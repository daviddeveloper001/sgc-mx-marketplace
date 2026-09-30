#!/usr/bin/env bash
# hooks/dod-mark-approved.sh <modulo> [<raiz-del-proyecto>]   (plugin sgc-core)
#
# Ejecutar SOLO cuando un revisor de Definition of Done dio VEREDICTO:
# APROBADO (sin FAIL) para el diff vigente. Registra el hash de ese diff como
# aprobado por <modulo> ("core", "laravel", "nestjs", ...), para que
# dod-stop-gate.sh deje cerrar la tarea cuando todos los módulos que aplican
# al diff hayan aprobado.
#
# La línea exacta a ejecutar (ruta absoluta + módulo) la da siempre el
# mensaje de bloqueo de dod-stop-gate.sh — nunca hay que adivinarla.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dod-lib.sh
. "$SCRIPT_DIR/dod-lib.sh"

MODULE="${1:-}"
if ! dod_valid_module_name "$MODULE"; then
  echo "Uso: bash dod-mark-approved.sh <modulo>   (ej.: core, laravel, nestjs)" >&2
  echo "Usa la línea exacta que dio el mensaje de bloqueo de dod-stop-gate.sh." >&2
  exit 1
fi

# El gate pasa la raíz del proyecto como 2º argumento: la clave del estado se
# deriva de ella, y el Bash tool del revisor puede estar parado en otra
# carpeta (o no tener CLAUDE_PROJECT_DIR en su entorno).
PROJECT_DIR="${2:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

if ! git -C "$PROJECT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
  echo "No es un repo git; nada que registrar." >&2
  exit 1
fi

STATE_DIR="$DOD_HOME/$(dod_project_key "$PROJECT_DIR")"
mkdir -p "$STATE_DIR"

DIFF_HASH="$(dod_diff_hash "$PROJECT_DIR")"

echo "$DIFF_HASH" > "$STATE_DIR/approved-$MODULE.hash"
echo "Diff actual (hash ${DIFF_HASH:0:12}...) marcado como aprobado por el módulo '$MODULE'."
