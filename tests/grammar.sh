#!/bin/sh
# tests/grammar.sh -- chadtab against chadgram: the grammar it is written in, and the version it says it is.
#
#   sh tests/grammar.sh               a development build: checks 1-3; says when chadgram has moved past the pin
#   CUT=1 sh tests/grammar.sh         a cut (tagged release): chadgram moved past the pin is a failure too
#   sh tests/grammar.sh --prove-red   plants a wrong arrow, a wrong version and a stale pinned copy; each must be caught
#
# 1  the program's --version is CHADTAB_VERSION and CHADTAB_DATE from chadtab.m4
# 2  the arrows the program holds (its --reserved lines "arrow TOKEN ROLE") are the arrows of grammar/chadgram.tsv,
#    in the same order (the grammar's order is the order they are tried in)
# 3  grammar/chadgram.tsv is chadgram's chadgram.tsv at CHADGRAM_PIN, byte for byte (needs a chadgram checkout:
#    CHADGRAM_DIR, default ../chadgram; without one, 3 is NOT CHECKED and said)
# 4  (CUT=1) chadgram's newest chadgram.tsv is the pinned one; on a development build a difference is only said
# sh, sed, awk, git; python3 runs the program.  Copyright 2026 INPUTLOOP (Bryant Frankford and Corwin Brust).
# SPDX-License-Identifier: GPL-3.0-or-later.  Mentat (for Corwin; claude-opus-5-5)
set -u
here=$(cd "$(dirname "$0")/.." && pwd) || exit 2
PY=${PYTHON:-python3}; command -v "$PY" >/dev/null 2>&1 || PY=python
CG=${CHADGRAM_DIR:-$here/../chadgram}
red=0
ok()  { echo "ok    $*"; }
bad() { echo "FAIL  $*"; red=$((red + 1)); }
m4v() { sed -n "s/^m4_define(\[$1\], *\[\([^]]*\)\]).*/\1/p" "$2"; }

check() {   # ROOT (a chadtab tree): runs 1-4 against it
  r=$1; v=$(m4v CHADTAB_VERSION "$r/chadtab.m4"); d=$(m4v CHADTAB_DATE "$r/chadtab.m4"); pin=$(m4v CHADGRAM_PIN "$r/chadtab.m4")
  [ -n "$v" ] && [ -n "$d" ] && [ -n "$pin" ] || { bad "chadtab.m4 does not define CHADTAB_VERSION, CHADTAB_DATE and CHADGRAM_PIN"; return; }
  got=$("$PY" "$r/chadtab" --version)
  [ "$got" = "chadtab $v ($d)" ] && ok "1 the program says it is $v ($d), as chadtab.m4 does" || bad "1 the program says '$got'; chadtab.m4 says $v ($d)"
  "$PY" "$r/chadtab" --reserved | awk '$1 == "arrow" { print $2 "\t" $3 }' > "$T/prog"
  awk -F '\t' '$1 == "arrow" { print $2 "\t" $3 }' "$r/grammar/chadgram.tsv" > "$T/gram"
  if [ -s "$T/gram" ] && cmp -s "$T/prog" "$T/gram"; then ok "2 the program's $(wc -l < "$T/gram" | tr -d ' ') arrows are the grammar's, in its order"
  else bad "2 the program's arrows and grammar/chadgram.tsv differ:"; diff "$T/gram" "$T/prog" | sed 's/^/        /' | head -n 6; fi
  if [ -d "$CG/.git" ] || git -C "$CG" rev-parse >/dev/null 2>&1; then
    if git -C "$CG" show "$pin:chadgram.tsv" > "$T/pinned" 2>/dev/null; then
      cmp -s "$T/pinned" "$r/grammar/chadgram.tsv" && ok "3 grammar/chadgram.tsv is chadgram's at ${pin%"${pin#???????}"}" \
        || bad "3 grammar/chadgram.tsv is not chadgram's at ${pin%"${pin#???????}"}"
      if cmp -s "$T/pinned" "$CG/chadgram.tsv"; then ok "4 chadgram's newest grammar is the pinned one"
      elif [ "${CUT:-0}" = 1 ]; then bad "4 chadgram's grammar has moved past the pin; a cut must be built against its pin (update grammar/ and CHADGRAM_PIN, or cut from the pin)"
      else echo "note  4 chadgram's grammar has moved past the pin ($(diff "$T/pinned" "$CG/chadgram.tsv" | grep -c '^[<>]') line(s) differ); a development build goes on, a cut would not"; fi
    else bad "3 chadgram has no commit $pin (CHADGRAM_DIR=$CG)"; fi
  else echo "NOT CHECKED: 3-4 (no chadgram checkout at $CG; set CHADGRAM_DIR)"; fi
}

T=$(mktemp -d) || exit 2; trap 'rm -rf "$T" "${P:-}"' EXIT INT TERM
if [ "${1:-}" != --prove-red ]; then
  check "$here"
  [ $red = 0 ] && { echo "GREEN: grammar"; exit 0; } || { echo "RED: $red"; exit 1; }
fi
check "$here" > /dev/null; [ $red = 0 ] || { echo "KIT BROKEN: the clean run is red"; exit 2; }
P=$(mktemp -d) || exit 2; missed=0
plant() {   # NAME FILE SED-EXPRESSION
  rm -rf "$P/t"; mkdir "$P/t"; cp -R "$here/chadtab" "$here/chadtab.m4" "$here/grammar" "$P/t/"
  sed "$3" "$P/t/$2" > "$P/x" && cat "$P/x" > "$P/t/$2"
  red=0; check "$P/t" > "$P/out"
  [ $red -gt 0 ] && echo "RED as planted: $1" || { echo "MISSED: $1"; missed=1; }
}
plant "an arrow the program holds and the grammar does not" chadtab 's/("==>", "BIND")/("=>>", "BIND")/'
plant "a version the template does not say" chadtab.m4 's/\[CHADTAB_VERSION\], \[[^]]*\]/[CHADTAB_VERSION], [9.9.9]/'
plant "a pinned copy that is not chadgram's at the pin (a mark, which only 3 can see)" grammar/chadgram.tsv 's/^char	@	ARRAY$/char	@	ARRAYS/'
[ $missed = 0 ] && { echo "PROVE-RED OK: 3 planted faults each turned it red"; exit 0; } || exit 1
