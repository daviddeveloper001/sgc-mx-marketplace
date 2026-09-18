#!/usr/bin/env bash
# hooks/dod-mark-approved.sh
#
# Ejecutar SOLO cuando dod-reviewer dio VEREDICTO: APROBADO (sin FAIL) para
# el diff vigente. Registra el hash de ese diff como "ya revisado", para que
# dod-stop-gate.sh deje cerrar la tarea. La ruta exacta a este script la da
# siempre el mensaje de bloqueo del propio hook — nunca hay que adivinarla.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

if ! git -C "$PROJECT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
  echo "No es un repo git; nada que registrar." >&2
  exit 1
fi

PROJECT_KEY="$(printf '%s' "$PROJECT_DIR" | node -e "
  const crypto = require('crypto');
  let d='';
  process.stdin.on('data', c => d += c);
  process.stdin.on('end', () => process.stdout.write(crypto.createHash('sha256').update(d).digest('hex').slice(0, 16)));
")"
STATE_DIR="${HOME:-/tmp}/.claude/dod-state/$PROJECT_KEY"
mkdir -p "$STATE_DIR"

sha256_of_stdin() {
  node -e "
    const crypto = require('crypto');
    let d='';
    process.stdin.on('data', c => d += c);
    process.stdin.on('end', () => process.stdout.write(crypto.createHash('sha256').update(d).digest('hex')));
  "
}

DIFF_HASH="$(
  { git -C "$PROJECT_DIR" diff HEAD 2>/dev/null; \
    git -C "$PROJECT_DIR" status --porcelain 2>/dev/null; } | sha256_of_stdin
)"

echo "$DIFF_HASH" > "$STATE_DIR/last-approved.hash"
echo "Diff actual (hash ${DIFF_HASH:0:12}...) marcado como revisado por dod-reviewer."
