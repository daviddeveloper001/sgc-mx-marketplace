#!/usr/bin/env bash
# dod/prefilter.sh  (plugin sgc-laravel — módulo "laravel" del gate de sgc-core)
#
# Lo ejecuta dod-stop-gate.sh (sgc-core) en cada intento de cierre. Recibe
# solo los archivos del diff que caen dentro de las raíces Laravel del repo y
# responde, línea por línea, qué puntos LAR-* aplican. Los puntos CORE-* no
# son asunto de este archivo: el gate los deja siempre vivos.
#
# Entrada (variables de entorno, las pone el gate):
#   DOD_FILES        archivo con las rutas del diff de este módulo (una por línea)
#   DOD_DIFF         archivo con el diff de este módulo (+ los no trackeados
#                    como líneas "+")
#   DOD_NUM_FILES / DOD_NUM_LINES      tamaño del diff de este módulo
#   DOD_TOTAL_FILES / DOD_TOTAL_LINES  tamaño del diff completo
#   DOD_PROJECT_DIR  raíz del repo
#
# Salida (stdout):
#   ACTIVE=true|false
#   REVIEWER=<subagent_type>
#   REVIEWER_NOTE=<una línea>
#   LIVE=<ID> <ID> ...
#   NA=<ID>|<razón>          (una línea por punto descartado)
#
# Un punto solo se descarta cuando el tipo de archivo que lo activaría está
# objetivamente ausente del diff — nunca por adivinanza. LAR-2 y LAR-6 se
# evalúan siempre que el diff toque PHP.
#
# Rutas: convención estándar de Laravel (Http/Controllers/, app/Models/,
# database/migrations/...). Si tu proyecto usa otra estructura, ajusta los
# patrones de la sección "Categorías" antes de confiar en el atajo.

set -euo pipefail

FILES="$(cat "$DOD_FILES")"

has_match() {
  printf '%s\n' "$FILES" | grep -Eq "$1"
}

has_added_catch() {
  grep -Eq '^\+[^+].*catch[[:space:]]*\(' "$DOD_DIFF"
}

any_true() {
  for v in "$@"; do
    [ "$v" = "true" ] && return 0
  done
  return 1
}

# El módulo solo aplica si el diff toca PHP (incluye .blade.php, lang/*.php,
# migraciones...). Un diff Laravel que solo toca JS/CSS/Markdown lo revisa el
# core con sus puntos agnósticos.
if ! has_match '\.php$'; then
  echo "ACTIVE=false"
  exit 0
fi
echo "ACTIVE=true"

# --- Categorías -------------------------------------------------------------
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

# --- Puntos -----------------------------------------------------------------
LIVE="LAR-2 LAR-6"

check_point() {
  # $1 = ID, $2 = true/false, $3 = razón si se descarta
  if [ "$2" = "true" ]; then
    LIVE="$LIVE $1"
  else
    echo "NA=$1|$3"
  fi
}

check_point LAR-1 "$TOUCHES_CONTROLLER" "sin archivos bajo Http/Controllers/ en el diff"
if any_true "$TOUCHES_BLADE" "$TOUCHES_CONTROLLER" "$TOUCHES_API_RESOURCE"; then
  check_point LAR-3 true ""
else
  check_point LAR-3 false "sin vistas Blade, controladores ni Resources de API en el diff"
fi
check_point LAR-4 "$TOUCHES_CATCH" "no se agregó ni modificó ningún bloque catch"
check_point LAR-5 "$TOUCHES_BLADE" "sin archivos .blade.php en el diff"
check_point LAR-7 "$TOUCHES_JOB_COMMAND" "sin Jobs/Commands/Listeners en el diff"
if any_true "$TOUCHES_CONTROLLER" "$TOUCHES_FORM_REQUEST"; then
  check_point LAR-8 true ""
else
  check_point LAR-8 false "sin controladores ni Form Requests en el diff"
fi
if any_true "$TOUCHES_API_CONTROLLER" "$TOUCHES_API_RESOURCE"; then
  check_point LAR-9 true ""
else
  check_point LAR-9 false "sin controladores ni Resources de API en el diff"
fi
check_point LAR-10 "$TOUCHES_API_CONTROLLER" "sin controladores bajo Http/Controllers/Api en el diff"
if any_true "$TOUCHES_API_CONTROLLER" "$TOUCHES_API_FILTER"; then
  check_point LAR-11 true ""
else
  check_point LAR-11 false "sin controladores de API ni Filters en el diff"
fi
if any_true "$TOUCHES_REPOSITORY" "$TOUCHES_API_SERVICE"; then
  check_point LAR-12 true ""
else
  check_point LAR-12 false "sin Repositories ni Services de API en el diff"
fi
check_point LAR-13 "$TOUCHES_API_SERVICE" "sin Services de API en el diff"
if any_true "$TOUCHES_EXCEPTION" "$TOUCHES_API_SERVICE"; then
  check_point LAR-14 true ""
else
  check_point LAR-14 false "sin excepciones de dominio ni Services de API en el diff"
fi
check_point LAR-15 "$TOUCHES_MIGRATION" "sin archivos en database/migrations/ en el diff"
check_point LAR-16 "$TOUCHES_MODEL" "sin archivos en app/Models en el diff"

echo "LIVE=$(printf '%s\n' $LIVE | sort -t- -k2 -n -u | tr '\n' ' ')"

# --- ¿Revisión completa o lite? ---------------------------------------------
# Lite solo si NINGUNA categoría sensible aparece y el diff COMPLETO (no solo
# la parte PHP) está bajo el umbral: el revisor también evalúa los CORE-*
# sobre todo el diff. Umbrales arbitrarios, no medidos: ajústalos si ves
# diffs mal clasificados.
LINE_THRESHOLD=60
FILE_THRESHOLD=3
SENSITIVE=false
if any_true "$TOUCHES_BLADE" "$TOUCHES_MIGRATION" "$TOUCHES_MODEL" "$TOUCHES_CONTROLLER" \
            "$TOUCHES_API_CONTROLLER" "$TOUCHES_API_RESOURCE" "$TOUCHES_API_FILTER" \
            "$TOUCHES_REPOSITORY" "$TOUCHES_API_SERVICE" "$TOUCHES_EXCEPTION" \
            "$TOUCHES_FORM_REQUEST" "$TOUCHES_JOB_COMMAND" "$TOUCHES_CATCH"; then
  SENSITIVE=true
fi
if [ "${DOD_TOTAL_LINES:-0}" -gt "$LINE_THRESHOLD" ] || [ "${DOD_TOTAL_FILES:-0}" -gt "$FILE_THRESHOLD" ]; then
  SENSITIVE=true
fi

if [ "$SENSITIVE" = "true" ]; then
  echo "REVIEWER=sgc-laravel:dod-reviewer"
  echo "REVIEWER_NOTE=Revisión completa: el diff toca al menos una ruta sensible (controlador, migración, modelo, ecosistema de API, Form Request, Job/Command o un catch nuevo) y/o supera $FILE_THRESHOLD archivos / $LINE_THRESHOLD líneas."
else
  echo "REVIEWER=sgc-laravel:dod-reviewer-lite"
  echo "REVIEWER_NOTE=Diff pequeño (${DOD_TOTAL_FILES:-0} archivo(s), ${DOD_TOTAL_LINES:-0} línea(s)) sin rutas sensibles: basta la variante lite (mismo checklist auditable, modelo más liviano)."
fi
