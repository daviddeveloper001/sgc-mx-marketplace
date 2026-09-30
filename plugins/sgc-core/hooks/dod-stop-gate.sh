#!/usr/bin/env bash
# hooks/dod-stop-gate.sh  (plugin sgc-core)
#
# Stop hook: bloquea el cierre de una tarea de código hasta que el diff
# vigente haya sido aprobado por el revisor de Definition of Done que le
# corresponde.
#
# --- Arquitectura: core + módulos (v1.0.0) ---
# Este es el ÚNICO hook Stop del sistema. Los plugins de stack (sgc-laravel,
# sgc-nestjs, y los que se agreguen) no bloquean nada por su cuenta: en su
# hook SessionStart registran un "módulo" en
#   ~/.claude/dod-state/sessions/<session_id>/modules/<modulo>.mod
# con su nombre, la ruta a su pre-filtro (dod/prefilter.sh) y las carpetas
# raíz de su stack dentro del repo. Este gate:
#
#   1. Calcula el hash del diff (igual que siempre) y sale si no hay cambios
#      o si ya está aprobado.
#   2. Para cada módulo registrado en ESTA sesión, le pasa los archivos del
#      diff que caen en sus raíces. El pre-filtro responde si el módulo
#      aplica (ACTIVE), qué revisor usar, qué puntos quedan vivos y cuáles
#      se descartan mecánicamente (con su razón).
#   3. Los puntos CORE-* (agnósticos) están siempre vivos y los evalúa el
#      revisor del módulo junto con los suyos. Si ningún módulo aplica, el
#      diff lo revisa sgc-core:dod-reviewer (solo CORE-*).
#   4. El cierre se libera cuando TODOS los módulos activos (o "core" si no
#      hay ninguno) registraron su aprobación para este mismo diff.
#
# Contrato de un pre-filtro (para agregar un stack nuevo): ver README.md,
# sección "Contrato de un módulo de stack".
#
# Máximo 2 bloqueos por diff: al tercero deja pasar con una advertencia,
# para nunca generar un loop infinito.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dod-lib.sh
. "$SCRIPT_DIR/dod-lib.sh"
MARK_SCRIPT="$SCRIPT_DIR/dod-mark-approved.sh"

INPUT_JSON="$(cat)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Si no es un repo git, no hay nada que este hook pueda revisar.
if ! git -C "$PROJECT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
  exit 0
fi

DIFF_HASH="$(dod_diff_hash "$PROJECT_DIR")"

# Sin cambios pendientes: nada que revisar, dejar cerrar.
if [ "$DIFF_HASH" = "$DOD_EMPTY_HASH" ]; then
  exit 0
fi

SESSION_ID="$(printf '%s' "$INPUT_JSON" | dod_json_field session_id)"
[ -n "$SESSION_ID" ] || SESSION_ID="unknown-session"

STATE_DIR="$DOD_HOME/$(dod_project_key "$PROJECT_DIR")"
mkdir -p "$STATE_DIR"

TOPLEVEL="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel)"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dod-gate.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

# ---------------------------------------------------------------------------
# Archivos del diff. Incluye los no trackeados (respetando .gitignore): un
# controlador nuevo sin `git add` ya activa su punto en el pre-filtrado.
# Rutas relativas a la raíz del repo, con "/" (también en Windows).
# ---------------------------------------------------------------------------
git -C "$TOPLEVEL" diff HEAD --name-only 2>/dev/null > "$TMP_DIR/tracked" || true
git -C "$TOPLEVEL" ls-files --others --exclude-standard 2>/dev/null > "$TMP_DIR/untracked" || true
sort -u "$TMP_DIR/tracked" "$TMP_DIR/untracked" | grep . > "$TMP_DIR/all-files" || true

count_lines_of_untracked() {
  # $1 = archivo con la lista de rutas no trackeadas
  local total=0 n path
  while IFS= read -r path || [ -n "$path" ]; do
    [ -f "$TOPLEVEL/$path" ] || continue
    n="$(wc -l < "$TOPLEVEL/$path" | tr -d '[:space:]')"
    total=$((total + ${n:-0}))
  done < "$1"
  echo "$total"
}

numstat_total() {
  # stdin = salida de git diff --numstat. Archivos binarios cuentan como 0.
  awk '{a=$1+0; r=$2+0; t+=a+r} END{print t+0}'
}

TOTAL_FILES="$(grep -c . "$TMP_DIR/all-files" || true)"
TOTAL_LINES=$(( $(git -C "$TOPLEVEL" diff HEAD --numstat 2>/dev/null | numstat_total) \
              + $(count_lines_of_untracked "$TMP_DIR/untracked") ))

# ---------------------------------------------------------------------------
# Módulos de stack registrados en esta sesión.
# ---------------------------------------------------------------------------
MODULES_DIR="$DOD_HOME/sessions/$SESSION_ID/modules"
ACTIVE_MODULES=""
MODULE_BLOCKS=""
WARNINGS=""

add_warning() {
  WARNINGS="${WARNINGS}  - $1
"
}

# Filtra all-files a las raíces del módulo. $1 = raíces (una por línea).
# Las raíces van por ENVIRON y no por -v: el awk de macOS (BWK) rechaza un
# -v con saltos de línea ("newline in string").
filter_by_roots() {
  DOD_ROOTS="$1" awk '
    BEGIN { n = split(ENVIRON["DOD_ROOTS"], r, "\n") }
    {
      for (i = 1; i <= n; i++) {
        if (r[i] == "") continue
        if (r[i] == "." || index($0, r[i] "/") == 1) { print; next }
      }
    }' "$TMP_DIR/all-files"
}

run_module() {
  local mod_file="$1"
  local name="" prefilter="" roots="" line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      name=*)      name="${line#name=}" ;;
      prefilter=*) prefilter="${line#prefilter=}" ;;
      root=*)      roots="${roots}${line#root=}
" ;;
    esac
  done < "$mod_file"

  if ! dod_valid_module_name "$name"; then
    add_warning "registro de módulo inválido ignorado: $mod_file"
    return 0
  fi
  if [ ! -f "$prefilter" ]; then
    add_warning "el módulo '$name' está registrado pero su pre-filtro no existe ($prefilter). ¿Se actualizó o desinstaló el plugin a mitad de sesión? Reinicia la sesión para re-registrarlo."
    return 0
  fi
  [ -n "$roots" ] || roots="."

  local files="$TMP_DIR/$name.files" diff="$TMP_DIR/$name.diff"
  filter_by_roots "$roots" > "$files"
  # Sin archivos del diff dentro de las raíces de su stack: no aplica.
  [ -s "$files" ] || return 0

  # Diff del módulo: cambios trackeados dentro de sus raíces + el contenido
  # de sus archivos no trackeados como líneas agregadas ("+"), para que los
  # pre-filtros que buscan código nuevo (catch, interface, import...) también
  # lo vean sin depender de `git add`.
  local root
  : > "$diff"
  while IFS= read -r root; do
    [ -n "$root" ] || continue
    if [ "$root" = "." ]; then
      git -C "$TOPLEVEL" diff HEAD 2>/dev/null >> "$diff" || true
      break
    fi
    git -C "$TOPLEVEL" diff HEAD -- "$root" 2>/dev/null >> "$diff" || true
  done <<ROOTS_EOF
$roots
ROOTS_EOF

  local path
  while IFS= read -r path || [ -n "$path" ]; do
    [ -n "$path" ] || continue
    if grep -qxF "$path" "$TMP_DIR/untracked" && [ -f "$TOPLEVEL/$path" ]; then
      printf '+++ b/%s\n' "$path" >> "$diff"
      awk '{ print "+" $0 }' "$TOPLEVEL/$path" >> "$diff"
    fi
  done < "$files"

  local num_files num_lines
  num_files="$(grep -c . "$files" || true)"
  num_lines="$(grep -c '^+[^+]' "$diff" || true)"

  local out
  if ! out="$(DOD_PROJECT_DIR="$TOPLEVEL" DOD_FILES="$files" DOD_DIFF="$diff" \
              DOD_NUM_FILES="$num_files" DOD_NUM_LINES="$num_lines" \
              DOD_TOTAL_FILES="$TOTAL_FILES" DOD_TOTAL_LINES="$TOTAL_LINES" \
              bash "$prefilter" 2> "$TMP_DIR/$name.err")"; then
    add_warning "el pre-filtro del módulo '$name' falló ($(head -c 300 "$TMP_DIR/$name.err" | tr '\n' ' ')). Se exige su revisión completa."
    out="ACTIVE=true
REVIEWER=
LIVE=(todos los puntos del módulo — el pre-filtro no pudo descartar ninguno)"
  fi

  local active="" reviewer="" note="" live="" na=""
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      ACTIVE=*)        active="${line#ACTIVE=}" ;;
      REVIEWER=*)      reviewer="${line#REVIEWER=}" ;;
      REVIEWER_NOTE=*) note="${line#REVIEWER_NOTE=}" ;;
      LIVE=*)          live="${live} ${line#LIVE=}" ;;
      NA=*)
        local item="${line#NA=}"
        na="${na}    - ${item%%|*}: N/A — ${item#*|}
" ;;
    esac
  done <<OUT_EOF
$out
OUT_EOF

  [ "$active" = "true" ] || return 0
  [ -n "$reviewer" ] || reviewer="(el que declare el plugin sgc-$name; si dudas, su dod-reviewer completo)"

  ACTIVE_MODULES="$ACTIVE_MODULES $name"

  local status="PENDIENTE"
  if [ "$(cat "$STATE_DIR/approved-$name.hash" 2>/dev/null || true)" = "$DIFF_HASH" ]; then
    status="YA APROBADO para este diff"
  fi

  [ -n "$na" ] || na="    (ninguno — todos los puntos del módulo quedan vivos)
"
  MODULE_BLOCKS="${MODULE_BLOCKS}
[módulo $name] — $status
  Subagente: $reviewer
  ${note:+$note
  }Puntos vivos del módulo (evaluación completa, con archivo:línea):${live}
  Descartados mecánicamente (repórtalos N/A con esta razón, sin re-investigar):
${na}  Si el veredicto es APROBADO, el revisor ejecuta:
    bash \"$MARK_SCRIPT\" $name \"$PROJECT_DIR\"
"
}

if [ -d "$MODULES_DIR" ]; then
  for mod_file in "$MODULES_DIR"/*.mod; do
    [ -f "$mod_file" ] || continue
    run_module "$mod_file"
  done
fi

# ---------------------------------------------------------------------------
# ¿Quién tiene que aprobar este diff?
# ---------------------------------------------------------------------------
REQUIRED="${ACTIVE_MODULES# }"
[ -n "$REQUIRED" ] || REQUIRED="core"

ALL_APPROVED=true
for module in $REQUIRED; do
  if [ "$(cat "$STATE_DIR/approved-$module.hash" 2>/dev/null || true)" != "$DIFF_HASH" ]; then
    ALL_APPROVED=false
  fi
done

# Este diff exacto ya fue aprobado por todos los revisores que le tocan.
if [ "$ALL_APPROVED" = "true" ]; then
  exit 0
fi

# --- control de intentos para no bloquear infinitamente ---
# El contador se guarda junto con el hash del diff al que pertenece: si el
# diff cambió desde el último bloqueo, el contador arranca de nuevo.
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
  echo "[dod-stop-gate] Aviso: se permitió cerrar sin aprobación explícita ($REQUIRED) tras $ATTEMPTS intentos. Revisa el diff manualmente." >&2
  exit 0
fi

if [ -z "${ACTIVE_MODULES# }" ]; then
  MODULE_BLOCKS="
Ningún módulo de stack aplica a este diff (no hay un plugin de stack
registrado en esta sesión, o el diff no toca archivos de su stack).

[core] — PENDIENTE
  Subagente: sgc-core:dod-reviewer (solo puntos CORE)
  Si el veredicto es APROBADO, el revisor ejecuta:
    bash \"$MARK_SCRIPT\" core \"$PROJECT_DIR\"
"
fi

WARNINGS_BLOCK=""
[ -n "$WARNINGS" ] && WARNINGS_BLOCK="
Advertencias del gate:
$WARNINGS"

cat >&2 <<MSG_EOF
Hay cambios sin revisar contra el Definition of Done (intento $ATTEMPTS de $ATTEMPT_CAP).
Diff: $TOTAL_FILES archivo(s), $TOTAL_LINES línea(s).

Puntos CORE (agnósticos, siempre vivos; se evalúan sobre TODO el diff con
evidencia archivo:línea): $DOD_CORE_POINTS
$MODULE_BLOCKS$WARNINGS_BLOCK
Antes de dar esta tarea por terminada:
1. Invoca cada subagente PENDIENTE de arriba (Agent tool, subagent_type exacto)
   contra el diff actual, pasándole este mensaje completo.
2. Resuelve cualquier hallazgo marcado FAIL.
3. Cada revisor con VEREDICTO: APROBADO ejecuta su línea "bash ... <módulo>".
   El cierre se libera cuando todos los módulos listados aprobaron este mismo diff.
MSG_EOF

exit 2
