#!/bin/sh
# deploy/ci.sh -- chadtab's CI on the host: run the test kit and the planted faults, write the result page,
# and end with one line chadtab captures: RESULT PASSED SUMMARY (the chadgram rules: SUMMARY keeps the rest).
# Run by chadtab itself (deploy/gw33.tab).  Copyright 2026 INPUTLOOP; GPL-3.0-or-later.  Mentat (for Corwin).
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
out=${CHADTAB_CI_OUT:-/var/www/chadtab.com/public/ci}
mkdir -p "$out"
when=$(date -u +%Y-%m-%dT%H:%MZ)
rev=$(cat "$here/REVISION" 2>/dev/null || echo unknown)
t=$(sh "$here/tests/run.sh" 2>&1); rc=$?
p=$(sh "$here/tests/run.sh" --prove-red 2>&1 | tail -1); prc=$?
result=red; [ $rc = 0 ] && [ $prc = 0 ] && result=green
esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }
{
  printf '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">\n'
  printf '<title>chadtab CI</title><link rel="stylesheet" href="../style.css">\n<main>\n'
  printf '<p class="kicker"><a href="../">chadtab</a> / continuous integration</p>\n'
  printf '<h1 class="%s">%s</h1>\n' "$result" "$result"
  printf '<p>Revision <code>%s</code>, run on gw33 at %s by chadtab itself (<code>deploy/gw33.tab</code>).</p>\n' "$rev" "$when"
  printf '<h2>The test kit</h2><pre>%s</pre>\n' "$(printf '%s\n' "$t" | esc)"
  printf '<h2>Planted faults</h2><pre>%s</pre>\n' "$(printf '%s\n' "$p" | esc)"
  printf '<p class="small">The history of runs is <a href="runs.jsonl">runs.jsonl</a>, one JSON line each.</p>\n</main>\n'
} > "$out/index.html.tmp" && mv "$out/index.html.tmp" "$out/index.html"
printf '%s %s %s\n' "$result" "$([ $rc = 0 ] && echo yes || echo no)" "$(printf '%s' "$t" | tail -1)"
[ $result = green ]
