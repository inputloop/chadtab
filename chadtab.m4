dnl chadtab.m4 -- what this build is and what it is built against, in M4, read the way Corwin's Emacs builds for
dnl Windows read AC_INIT: by matching the m4_define lines (tests/grammar.sh does it with sed; no m4 is needed).
dnl A development build follows chadgram's latest and is told when chadgram has moved past CHADGRAM_PIN; a cut
dnl (a tagged release, CUT=1) is built against CHADGRAM_PIN exactly, and fails if grammar/chadgram.tsv is not it.
dnl Copyright 2026 INPUTLOOP (Bryant Frankford and Corwin Brust).  SPDX-License-Identifier: GPL-3.0-or-later
m4_define([CHADTAB_VERSION], [0.2.0])
m4_define([CHADTAB_DATE], [2026-11-10])
m4_define([CHADGRAM_PIN], [14de8d287915c20b003134d33da33e24f42e187f])
