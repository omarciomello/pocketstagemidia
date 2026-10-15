#!/usr/bin/env bash
# Roda um comando no CI; se falhar, publica as linhas de erro como anotação do GitHub.
# Uso: bash tool/ci_run.sh "título" comando args...
titulo="$1"; shift
out=$(mktemp)
"$@" >"$out" 2>&1
s=$?
cat "$out"
if [ $s -ne 0 ]; then
  linhas=$(grep -E '•|[Ee]rror|ERROR|FAILED|Exception|\.dart:[0-9]+' "$out" | grep -v '^\s*info •' | head -70)
  [ -z "$linhas" ] && linhas=$(tail -60 "$out")
  msg=$(printf '%s\n' "$linhas" | sed 's/%/%25/g; s/\r//g' | awk '{printf "%s%%0A", $0}')
  echo "::error title=$titulo::$msg"
fi
exit $s
