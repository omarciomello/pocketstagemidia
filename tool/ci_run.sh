#!/usr/bin/env bash
# Roda um comando no CI; se falhar, publica as linhas de erro como anotação do GitHub.
# Uso: bash tool/ci_run.sh "título" comando args...
titulo="$1"; shift
out=$(mktemp)
"$@" >"$out" 2>&1
s=$?
cat "$out"
if [ $s -ne 0 ]; then
  linhas=$( { grep -E '(error|warning) •' "$out"; grep -E -A6 'The following|Test failed|FAILED|\[E\]|Error:|What went wrong|^e: |ERROR:' "$out"; } | grep -vE '^#[0-9]+|^--$|^═|package:flutter/|dart:async|package:flutter_test|package:stack_trace|package:test_api|^\s*$' | awk '!seen[$0]++' | head -90)
  [ -z "$linhas" ] && linhas=$(tail -60 "$out")
  msg=$(printf '%s\n' "$linhas" | sed 's/%/%25/g; s/\r//g' | awk '{printf "%s%%0A", $0}')
  echo "::error title=$titulo::$msg"
fi
exit $s
