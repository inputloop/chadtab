#!/bin/sh
# site-check.sh -- chadtab.com and its mirrors, checked from outside: what a browser is sent, not what a file says.
#
#   sh deploy/site-check.sh               every check, one line each; exit 0 when all pass, 1 when any fails
#   sh deploy/site-check.sh --prove-red   the judging half against planted answers (no network)
#
# Checks: the home page and the stylesheet answer 200 with text/html and text/css (2026-11-11: a server-wide types
# block sent both as application/octet-stream, and with nosniff a browser downloaded the page); each carries
# nosniff and the content security policy; plain http answers 301 to https; www.chadtab.com and the four mirror names
# (chadtab.net, chadtab.org, with and without www) answer 301 to https://chadtab.com with the path and query kept.
# Needs: sh, curl.  BASE (default https://chadtab.com) moves the page checks to another address.
#
# Copyright 2026 INPUTLOOP (Bryant Frankford and Corwin Brust).  SPDX-License-Identifier: GPL-3.0-or-later
# Mentat (for Corwin; claude-opus-5-5)
BASE=${BASE:-https://chadtab.com}
fails=0
ok()  { echo "ok    $*"; }
bad() { echo "FAIL  $*"; fails=$((fails + 1)); }

# judge NAME HEADERS WANT-TYPE: the status line, the type and the two headers a page needs, from headers as text
judge() {
  h=$(printf '%s\n' "$2" | tr -d '\r')
  st=$(printf '%s\n' "$h" | awk 'toupper($1) ~ /^HTTP/ { s = $2 } END { print s }')
  ty=$(printf '%s\n' "$h" | awk -F': *' 'tolower($1) == "content-type" { t = $2 } END { print t }')
  [ "$st" = 200 ] || { bad "$1 answers $st, not 200"; return; }
  case "$ty" in "$3"|"$3;"*) ;; *) bad "$1 is sent as ${ty:-no type}, not $3"; return ;; esac
  printf '%s\n' "$h" | grep -qi '^x-content-type-options: *nosniff' || { bad "$1 has no nosniff"; return; }
  printf '%s\n' "$h" | grep -qi '^content-security-policy:' || { bad "$1 has no content security policy"; return; }
  ok "$1 answers 200 as $3, with nosniff and a content security policy"
}
# moved NAME STATUS LOCATION WANT-LOCATION
moved() {
  [ "$2" = 301 ] && [ "$3" = "$4" ] && ok "$1 answers 301 to $4" || bad "$1 answers ${2:-nothing} to ${3:-nowhere}, not 301 to $4"
}

if [ "${1:-}" = --prove-red ]; then
  good='HTTP/2 200
content-type: text/html; charset=utf-8
content-security-policy: default-src '"'self'"'
x-content-type-options: nosniff'
  out=$(judge page "$good" text/html); case "$out" in ok*) ;; *) echo "RED: a right page was faulted: $out"; exit 1 ;; esac
  out=$(judge page "$(printf '%s\n' "$good" | sed 's#text/html; charset=utf-8#application/octet-stream#')" text/html)
  case "$out" in *"sent as application/octet-stream"*) ;; *) echo "RED: the 2026-11-11 fault was not caught: $out"; exit 1 ;; esac
  out=$(judge page "$(printf '%s\n' "$good" | grep -v nosniff)" text/html); case "$out" in *nosniff*) ;; *) echo "RED: a missing nosniff was not caught: $out"; exit 1 ;; esac
  out=$(judge page "$(printf '%s\n' "$good" | sed 's#200#404#')" text/html); case "$out" in *"answers 404"*) ;; *) echo "RED: a 404 was not caught: $out"; exit 1 ;; esac
  out=$(moved m 301 https://chadtab.com/ https://chadtab.com/x); case "$out" in FAIL*) ;; *) echo "RED: a redirect that drops the path was not caught"; exit 1 ;; esac
  echo "PROVE-RED OK: a right page passes; octet-stream, no nosniff, a 404 and a redirect that drops the path are each caught"; exit 0
fi

command -v curl >/dev/null 2>&1 || { echo "site-check: needs curl"; exit 2; }
judge "$BASE/" "$(curl -sI -m 20 "$BASE/")" text/html
judge "$BASE/style.css" "$(curl -sI -m 20 "$BASE/style.css")" text/css
for host in chadtab.com www.chadtab.com chadtab.net www.chadtab.net chadtab.org www.chadtab.org; do
  for scheme in http https; do
    [ "$scheme$host" = httpschadtab.com ] && continue
    r=$(curl -s -o /dev/null -m 20 -w '%{http_code} %{redirect_url}' "$scheme://$host/x?y=1")
    moved "$scheme://$host/x?y=1" "${r%% *}" "${r#* }" "https://chadtab.com/x?y=1"
  done
done
[ $fails = 0 ] && echo "site-check: all pass" || echo "site-check: $fails failing"
[ $fails = 0 ]
