#!/usr/bin/env bash
# hooks/dod-stop-gate.sh
#
# Stop hook: bloquea el cierre de una tarea de código hasta que el diff
# vigente haya sido revisado y aprobado por el subagente `dod-reviewer`
# (o su variante liviana `dod-reviewer-lite` para diffs pequeños y no
# sensibles).
#
# Requiere: git y node en PATH (no depende de jq). No necesita permisos de
# escritura fuera de ~/.claude/dod-state/.
#
# Funciona igual instalado como plugin (hooks/ dentro del plugin) o copiado
# a mano a .claude/hooks/ de un proyecto: la ruta al script hermano
# dod-mark-approved.sh se resuelve siempre relativa a este mismo archivo,
# nunca a una ruta fija — así no importa desde dónde lo ejecute Claude Code.
#
# --- Pre-filtrado mecánico (v0.7.0) ---
# Antes de pedirle a dod-reviewer que audite los 24 puntos, este hook mira
# qué archivos cambiaron y descarta mecánicamente los puntos del checklist
# que no pueden aplicar (ej.: sin archivos .blade.php en el diff, el punto 5
# es N/A sin necesidad de que el subagente investigue nada). Los puntos
# agnósticos (2, 6, 7, 8, 9, 10, 11, 12, 13, 24) siempre quedan "vivos" y se
# evalúan a fondo, sin excepción — el pre-filtrado nunca descarta un punto
# por adivinanza, solo por ausencia real de los archivos que lo activarían.
#
# Además, si el diff es pequeño y no toca ninguna ruta sensible (no dispara
# NINGUNA categoría: controlador, migración, modelo, API, Form Request,
# Job/Command, o un bloque catch nuevo), el hook sugiere invocar
# `dod-reviewer-lite` en vez de `dod-reviewer` — mismo checklist auditable,
# modelo más liviano, y solo los skills core-* + laravel-modern-syntax +
# laravel-eloquent-encapsulation precargados (los únicos que respaldan los
# puntos que pueden seguir vivos en ese caso).

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

# ---------------------------------------------------------------------------
# Pre-filtrado mecánico: qué archivos cambiaron y qué categorías tocan.
# Requiere que el nuevo trabajo (incluidos archivos nuevos) ya esté agregado
# al índice (`git add -A`) — mismo requisito que ya existía para el hash.
# ---------------------------------------------------------------------------
CHANGED_FILES="$(
  { git -C "$PROJECT_DIR" diff HEAD --name-only 2>/dev/null; } | sort -u
)"
NUM_FILES="$(printf '%s\n' "$CHANGED_FILES" | grep -c . || true)"
NUM_LINES="$(
  git -C "$PROJECT_DIR" diff HEAD --numstat 2>/dev/null \
    | awk '{a=$1+0; r=$2+0; t+=a+r} END{print t+0}'
)"

has_match() {
  printf '%s\n' "$CHANGED_FILES" | grep -Eq "$1"
}

has_added_catch() {
  git -C "$PROJECT_DIR" diff HEAD 2>/dev/null | grep -Eq '^\+[^+].*catch[[:space:]]*\('
}

any_true() {
  for v in "$@"; do
    [ "$v" = "true" ] && return 0
  done
  return 1
}

TOUCHES_BLADE=false;          has_match '\.blade\.php$' && TOUCHES_BLADE=true
TOUCHES_MIGRATION=false;      has_match 'database/migrations/' && TOUCHES_MIGRATION=true
TOUCHES_MODEL=false;          has_match '(^|/)[Mm]odels/' && TOUCHES_MODEL=true
TOUCHES_CONTROLLER=false;     has_match 'Http/Controllers/' && TOUCHES_CONTROLLER=true
TOUCHES_API_CONTROLLER=false; has_match 'Http/Controllers/Api/' && TOUCHES_API_CONTROLLER=true
TOUCHES_API_RESOURCE=false;   has_match 'Http/Resources/' && TOUCHES_API_RESOURCE=true
TOUCHES_API_FILTER=false;     has_match '(Filters/|QueryFilter)' && TOUCHES_API_FILTER=true
TOUCHES_REPOSITORY=false;     has_match 'Repositories/' && TOUCHES_REPOSITORY=true
TOUCHES_API_SERVICE=false;    has_match 'Services/Api/' && TOUCHES_API_SERVICE=true
TOUCHES_EXCEPTION=false;      has_match 'Exceptions/' && TOUCHES_EXCEPTION=true
TOUCHES_FORM_REQUEST=false;   has_match 'Http/Requests/' && TOUCHES_FORM_REQUEST=true
TOUCHES_JOB_COMMAND=false;    has_match '(Jobs/|Console/Commands/|Listeners/)' && TOUCHES_JOB_COMMAND=true
TOUCHES_CATCH=false;          has_added_catch && TOUCHES_CATCH=true

# Un punto queda "vivo" (evaluación completa, con evidencia archivo:línea) si
# su categoría de archivo aparece en el diff. Si no, queda mecánicamente
# descartado: dod-reviewer lo marca N/A citando la razón, sin investigar.
POINTS_LIVE="2 6 7 8 9 10 11 12 13 24"
POINTS_DISCARDED=""

check_point() {
  # $1 = número de punto, $2 = true/false, $3 = razón si se descarta
  if [ "$2" = "true" ]; then
    POINTS_LIVE="$POINTS_LIVE $1"
  else
    POINTS_DISCARDED="${POINTS_DISCARDED}  - Punto $1: N/A — $3
"
  fi
}

check_point 1  "$TOUCHES_CONTROLLER" "sin archivos bajo Http/Controllers/ en el diff"
if any_true "$TOUCHES_BLADE" "$TOUCHES_CONTROLLER" "$TOUCHES_API_RESOURCE"; then
  check_point 3 "true" ""
else
  check_point 3 "false" "sin vistas Blade, controladores ni Resources de API en el diff"
fi
check_point 4  "$TOUCHES_CATCH" "no se agregó ni modificó ningún bloque catch"
check_point 5  "$TOUCHES_BLADE" "sin archivos .blade.php en el diff"
check_point 14 "$TOUCHES_JOB_COMMAND" "sin Jobs/Commands/Listeners en el diff"
if any_true "$TOUCHES_CONTROLLER" "$TOUCHES_FORM_REQUEST"; then
  check_point 15 "true" ""
else
  check_point 15 "false" "sin controladores ni Form Requests en el diff"
fi
if any_true "$TOUCHES_API_CONTROLLER" "$TOUCHES_API_RESOURCE"; then
  check_point 16 "true" ""
else
  check_point 16 "false" "sin controladores ni Resources de API en el diff"
fi
check_point 17 "$TOUCHES_API_CONTROLLER" "sin controladores bajo Http/Controllers/Api en el diff"
if any_true "$TOUCHES_API_CONTROLLER" "$TOUCHES_API_FILTER"; then
  check_point 18 "true" ""
else
  check_point 18 "false" "sin controladores de API ni Filters en el diff"
fi
if any_true "$TOUCHES_REPOSITORY" "$TOUCHES_API_SERVICE"; then
  check_point 19 "true" ""
else
  check_point 19 "false" "sin Repositories ni Services de API en el diff"
fi
check_point 20 "$TOUCHES_API_SERVICE" "sin Services de API en el diff"
if any_true "$TOUCHES_EXCEPTION" "$TOUCHES_API_SERVICE"; then
  check_point 21 "true" ""
else
  check_point 21 "false" "sin excepciones de dominio ni Services de API en el diff"
fi
check_point 22 "$TOUCHES_MIGRATION" "sin archivos en database/migrations/ en el diff"
check_point 23 "$TOUCHES_MODEL" "sin archivos en app/Models en el diff"

# Ordenar la lista de puntos vivos para que el mensaje sea legible.
POINTS_LIVE="$(printf '%s\n' $POINTS_LIVE | sort -n -u | tr '\n' ' ')"

# --- ¿Diff apto para dod-reviewer-lite? ---
# Solo si NINGUNA categoría especial aparece en el diff (todo lo Laravel/API
# específico queda descartado) y el tamaño está bajo el umbral. Si toca
# aunque sea una ruta sensible, va siempre a dod-reviewer completo.
LINE_THRESHOLD=60
FILE_THRESHOLD=3
SENSITIVE=false
if any_true "$TOUCHES_BLADE" "$TOUCHES_MIGRATION" "$TOUCHES_MODEL" "$TOUCHES_CONTROLLER" \
            "$TOUCHES_API_CONTROLLER" "$TOUCHES_API_RESOURCE" "$TOUCHES_API_FILTER" \
            "$TOUCHES_REPOSITORY" "$TOUCHES_API_SERVICE" "$TOUCHES_EXCEPTION" \
            "$TOUCHES_FORM_REQUEST" "$TOUCHES_JOB_COMMAND" "$TOUCHES_CATCH"; then
  SENSITIVE=true
fi
if [ "$NUM_LINES" -gt "$LINE_THRESHOLD" ] || [ "$NUM_FILES" -gt "$FILE_THRESHOLD" ]; then
  SENSITIVE=true
fi

if [ "$SENSITIVE" = "true" ]; then
  REVIEWER_HINT="Usa el subagente dod-reviewer (revisión completa) — el diff toca al menos una ruta sensible (controlador, migración, modelo, algo del ecosistema de API, Form Request, Job/Command, o un catch nuevo) y/o supera el umbral de tamaño ($FILE_THRESHOLD archivos / $LINE_THRESHOLD líneas)."
else
  REVIEWER_HINT="Este diff es pequeño ($NUM_FILES archivo(s), $NUM_LINES línea(s)) y no toca ninguna ruta sensible: usa el subagente dod-reviewer-lite (mismo checklist auditable de 24 puntos, modelo más liviano) en vez de dod-reviewer."
fi

DISCARDED_BLOCK="(ninguno — todos los puntos quedan vivos)"
[ -n "$POINTS_DISCARDED" ] && DISCARDED_BLOCK="$POINTS_DISCARDED"

cat >&2 <<MSG_EOF
Hay cambios sin revisar contra el Definition of Done (intento $ATTEMPTS de $ATTEMPT_CAP).

$REVIEWER_HINT

Pre-filtrado mecánico según los archivos del diff (no re-investigues estos puntos,
cítalos N/A con la razón dada tal cual):
$DISCARDED_BLOCK
Puntos vivos — evalúalos a fondo con evidencia archivo:línea real: $POINTS_LIVE

Antes de dar esta tarea por terminada:
1. Invoca al subagente correspondiente (Task/Agent tool, subagent_type "dod-reviewer" o "dod-reviewer-lite" según arriba) contra el diff actual.
2. Resuelve cualquier hallazgo marcado FAIL.
3. Si el veredicto final es APROBADO, el subagente debe ejecutar exactamente:
   bash "$MARK_SCRIPT"
MSG_EOF

exit 2
