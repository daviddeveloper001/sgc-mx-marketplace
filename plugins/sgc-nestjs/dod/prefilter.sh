#!/usr/bin/env bash
# dod/prefilter.sh  (plugin sgc-nestjs — módulo "nestjs" del gate de sgc-core)
#
# Mismo contrato que el pre-filtro de sgc-laravel (ver README.md, sección
# "Contrato de un módulo de stack"): recibe los archivos/diff del módulo por
# DOD_FILES / DOD_DIFF y responde ACTIVE, REVIEWER, LIVE y NA=<ID>|<razón>.
#
# NEST-1 (tipado estricto) se evalúa siempre que el diff toque TypeScript de
# Nest. Los demás se descartan solo si su archivo o su código disparador está
# objetivamente ausente del diff.
#
# Convenciones de nombre asumidas (las del CLI de Nest): *.controller.ts,
# *.service.ts, *.repository.ts, *.module.ts, *.dto.ts, *.interface.ts.
# Si tu proyecto usa otras, ajusta los patrones de "Categorías".

set -euo pipefail

FILES="$(cat "$DOD_FILES")"

has_match() {
  printf '%s\n' "$FILES" | grep -Eq "$1"
}

added_code_matches() {
  grep -Eq "$1" "$DOD_DIFF"
}

any_true() {
  for v in "$@"; do
    [ "$v" = "true" ] && return 0
  done
  return 1
}

# Aplica si el diff toca TypeScript (sin .d.ts) o la config de TypeScript
# dentro de las raíces Nest del repo.
TS_FILES="$(printf '%s\n' "$FILES" | grep -E '\.ts$' | grep -Ev '\.d\.ts$' || true)"
if [ -z "$TS_FILES" ] && ! has_match '(^|/)tsconfig[^/]*\.json$'; then
  echo "ACTIVE=false"
  exit 0
fi
echo "ACTIVE=true"

# --- Categorías -------------------------------------------------------------
TOUCHES_CONTROLLER=false; has_match '\.controller\.ts$' && TOUCHES_CONTROLLER=true
TOUCHES_SERVICE=false;    has_match '(\.service\.ts$|\.use-case\.ts$|/use-cases/)' && TOUCHES_SERVICE=true
TOUCHES_REPOSITORY=false; has_match '(\.repository\.ts$|/repositories/)' && TOUCHES_REPOSITORY=true
TOUCHES_DTO=false;        has_match '(\.dto\.ts$|/dto/|/dtos/)' && TOUCHES_DTO=true
TOUCHES_MAIN=false;       has_match '(^|/)main\.ts$' && TOUCHES_MAIN=true
TOUCHES_MODULE=false;     has_match '\.module\.ts$' && TOUCHES_MODULE=true
TOUCHES_INTERFACE=false
if has_match '\.interface\.ts$' || added_code_matches '^\+(.*[^A-Za-z0-9_])?interface[[:space:]]+[A-Za-z_]'; then
  TOUCHES_INTERFACE=true
fi
TOUCHES_IMPORTS=false
if added_code_matches '^\+[[:space:]]*import[[:space:]]' || added_code_matches 'forwardRef'; then
  TOUCHES_IMPORTS=true
fi

# --- Puntos -----------------------------------------------------------------
LIVE="NEST-1"

check_point() {
  # $1 = ID, $2 = true/false, $3 = razón si se descarta
  if [ "$2" = "true" ]; then
    LIVE="$LIVE $1"
  else
    echo "NA=$1|$3"
  fi
}

if any_true "$TOUCHES_DTO" "$TOUCHES_CONTROLLER" "$TOUCHES_MAIN"; then
  check_point NEST-2 true ""
else
  check_point NEST-2 false "sin DTOs, controladores ni main.ts en el diff"
fi
if any_true "$TOUCHES_SERVICE" "$TOUCHES_REPOSITORY" "$TOUCHES_CONTROLLER"; then
  check_point NEST-3 true ""
else
  check_point NEST-3 false "sin services, repositories ni controladores en el diff"
fi
check_point NEST-4 "$TOUCHES_INTERFACE" "no se declaró ni modificó ninguna interfaz (ni archivos .interface.ts)"
if any_true "$TOUCHES_REPOSITORY" "$TOUCHES_SERVICE"; then
  check_point NEST-5 true ""
else
  check_point NEST-5 false "sin repositories ni services en el diff"
fi
if any_true "$TOUCHES_MODULE" "$TOUCHES_IMPORTS"; then
  check_point NEST-6 true ""
else
  check_point NEST-6 false "sin *.module.ts, imports nuevos ni forwardRef en el diff"
fi

echo "LIVE=$(printf '%s\n' $LIVE | sort -t- -k2 -n -u | tr '\n' ' ')"

# Por ahora NestJS tiene un solo revisor (sin variante lite).
echo "REVIEWER=sgc-nestjs:dod-reviewer"
echo "REVIEWER_NOTE=Revisión del módulo NestJS (CORE-* + NEST-*)."
