#!/bin/sh
# tests/run.sh -- chadtab's test kit, in POSIX sh.  Spec: tests/SPEC.txt (each test carries its number).
# usage: sh tests/run.sh [--prove-red]     exit 0 green, 1 red, 2 kit broken
# Readers: chadtab (Python) and chadtab.el (Emacs Lisp) for clocks; cxr's tv1cr (sh) for the naming rule.
# Copyright 2026 INPUTLOOP (Bryant Frankford and Corwin Brust).  SPDX-License-Identifier: GPL-3.0-or-later
# Mentat (for Corwin; claude-opus-5-5)
set -u
here=$(cd "$(dirname "$0")/.." && pwd) || exit 2
PY=${PYTHON:-python3}; command -v "$PY" >/dev/null 2>&1 || PY=python
command -v "$PY" >/dev/null 2>&1 || { echo "KIT BROKEN: no python"; exit 2; }
EMACS=${EMACS:-emacs}
CT="$here/chadtab"
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT INT TERM
red=0; notchecked=""
fail() { echo "FAIL $*"; red=$((red+1)); }
c() { CHADTAB_FAULT="${FAULT:-}" CHADTAB_LOCK_WAIT=0.3 "$PY" "$CT" "$@"; }
el() { "$EMACS" -Q --batch -l "$here/chadtab.el" -f chadtab-batch-next "$@" 2>/dev/null; }
have_emacs=1; command -v "$EMACS" >/dev/null 2>&1 || { have_emacs=0; notchecked="1-3 second reader (no emacs: the Emacs Lisp reader was not asked)"; }
TV1CR=${TV1CR:-}
[ -z "$TV1CR" ] && for p in "$here/../c4/bin/tv1cr" /root/.claude/plugins/synced/*/vibrobeast-skills/skills/cxr/scripts/tv1cr; do [ -f "$p" ] && TV1CR=$p && break; done

run_tests() {
  red=0
  # 1-3 clocks: the hand-worked oracle, both readers; agree rows: the two readers together
  tab=$(printf '\t')
  while IFS="$tab" read -r clock from n want; do
    case "$clock" in ''|'#'*) continue ;; esac
    py=$(TZ=UTC c clock "$clock" "$from" "$n" | tr '\n' ' ' | sed 's/ $//')
    if [ "$want" = agree ]; then
      [ $have_emacs = 1 ] || continue
      lisp=$(TZ=UTC el "$clock" "$from" "$n" | tr '\n' ' ' | sed 's/ $//')
      [ -n "$py" ] && [ "$py" = "$lisp" ] || fail "2 readers disagree on $clock from $from: python [$py] lisp [$lisp]"
    else
      [ "$py" = "$want" ] || fail "1 python $clock from $from: [$py] want [$want]"
      if [ $have_emacs = 1 ]; then
        lisp=$(TZ=UTC el "$clock" "$from" "$n" | tr '\n' ' ' | sed 's/ $//')
        [ "$lisp" = "$want" ] || fail "1 lisp $clock from $from: [$lisp] want [$want]"
      fi
    fi
  done < "$here/tests/VECTORS.tsv"
  while IFS="$tab" read -r zone clock from n want; do
    case "$zone" in ''|'#'*) continue ;; esac
    py=$(TZ=$zone c clock "$clock" "$from" "$n" | tr '\n' ' ' | sed 's/ $//')
    [ "$py" = "$want" ] || fail "3 python $clock in $zone from $from: [$py] want [$want]"
    if [ $have_emacs = 1 ]; then
      lisp=$(TZ=$zone el "$clock" "$from" "$n" | tr '\n' ' ' | sed 's/ $//')
      [ "$lisp" = "$want" ] || fail "3 lisp $clock in $zone: [$lisp] want [$want]"
    fi
  done < "$here/tests/VECTORS-TZ.tsv"

  # 4 the table: blocks, settings, levels; a bad line is refused by number
  mkdir -p "$T/w"; cat > "$T/w/good.tab" <<'TAB'
# a chadtab
PATH=/usr/local/bin:/usr/bin:/bin
RUNLEVEL=2
*  stamp   cron:*/5 * * * *
|  --->    !sh -c "echo ok 42 the rest of it"
|  % <--- @   status bytes ..note
|  -->>    log/stamp.jsonl
|  ==>     c4:reg host1 status $status
*  deep    every:1h  level=5
|  --->    !sh -c "echo deep"
*  start   boot
|  --->    !sh -c "echo booted"
|  -->>    log/boot.jsonl
*  missed  cron:0 3 * * *  catchup
|  --->    !sh -c "echo caught"
|  -->>    log/missed.jsonl
TAB
  o=$(TZ=UTC c check "$T/w/good.tab" --from 2026-11-10T13:07) || fail "4 good table refused: $o"
  echo "$o" | grep -q "run-level 2; 1 setting(s); 4 block(s)" || fail "4 table summary: $o"
  echo "$o" | grep -q "deep: every:1h (level 5)" || fail "4 block level: $o"
  echo "$o" | grep -q "missed: cron:0 3 \* \* \* (level 2, catchup)" || fail "4 catchup/default level: $o"
  printf '%s\n' '*  a  cron:* * *' > "$T/w/bad1.tab"; c check "$T/w/bad1.tab" >/dev/null 2>&1; [ $? = 2 ] || fail "4 four-field cron not refused"
  printf '%s\n' '|  ---> !true' > "$T/w/bad2.tab"; o=$(c check "$T/w/bad2.tab" 2>&1); [ $? = 2 ] && echo "$o" | grep -q "line 1" || fail "4 step before block: $o"
  printf '%s\n' '*  a  every:1m' '|  just words' > "$T/w/bad3.tab"; o=$(c check "$T/w/bad3.tab" 2>&1); [ $? = 2 ] && echo "$o" | grep -q "line 2" || fail "4 arrowless step: $o"
  printf '%s\n' '*  a  every:1m' '*  a  every:2m' > "$T/w/bad4.tab"; c check "$T/w/bad4.tab" >/dev/null 2>&1; [ $? = 2 ] || fail "4 duplicate block not refused"

  # 5 a run: command, capture by the chadgram rules (the .. field keeps the rest), append, guarded bind
  rm -rf "$T/w/log" "$T/w/reg"
  o=$(c run "$T/w/good.tab" stamp) || fail "5 run stamp: $o"
  echo "$o" | grep -q '"note": "the rest of it"' || fail "5 slurp field: $o"
  grep -q '"bytes": "42"' "$T/w/log/stamp.jsonl" 2>/dev/null || fail "5 append record"
  [ "$(cat "$T/w/reg/r/host1/status" 2>/dev/null)" = ok ] || fail "5 bind r side"
  grep -qx host1 "$T/w/reg/c/status/ok" 2>/dev/null || fail "5 bind c side"
  c verify "$T/w/reg" >/dev/null || fail "5 verify after run: $(c verify "$T/w/reg")"

  # 6 guarded writes: the semaphore, levels, the journal
  R=$T/reg6; rm -rf "$R"
  c put "$R" gw33 role web --level 3 --writer a >/dev/null || fail "6 put"
  c put "$R" gw33 role build --level 3 --writer a >/dev/null || fail "6 put 2"
  [ "$(cat "$R/s")" = 2 ] || fail "6 semaphore not at the last commit: $(cat "$R/s" 2>/dev/null)"
  [ ! -f "$R/c/role/web" ] || fail "6 old c member left behind"
  [ "$(c get "$R" gw33 role --level 3)" = build ] || fail "6 same-level reader"
  [ "$(c get "$R" gw33 role --level 1)" = build ] || fail "6 lower-order reader does not see it"
  c get "$R" gw33 role --level 5 >/dev/null 2>&1; [ $? = 3 ] || fail "6 higher-order reader saw a level-3 write"
  c put "$R" gw33 role edge --level 5 --writer b >/dev/null || fail "6 put at 5"
  [ "$(c get "$R" gw33 role --level 5)" = edge ] || fail "6 level-5 reader"
  printf '1\n' > "$R/s"
  [ "$(c get "$R" gw33 role --level 3)" = web ] || fail "6 a reader looked past the semaphore"
  printf '3\n' > "$R/s"
  [ "$(grep -c ' COMMIT ' "$R/j")" = 3 ] || fail "6 journal commits: $(cat "$R/j")"
  c verify "$R" >/dev/null || fail "6 verify: $(c verify "$R")"

  # 7 the reciprocal guard: a stale c member makes the writers disagree; the old value comes back, FAILED journalled
  printf 'gw33\n' > "$R/c/role/^stray^"
  o=$(c put "$R" gw33 role mail --writer a 2>&1); rc=$?
  [ $rc = 4 ] || fail "7 disagreement not refused (exit $rc): $o"
  [ "$(cat "$R/r/gw33/role")" = edge ] || fail "7 old value not put back: $(cat "$R/r/gw33/role")"
  tail -1 "$R/j" | grep -q ' FAILED ' || fail "7 FAILED not journalled"
  [ "$(cat "$R/s")" = 3 ] || fail "7 semaphore moved on a failed write"
  [ ! -f "$R/c/role/mail" ] || fail "7 c kept the failed value"
  rm -f "$R/c/role/^stray^"

  # 8 the lock: a writer that holds it keeps the other out, and nothing is written
  mkdir "$R/.lock"; echo "other 1 now" > "$R/.lock/owner"
  o=$(c put "$R" gw33 role web 2>&1); [ $? = 5 ] || fail "8 held lock not respected: $o"
  [ "$(cat "$R/r/gw33/role")" = edge ] || fail "8 wrote through a held lock"
  rm -rf "$R/.lock"

  # 9 the naming rule agrees with cxr's tv1cr, written separately in sh
  if [ -n "$TV1CR" ]; then
    for s in "Hello World" "a/b" "" "." ".." "ÉCOLE" "x%y" "MiXeD-case_1.0"; do
      [ "$(c enc "$s")" = "$(sh "$TV1CR" enc "$s")" ] || fail "9 enc [$s]: $(c enc "$s") vs $(sh "$TV1CR" enc "$s")"
    done
  else notchecked="$notchecked${notchecked:+; }9 (no tv1cr found)"; fi

  # 10 the daemon: one tick at a set time runs what is due, keeps state; boot runs once; catchup runs what was missed
  S=$T/state; rm -rf "$S" "$T/w/log"
  printf '{"missed": {"start": "2026-11-08T03:00:00", "ok": true, "exit": 0, "secs": 0.1}}' > "$T/s0.json"; mkdir -p "$S"; cp "$T/s0.json" "$S/last.json"
  TZ=UTC c daemon "$T/w/good.tab" --state "$S" --once-at 2026-11-10T13:05 >/dev/null 2>&1 || fail "10 daemon tick"
  [ -f "$T/w/log/stamp.jsonl" ] || fail "10 due block (*/5 at 13:05) did not run"
  [ -f "$T/w/log/boot.jsonl" ] || fail "10 boot block did not run"
  [ -f "$T/w/log/missed.jsonl" ] || fail "10 catchup block did not run after a missed fire"
  grep -q '"deep"' "$S/runs.jsonl" && fail "10 a level-5 block ran at level 3"
  TZ=UTC c daemon "$T/w/good.tab" --state "$S" --once-at 2026-11-10T13:06 >/dev/null 2>&1
  [ "$(grep -c '"stamp"' "$S/runs.jsonl")" = 1 ] || fail "10 stamp ran at 13:06 too"

  # 11 the views: status as JSON for Emacs and the surface; the text view has every block
  o=$(c status "$T/w/good.tab" --state "$S" --json) || fail "11 status json"
  echo "$o" | "$PY" -c 'import json,sys; s=json.load(sys.stdin); b={x["name"]:x for x in s["blocks"]}; assert b["stamp"]["ok"] is True and b["stamp"]["hist"]==[1] and b["deep"]["last"] is None' 2>/dev/null || fail "11 status fields: $o"
  o=$(c status "$T/w/good.tab" --state "$S"); for b in stamp deep start missed; do echo "$o" | grep -q "^$b " || fail "11 text view lacks $b"; done
}

if [ "${1:-}" != --prove-red ]; then
  FAULT=; run_tests
  [ -n "$notchecked" ] && echo "NOT CHECKED: $notchecked"
  [ $red = 0 ] && { echo "GREEN: chadtab tests (SPEC 1-11)"; exit 0; } || { echo "RED: $red failure(s)"; exit 1; }
fi
FAULT=; run_tests; [ $red = 0 ] || { echo "KIT BROKEN: the clean run is red"; exit 2; }
bad=0
for f in domor everylocal nolock onewriter noguard nosem levelinv; do
  FAULT=$f; run_tests >/dev/null 2>&1
  if [ $red -gt 0 ]; then echo "RED as planted: $f ($red)"; else echo "MISSED: $f did not turn the kit red"; bad=1; fi
done
[ $bad = 0 ] && { echo "PROVE-RED OK: 7 planted faults each turned the kit red"; exit 0; } || exit 1
