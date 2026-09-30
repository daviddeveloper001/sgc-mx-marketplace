#!/usr/bin/env bash
# tests/run-dod-tests.sh
#
# Pruebas de regresión del gate de cierre (sgc-core) y sus módulos de stack
# (sgc-laravel, sgc-nestjs). Crea repos git desechables en un directorio
# temporal, con un HOME falso (no toca tu ~/.claude), y ejecuta los hooks tal
# como los llama Claude Code: JSON por stdin; exit 2 + stderr = bloqueo.
#
# Uso:  bash tests/run-dod-tests.sh
# Requiere git, node y bash. Sale con código ≠ 0 si alguna prueba falla.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
P="$REPO_ROOT/plugins"
GATE="$P/sgc-core/hooks/dod-stop-gate.sh"
MARK="$P/sgc-core/hooks/dod-mark-approved.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dod-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home"
mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL="$WORK/gitconfig"
git config --global user.email test@example.com
git config --global user.name dod-tests
git config --global init.defaultBranch main
git config --global core.autocrlf false

PASS=0
FAIL=0
MSG="$WORK/last-msg"
EXIT_CODE=0

ok()   { PASS=$((PASS + 1)); echo "  ok   $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "  FAIL $1"; sed 's/^/       | /' "$MSG" | head -40; }

# gate <session> <project_dir>
gate() {
  echo "{\"session_id\":\"$1\"}" | CLAUDE_PROJECT_DIR="$2" bash "$GATE" 2> "$MSG"
  EXIT_CODE=$?
}
# register <session> <project_dir> <plugin>
register() {
  echo "{\"session_id\":\"$1\"}" | CLAUDE_PROJECT_DIR="$2" node "$P/$3/hooks/register-dod-module.js"
}
expect_exit()     { if [ "$EXIT_CODE" = "$1" ]; then ok "$2"; else bad "$2 (exit=$EXIT_CODE, esperado $1)"; fi; }
expect_msg()      { if grep -qF -- "$1" "$MSG"; then ok "$2"; else bad "$2 (falta: $1)"; fi; }
expect_no_msg()   { if grep -qF -- "$1" "$MSG"; then bad "$2 (sobra: $1)"; else ok "$2"; fi; }
new_repo() {
  rm -rf "$WORK/$1"; mkdir -p "$WORK/$1"; git -C "$WORK/$1" init -q
}
commit_all() { git -C "$1" add -A && git -C "$1" commit -qm "$2"; }

# ---------------------------------------------------------------------------
echo "Laravel"
L="$WORK/lara"; new_repo lara
echo '{"require":{"laravel/framework":"^12.0"}}' > "$L/composer.json"
mkdir -p "$L/app/Services" "$L/resources/js"
echo '<?php // base' > "$L/app/Services/Foo.php"
commit_all "$L" init
S=sess-lara
register $S "$L" sgc-laravel
if grep -qx 'root=.' "$HOME/.claude/dod-state/sessions/$S/modules/laravel.mod"; then ok "registra el módulo laravel con root=."; else bad "registro laravel"; fi

gate $S "$L"; expect_exit 0 "sin cambios deja cerrar"

echo '<?php class Bar { function a(){ try{}catch(\Exception $e){} } }' > "$L/app/Services/Bar.php"
gate $S "$L"; expect_exit 2 "archivo nuevo sin git add bloquea"
expect_msg "Subagente: sgc-laravel:dod-reviewer" "catch nuevo => revisión completa"
expect_msg "LAR-4" "catch en archivo no trackeado activa LAR-4"
expect_msg "LAR-1: N/A" "sin controladores => LAR-1 N/A"

(cd "$L/app/Services" && env -u CLAUDE_PROJECT_DIR bash "$MARK" laravel "$L" >/dev/null)
gate $S "$L"; expect_exit 0 "aprobación registrada desde una subcarpeta se respeta"

echo '<?php // otro cambio' >> "$L/app/Services/Foo.php"
gate $S "$L"; expect_exit 2 "cambio tras aprobar vuelve a bloquear"; expect_msg "intento 1 de 2" "contador reiniciado"
gate $S "$L"; expect_msg "intento 2 de 2" "segundo intento"
gate $S "$L"; expect_exit 0 "válvula: tercer intento deja pasar"; expect_msg "Aviso" "válvula avisa"

rm "$L/app/Services/Bar.php"; commit_all "$L" c2
echo '<?php // chico' >> "$L/app/Services/Foo.php"
gate $S "$L"; expect_msg "Subagente: sgc-laravel:dod-reviewer-lite" "diff chico sin rutas sensibles => lite"

git -C "$L" checkout -q -- .
echo 'let a = 1' > "$L/resources/js/app.js"
gate $S "$L"; expect_msg "Subagente: sgc-core:dod-reviewer" "diff solo JS en repo Laravel => core"
bash "$MARK" core "$L" >/dev/null; gate $S "$L"; expect_exit 0 "aprobación core libera"

bash "$MARK" > "$MSG" 2>&1; EXIT_CODE=$?; expect_exit 1 "mark sin módulo => error de uso"
bash "$MARK" '../x' > "$MSG" 2>&1; EXIT_CODE=$?; expect_exit 1 "mark con módulo inválido => error"

# ---------------------------------------------------------------------------
echo "NestJS"
N="$WORK/nest"; new_repo nest
echo '{"dependencies":{"@nestjs/core":"^11.0.0"}}' > "$N/package.json"
mkdir -p "$N/src/cat"; echo 'export const x = 1;' > "$N/src/cat/util.ts"
commit_all "$N" init
S=sess-nest
register $S "$N" sgc-laravel; register $S "$N" sgc-nestjs
if [ ! -f "$HOME/.claude/dod-state/sessions/$S/modules/laravel.mod" ] && [ -f "$HOME/.claude/dod-state/sessions/$S/modules/nestjs.mod" ]; then
  ok "en repo Nest solo se registra nestjs"; else bad "registro en repo Nest"; fi
cat > "$N/src/cat/cat.service.ts" <<'EOF'
import { Injectable } from '@nestjs/common';
interface CatInput { name: string }
@Injectable()
export class CatService { create(d: any) { return d; } }
EOF
gate $S "$N"; expect_msg "Subagente: sgc-nestjs:dod-reviewer" "service Nest => revisor Nest"
expect_msg "NEST-1 NEST-3 NEST-4 NEST-5 NEST-6" "service con interface/import => NEST-1,3,4,5,6 vivos"
expect_msg "NEST-2: N/A" "sin DTO/controller => NEST-2 N/A"
rm "$N/src/cat/cat.service.ts"; echo 'export const y = 2;' >> "$N/src/cat/util.ts"
gate $S "$N"; expect_msg "(evaluación completa, con archivo:línea): NEST-1 " "util.ts sin imports => solo NEST-1 vivo"

# ---------------------------------------------------------------------------
echo "Monorepo"
M="$WORK/mono"; new_repo mono
mkdir -p "$M/backend/app/Http/Controllers" "$M/apps/api/src" "$M/frontend/src" "$M/node_modules/fake"
echo '{"require":{"laravel/framework":"^12"}}' > "$M/backend/composer.json"
echo '{"dependencies":{"@nestjs/core":"^11"}}' > "$M/apps/api/package.json"
echo '{"dependencies":{"vue":"^3"}}' > "$M/frontend/package.json"
echo '{"dependencies":{"@nestjs/core":"^11"}}' > "$M/node_modules/fake/package.json"
echo 'node_modules/' > "$M/.gitignore"
commit_all "$M" init
S=sess-mono
register $S "$M" sgc-laravel; register $S "$M" sgc-nestjs
MODS="$HOME/.claude/dod-state/sessions/$S/modules"
if grep -qx 'root=backend' "$MODS/laravel.mod" && grep -qx 'root=apps/api' "$MODS/nestjs.mod" \
   && [ "$(grep -c '^root=' "$MODS/nestjs.mod")" = 1 ]; then
  ok "raíces backend/ y apps/api (ignora node_modules)"; else bad "raíces del monorepo"; fi
echo 'const a: number = 1' > "$M/frontend/src/main.ts"
gate $S "$M"; expect_msg "[core] — PENDIENTE" "TS de frontend no activa Nest"
echo '<?php class C {}' > "$M/backend/app/Http/Controllers/C.php"
echo 'export class S {}' > "$M/apps/api/src/s.service.ts"
gate $S "$M"; expect_msg "[módulo laravel] — PENDIENTE" "monorepo: laravel pendiente"; expect_msg "[módulo nestjs] — PENDIENTE" "monorepo: nestjs pendiente"
bash "$MARK" laravel "$M" >/dev/null; gate $S "$M"
expect_exit 2 "con una sola aprobación sigue bloqueado"; expect_msg "[módulo laravel] — YA APROBADO" "marca el módulo ya aprobado"
bash "$MARK" nestjs "$M" >/dev/null; gate $S "$M"; expect_exit 0 "con ambas aprobaciones libera"
register sess-sub "$M/apps/api/src" sgc-nestjs
if grep -qx 'root=apps/api' "$HOME/.claude/dod-state/sessions/sess-sub/modules/nestjs.mod"; then
  ok "sesión abierta en subcarpeta registra root=apps/api"; else bad "registro desde subcarpeta"; fi

# ---------------------------------------------------------------------------
echo "Robustez"
S=sess-broken
mkdir -p "$HOME/.claude/dod-state/sessions/$S/modules"
printf 'name=nestjs\nprefilter=%s\nroot=.\n' "$WORK/no-existe.sh" > "$HOME/.claude/dod-state/sessions/$S/modules/nestjs.mod"
echo 'export const z = 3;' >> "$N/src/cat/util.ts"
gate $S "$N"; expect_msg "su pre-filtro no existe" "pre-filtro ausente => advertencia"; expect_msg "[core] — PENDIENTE" "pre-filtro ausente => cae a core"
printf '#!/usr/bin/env bash\nexit 3\n' > "$WORK/crash.sh"
printf 'name=nestjs\nprefilter=%s\nroot=.\n' "$WORK/crash.sh" > "$HOME/.claude/dod-state/sessions/$S/modules/nestjs.mod"
gate $S "$N"; expect_msg "el pre-filtro del módulo 'nestjs' falló" "pre-filtro que falla => advertencia"; expect_msg "[módulo nestjs] — PENDIENTE" "pre-filtro que falla => exige el módulo"
# Sesión aparte: con la misma sesión y el mismo diff, este sería el 3.er
# intento y la válvula dejaría pasar (comportamiento correcto, otra prueba).
S=sess-invalid
mkdir -p "$HOME/.claude/dod-state/sessions/$S/modules"
printf 'name=../evil\nprefilter=%s\n' "$P/sgc-nestjs/dod/prefilter.sh" > "$HOME/.claude/dod-state/sessions/$S/modules/evil.mod"
gate $S "$N"; expect_msg "registro de módulo inválido ignorado" "nombre de módulo inválido => ignorado"
gate sin-registro "$WORK/lara"; expect_exit 0 "diff ya aprobado por core en otra sesión sigue aprobado"

NOGIT="$WORK/nogit"; mkdir -p "$NOGIT"; echo x > "$NOGIT/a.txt"
gate $S "$NOGIT"; expect_exit 0 "fuera de un repo git no bloquea"
echo '{"session_id":"sess-x"}' | CLAUDE_PROJECT_DIR="$NOGIT" node "$P/sgc-laravel/hooks/register-dod-module.js" > "$MSG" 2>&1
if [ ! -s "$MSG" ]; then ok "registro fuera de git: silencioso"; else bad "registro fuera de git imprimió algo"; fi
echo 'no-es-json' | CLAUDE_PROJECT_DIR="$L" node "$P/sgc-laravel/hooks/register-dod-module.js" > "$MSG" 2>&1; EXIT_CODE=$?
expect_exit 0 "registro con stdin inválido no rompe la sesión"

# ---------------------------------------------------------------------------
echo "Estructura"
if cmp -s "$P/sgc-laravel/hooks/register-dod-module.js" "$P/sgc-nestjs/hooks/register-dod-module.js"; then
  ok "register-dod-module.js idéntico en los plugins de stack"; else bad "register-dod-module.js difiere entre plugins"; fi
for agent in "$P"/*/agents/*.md; do
  plugin_of_agent="$(basename "$(dirname "$(dirname "$agent")")")"
  missing=""
  for ref in $(awk '/^---$/{f++; next} f==1 && /^  - /{print $2}' "$agent"); do
    [ -f "$P/${ref%%:*}/skills/${ref#*:}/SKILL.md" ] || missing="$missing $ref"
  done
  if [ -z "$missing" ]; then ok "skills precargadas existen: $plugin_of_agent/$(basename "$agent")"; else echo "falta:$missing" > "$MSG"; bad "skills inexistentes en $plugin_of_agent/$(basename "$agent")"; fi
done

echo
echo "Resultado: $PASS ok, $FAIL fallidas"
[ "$FAIL" = 0 ]
