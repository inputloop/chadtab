;;; chadtab.el --- chadtab's clocks read a second time, and a view of a running chadtab  -*- lexical-binding: t; -*-

;; Copyright 2026 INPUTLOOP (Bryant Frankford and Corwin Brust)
;; SPDX-License-Identifier: GPL-3.0-or-later
;; Author: Mentat (for Corwin; claude-opus-5-5)
;; Package-Requires: ((emacs "27.1"))

;;; Commentary:

;; Two jobs, kept apart.
;;
;; 1. The second reader.  `chadtab-clock-next' answers "when does this clock fire next?" without
;;    sharing a line with the Python reader (chadtab): it walks days and then the hours and minutes a
;;    cron spec allows, where the Python one walks minutes and skips ahead.  tests/run.sh asks both of
;;    the same vectors and expects the same answers.  From a shell:
;;      emacs -Q --batch -l chadtab.el -f chadtab-batch-next "cron:0 9 * * 1-5" 2026-11-14T10:00 3
;;
;; 2. The view.  M-x chadtab-status asks `chadtab status TABLE --json' and shows the blocks in a
;;    tabulated list: clock, level, next fire, last result, and a strip of recent outcomes.  g refreshes,
;;    RET runs the block at point (after a yes), q quits.

;;; Code:

(require 'cl-lib)
(require 'json)

(defconst chadtab--names
  '(("jan" . 1) ("feb" . 2) ("mar" . 3) ("apr" . 4) ("may" . 5) ("jun" . 6) ("jul" . 7) ("aug" . 8)
    ("sep" . 9) ("oct" . 10) ("nov" . 11) ("dec" . 12)
    ("sun" . 0) ("mon" . 1) ("tue" . 2) ("wed" . 3) ("thu" . 4) ("fri" . 5) ("sat" . 6)))

(defun chadtab--num (s)
  (cond ((string-match-p "\\`[0-9]+\\'" s) (string-to-number s))
        ((cdr (assoc (downcase s) chadtab--names)))
        (t (error "chadtab: %S is not a number or a month/day name" s))))

(defun chadtab--field (text lo hi)
  "The sorted list of values cron field TEXT allows between LO and HI."
  (let (vals)
    (dolist (part (split-string text ","))
      (let* ((sl (split-string part "/"))
             (step (if (cdr sl) (string-to-number (cadr sl)) 1))
             (base (car sl))
             a b)
        (when (< step 1) (error "chadtab: bad step in %S" part))
        (cond ((string= base "*") (setq a lo b hi))
              ((string-match "\\`\\([^-]+\\)-\\(.+\\)\\'" base)
               (setq a (chadtab--num (match-string 1 base)) b (chadtab--num (match-string 2 base))))
              (t (setq a (chadtab--num base) b (if (cdr sl) hi a))))
        (when (or (< a lo) (> b hi) (> a b)) (error "chadtab: %S is outside %d-%d" part lo hi))
        (cl-loop for v from a to b by step do (push (if (and (= hi 7) (= v 7)) 0 v) vals))))
    (sort (delete-dups vals) #'<)))

(defun chadtab--parse-iso (s)
  "Seconds since the epoch for local wall time S, YYYY-MM-DDTHH:MM."
  (unless (string-match "\\`\\([0-9]+\\)-\\([0-9]+\\)-\\([0-9]+\\)[T ]\\([0-9]+\\):\\([0-9]+\\)" s)
    (error "chadtab: %S is not YYYY-MM-DDTHH:MM" s))
  (float-time (encode-time (list 0 (string-to-number (match-string 5 s)) (string-to-number (match-string 4 s))
                                 (string-to-number (match-string 3 s)) (string-to-number (match-string 2 s))
                                 (string-to-number (match-string 1 s)) nil -1 nil))))

(defun chadtab--iso (secs)
  (format-time-string "%Y-%m-%dT%H:%M" (seconds-to-time secs)))

(defun chadtab--cron-next (spec from)
  "First fire of cron SPEC (five fields) strictly after FROM (seconds), walking days, then hours, then minutes."
  (let* ((f (split-string spec))
         (_ (unless (= (length f) 5) (error "chadtab: cron wants five fields: %S" spec)))
         (mins (chadtab--field (nth 0 f) 0 59)) (hours (chadtab--field (nth 1 f) 0 23))
         (doms (chadtab--field (nth 2 f) 1 31)) (mons (chadtab--field (nth 3 f) 1 12))
         (dows (chadtab--field (nth 4 f) 0 7))
         (either (not (or (string= (nth 2 f) "*") (string= (nth 4 f) "*"))))
         (d0 (decode-time (seconds-to-time from)))
         (y (nth 5 d0)) (mo (nth 4 d0)) (dd (nth 3 d0)))
    (catch 'found
      (dotimes (i (* 5 366))
        ;; noon of the i-th day after FROM's day: away from any clock change
        (let* ((noon (decode-time (encode-time (list 0 0 12 (+ dd i) mo y nil -1 nil))))
               (day (nth 3 noon)) (mon (nth 4 noon)) (yr (nth 5 noon)) (dow (nth 6 noon))
               (dok (memq day doms)) (wok (memq dow dows)))
          (when (and (memq mon mons) (if either (or dok wok) (and dok wok)))
            (dolist (h hours)
              (dolist (m mins)
                (let ((tm (float-time (encode-time (list 0 m h day mon yr nil -1 nil)))))
                  (when (> tm from) (throw 'found tm))))))))
      nil)))

(defun chadtab-clock-next (clock from-iso &optional n)
  "The next N (default 1) fires of CLOCK after FROM-ISO, as YYYY-MM-DDTHH:MM strings."
  (let ((t0 (chadtab--parse-iso from-iso)) out)
    (dotimes (_ (or n 1))
      (let ((nx (cond
                 ((string-prefix-p "cron:" clock) (chadtab--cron-next (substring clock 5) t0))
                 ((string-match "\\`every:\\([0-9]+\\)\\([smhd]\\)\\(?:\\+\\([0-9]+\\)\\([smhd]\\)\\)?\\'" clock)
                  (let* ((u '(("s" . 1) ("m" . 60) ("h" . 3600) ("d" . 86400)))
                         (p (* (string-to-number (match-string 1 clock)) (cdr (assoc (match-string 2 clock) u))))
                         (o (if (match-string 3 clock)
                                (* (string-to-number (match-string 3 clock)) (cdr (assoc (match-string 4 clock) u)))
                              0)))
                    (+ (* (1+ (floor (- t0 o) p)) p) o)))
                 ((string-prefix-p "at:" clock)
                  (let ((w (chadtab--parse-iso (substring clock 3)))) (and (> w t0) w)))
                 ((string= clock "boot") nil)
                 (t (error "chadtab: unknown clock %S" clock)))))
        (when nx
          (push (chadtab--iso nx) out)
          (setq t0 nx))))
    (nreverse out)))

(defun chadtab-batch-next ()
  "Batch entry: CLOCK FROM N on the command line; prints one fire per line."
  (let ((a command-line-args-left))
    (setq command-line-args-left nil)
    (dolist (s (chadtab-clock-next (nth 0 a) (nth 1 a) (string-to-number (or (nth 2 a) "1"))))
      (princ (concat s "\n")))))

;;; The view

(defgroup chadtab nil "A successor to cron." :group 'processes)
(defcustom chadtab-program "chadtab" "The chadtab program." :type 'string)
(defvar-local chadtab--table nil)

(defun chadtab--strip (hist)
  (if (= (length hist) 0) "·" (mapconcat (lambda (x) (if (eq x 1) "▮" "▯")) hist "")))

(defun chadtab--refresh ()
  (let* ((json-object-type 'alist) (json-array-type 'list)
         (s (json-read-from-string
             (with-output-to-string
               (with-current-buffer standard-output
                 (call-process chadtab-program nil t nil "status" chadtab--table "--json"))))))
    (setq tabulated-list-entries
          (mapcar (lambda (b)
                    (let ((ok (alist-get 'ok b)))
                      (list (alist-get 'name b)
                            (vector (alist-get 'name b) (alist-get 'clock b) (format "%s" (alist-get 'level b))
                                    (or (alist-get 'next b) "—") (or (alist-get 'last b) "—")
                                    (cond ((eq ok t) "ok") ((null (assq 'ok b)) "—") ((eq ok :json-false) "FAIL") (t "—"))
                                    (chadtab--strip (alist-get 'hist b))))))
                  (alist-get 'blocks s)))
    (tabulated-list-print t)))

(define-derived-mode chadtab-status-mode tabulated-list-mode "chadtab"
  "The blocks of a chadtab and how they have run."
  (setq tabulated-list-format [("Block" 16 t) ("Clock" 22 nil) ("Lv" 3 nil) ("Next" 17 t) ("Last" 17 t)
                               ("Result" 7 t) ("Recent" 24 nil)])
  (add-hook 'tabulated-list-revert-hook #'chadtab--refresh nil t)
  (tabulated-list-init-header))

(define-key chadtab-status-mode-map (kbd "RET")
  (lambda () (interactive)
    (let ((name (tabulated-list-get-id)))
      (when (and name (yes-or-no-p (format "Run block %s now? " name)))
        (message "%s" (with-output-to-string
                        (with-current-buffer standard-output
                          (call-process chadtab-program nil t nil "run" chadtab--table name))))
        (revert-buffer)))))

;;;###autoload
(defun chadtab-status (table)
  "Show the blocks of chadtab TABLE and how they have run."
  (interactive "fchadtab table: ")
  (with-current-buffer (get-buffer-create "*chadtab*")
    (chadtab-status-mode)
    (setq chadtab--table (expand-file-name table))
    (chadtab--refresh)
    (pop-to-buffer (current-buffer))))

(provide 'chadtab)
;;; chadtab.el ends here
