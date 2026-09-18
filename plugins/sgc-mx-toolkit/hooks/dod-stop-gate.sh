#!/usr/bin/env bash
# hooks/dod-stop-gate.sh
#
# Stop hook: bloquea el cierre de una tarea de código hasta que el diff
# vigente haya sido revisado y aprobado por el subagente `dod-reviewer`.
#
# Requiere: git y node en PATH (no depende de jq). No necesita permisos de
# escritura fuera de ~/.claude/dod-state/.
#
# Funciona igual instalado como plugin (hooks/ dentro del plugin) o copiado
# a mano a .claude/hooks/ de un proyecto: la ruta al script hermano
# dod-mark-approved.sh se resuelve siempre relativa a este mismo archivo,
# nunca a una ruta fija — así no importa desde dónde lo ejecute Claude Code.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARK_SCRIPT="$SCRIPT_DIR/dod-mark-approved.sh"

INPUT_JSON="$(cat)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# El estado del gate vive FUERA del repo del proyecto (nunca dentro de
# $PROJECT_DIR): si viviera dentro, "git status --porcelain" lo vería como
# archivo nuevo y el hash del diff cambiaría solo con cada corrida del hook.
PROJECT_KEY="$(printf '%s' "$PROJECT_DIR" | node -e "
  const crypto = require('crypto');
  let d='';
  process.stdin.on('data', c => d += c);
  process.stdin.on('end', () => process.stdout.write(crypto.createHash('sha256').update(d).digest('hex').slice(0, 16)));
")"
STATE_DIR="${HOME:-/tmp}/.claude/dod-state/$PROJECT_KEY"
mkdir -p "$STATE_DIR"

read_field() {
  node -e "
    let d='';
    process.stdin.on('data', c => d += c);
    process.stdin.on('end', () => {
      try {
        const j = JSON.parse(d);
        const v = j['$1'];
        process.stdout.write(v === undefined || v === null ? '' : String(v));
      } catch (e) { process.stdout.write(''); }
    });
  " <<< "$INPUT_JSON"
}

sha256_of_stdin() {
  node -e "
    const crypto = require('crypto');
    let d='';
    process.stdin.on('data', c => d += c);
    process.stdin.on('end', () => process.stdout.write(crypto.createHash('sha256').update(d).digest('hex')));
  "
}

SESSION_ID="$(read_field session_id)"
[ -n "$SESSION_ID" ] || SESSION_ID="unknown-session"

# Si no es un repo git, no hay nada que este hook pueda revisar.
if ! git -C "$PROJECT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
  exit 0
fi

DIFF_HASH="$(
  { git -C "$PROJECT_DIR" diff HEAD 2>/dev/null; \
    git -C "$PROJECT_DIR" status --porcelain 2>/dev/null; } | sha256_of_stdin
)"
EMPTY_HASH="$(printf '' | sha256_of_stdin)"

# Sin cambios pendientes: nada que revisar, dejar cerrar.
if [ "$DIFF_HASH" = "$EMPTY_HASH" ]; then
  exit 0
fi

APPROVED_FILE="$STATE_DIR/last-approved.hash"
APPROVED_HASH=""
[ -f "$APPROVED_FILE" ] && APPROVED_HASH="$(cat "$APPROVED_FILE")"

# Este diff exacto ya fue revisado y aprobado: dejar cerrar.
if [ "$DIFF_HASH" = "$APPROVED_HASH" ]; then
  exit 0
fi

# --- control de intentos para no bloquear infinitamente ---
# El contador se guarda junto con el hash del diff al que pertenece: si el
# diff cambió desde el último bloqueo (nuevo trabajo tras una aprobación
# previa), el contador arranca de nuevo en vez de heredar intentos viejos.
ATTEMPTS_FILE="$STATE_DIR/attempts-$SESSION_ID.state"
LAST_ATTEMPT_HASH=""
ATTEMPTS=0
if [ -f "$ATTEMPTS_FILE" ]; then
  read -r LAST_ATTEMPT_HASH ATTEMPTS < "$ATTEMPTS_FILE" || true
fi
if [ "$LAST_ATTEMPT_HASH" != "$DIFF_HASH" ]; then
  ATTEMPTS=0
fi
ATTEMPTS=$((ATTEMPTS + 1))
echo "$DIFF_HASH $ATTEMPTS" > "$ATTEMPTS_FILE"

ATTEMPT_CAP=2

if [ "$ATTEMPTS" -gt "$ATTEMPT_CAP" ]; then
  echo "[dod-stop-gate] Aviso: se permitió cerrar sin aprobación explícita de dod-reviewer tras $ATTEMPTS intentos. Revisa el diff manualmente." >&2
  exit 0
fi

cat >&2 <<MSG_EOF
Hay cambios sin revisar contra el Definition of Done (intento $ATTEMPTS de $ATTEMPT_CAP).

Antes de dar esta tarea por terminada:
1. Invoca al subagente dod-reviewer (Task/Agent tool, subagent_type "dod-reviewer") contra el diff actual.
2. Resuelve cualquier hallazgo marcado FAIL.
3. Si el veredicto final es APROBADO, dod-reviewer debe ejecutar exactamente:
   bash "$MARK_SCRIPT"
MSG_EOF

exit 2
