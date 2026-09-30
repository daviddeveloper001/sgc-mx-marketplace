# sgc-mx — marketplace personal de Claude Code

Marketplace de Claude Code con los estándares de desarrollo de SGC-MX, divididos
en plugins por stack:

| Plugin | Qué trae | Dónde instalarlo |
|---|---|---|
| `sgc-core` | 10 skills `core-*` agnósticas + `process-definition-of-done` (checklist CORE-*), el revisor `sgc-core:dod-reviewer` y **el único hook de cierre** (`dod-stop-gate`) | Todo repo (los plugins de stack lo instalan solos) |
| `sgc-laravel` | 16 skills `laravel-*` + `multi-tenant-architecture` + `laravel-definition-of-done` (LAR-*), revisores `sgc-laravel:dod-reviewer` y `dod-reviewer-lite`, módulo de cierre Laravel | Repos Laravel |
| `sgc-nestjs` | 6 skills `nestjs-*` + `nestjs-definition-of-done` (NEST-*), revisor `sgc-nestjs:dod-reviewer`, módulo de cierre NestJS | Repos NestJS |

> **Siempre `sgc-core` + el plugin de tu stack.** En la app de Claude
> (Personalizar → Plugins) instala los dos a mano: la app **no** resuelve el
> campo `dependencies`, así que instalar `sgc-laravel` no trae `sgc-core`. Sin
> `sgc-core` no hay hook de cierre ni skills `core-*`, y los revisores del
> stack quedan sin su criterio CORE.

```
sgc-mx-marketplace/
├── .claude-plugin/marketplace.json
├── .gitattributes                      # fuerza LF en .sh/.js/.json (Git Bash)
└── plugins/
    ├── sgc-core/
    │   ├── .claude-plugin/plugin.json
    │   ├── skills/                     # core-* + process-definition-of-done
    │   ├── agents/dod-reviewer.md      # sgc-core:dod-reviewer (solo CORE-*)
    │   ├── hooks/
    │   │   ├── hooks.json              # SessionStart (limpieza) + Stop (gate)
    │   │   ├── dod-stop-gate.sh        # el gate: hash, intentos, módulos, mensaje
    │   │   ├── dod-mark-approved.sh    # registra la aprobación de un módulo
    │   │   ├── dod-lib.sh              # funciones compartidas por los dos anteriores
    │   │   └── dod-session-cleanup.sh
    │   └── CLAUDE.md.global.example
    ├── sgc-laravel/
    │   ├── .claude-plugin/plugin.json  # dependencies: ["sgc-core"]
    │   ├── skills/                     # laravel-* + multi-tenant + laravel-definition-of-done
    │   ├── agents/                     # dod-reviewer.md, dod-reviewer-lite.md
    │   ├── dod/
    │   │   ├── module.json             # nombre del módulo + cómo detectar Laravel
    │   │   └── prefilter.sh            # puntos LAR-* vivos / descartados
    │   ├── hooks/
    │   │   ├── hooks.json              # SessionStart → registra el módulo
    │   │   └── register-dod-module.js  # idéntico en todos los plugins de stack
    │   └── CLAUDE.md.laravel-project.example
    └── sgc-nestjs/                     # misma forma que sgc-laravel
```

## Instalación

**En la app de Claude** (plugins sincronizados desde este repositorio):
en Personalizar → Plugins, dentro del marketplace `sgc-mx-marketplace`,
instala `sgc-core` y además el plugin de cada stack que uses (`sgc-laravel`,
`sgc-nestjs`). Tienen que ser los dos, porque la app no instala dependencias
por su cuenta. Cada push a `main` se sincroniza solo, y **Actualizar** trae la
versión nueva.

**En Claude Code por línea de comandos:**

```
/plugin marketplace add daviddeveloper001/sgc-mx-marketplace
/plugin install sgc-laravel@sgc-mx     # repo Laravel  (trae sgc-core vía dependencies)
/plugin install sgc-nestjs@sgc-mx      # repo NestJS   (trae sgc-core vía dependencies)
/plugin install sgc-core@sgc-mx        # cualquier otro stack: solo reglas agnósticas
```

Aquí `dependencies` sí instala `sgc-core` automáticamente, si tu versión de
Claude Code lo soporta. Si no, instálalo a mano igual que en la app. Para
actualizar después de un push: `/plugin marketplace update`.

En un monorepo con Laravel y Nest, instala los dos plugins de stack. Si los
habilitas para todos tus repos, no pasa nada: cada módulo de stack solo se
activa en los repos donde detecta su framework (ver "Cómo funciona el
cierre").

### Migración desde `sgc-mx-toolkit`

`sgc-mx-toolkit` ya no existe en el marketplace. La versión 1.0.0 fue un
bundle vacío que dependía de los tres plugins nuevos, pensado para que
`/plugin marketplace update` migrara solo. En la app de Claude eso no
funciona, porque la app no resuelve `dependencies`: el bundle aparecía
instalado pero sin contenido. Para migrar:

1. Instala `sgc-core` y el plugin de tu stack (ver "Instalación").
2. Desinstala `sgc-mx-toolkit`.
3. Abre una sesión nueva para que se registren los hooks y los revisores.

Los subagentes cambian de nombre: `sgc-mx-toolkit:dod-reviewer` pasa a ser
`sgc-laravel:dod-reviewer` (y existen `sgc-core:dod-reviewer` y
`sgc-nestjs:dod-reviewer`). Si algún `CLAUDE.md` de proyecto nombra al
anterior, actualízalo.

## Cómo decide Claude qué skill usar

Claude no elige "un plugin" para una tarea. Lee la `description` de **todas**
las skills habilitadas, vengan del plugin que vengan, y activa las que
coinciden con lo que se está haciendo. Al refactorizar un controlador Nest que
compara un estado con `'activo'`, se disparan a la vez `nestjs-dtos` (de
`sgc-nestjs`), `core-clean-architecture` y `core-zero-magic-values` (de
`sgc-core`). Dividir en plugins no cambia ese mecanismo: cambia qué skills
existen en cada repo.

## Cómo funciona el cierre (Definition of Done)

El checklist tiene dos capas, con IDs por módulo:

- **CORE-1…CORE-11** (`sgc-core`): agnósticos, siempre vivos, en cualquier stack.
- **LAR-1…LAR-16** (`sgc-laravel`) y **NEST-1…NEST-6** (`sgc-nestjs`): se suman
  cuando el diff toca el stack de ese módulo.

El flujo:

1. **SessionStart.** Cada plugin de stack corre `register-dod-module.js`. Busca
   su manifiesto (`composer.json` con `laravel/framework`, `package.json` con
   `@nestjs/core`): hacia arriba hasta la raíz del repo y hacia abajo hasta 3
   niveles, ignorando `node_modules`, `vendor`, etc. Si lo encuentra, escribe
   `~/.claude/dod-state/sessions/<session_id>/modules/<modulo>.mod` con la ruta
   a su pre-filtro y las carpetas del repo donde vive ese stack (`root=.`,
   `root=backend`, `root=apps/api`…). Si no lo encuentra, no registra nada.
2. **Stop.** `dod-stop-gate.sh` (único hook Stop, en `sgc-core`) calcula el
   hash del diff. Si no hay cambios, o ya está aprobado, deja cerrar.
3. Para cada módulo registrado en la sesión, filtra los archivos del diff a sus
   carpetas y corre su `dod/prefilter.sh`. El pre-filtro dice si aplica, qué
   revisor usar y qué puntos quedan vivos o descartados (con su razón).
4. El gate bloquea con un mensaje que lista, por módulo activo, el subagente
   exacto (`sgc-laravel:dod-reviewer`, `…-lite`, `sgc-nestjs:dod-reviewer`),
   sus puntos y la línea de aprobación. Si ningún módulo aplica (repo sin
   plugin de stack, o un diff que solo toca JS, SQL o docs), lo revisa
   `sgc-core:dod-reviewer` con los CORE-*.
5. Cada revisor que aprueba ejecuta
   `bash ".../dod-mark-approved.sh" <modulo> "<raiz-del-proyecto>"`. El cierre
   se libera cuando **todos** los módulos activos aprobaron el mismo diff: en
   un monorepo, un diff que toca Laravel y Nest pide las dos aprobaciones.
6. Válvula de seguridad: máximo 2 bloqueos por diff. Al tercero deja pasar con
   una advertencia, para nunca generar un loop infinito.

### Equivalencia con el checklist anterior de 24 puntos

| Antes | Ahora | Antes | Ahora | Antes | Ahora |
|---|---|---|---|---|---|
| 1 | CORE-1 + LAR-1 | 9 | CORE-4 | 17 | LAR-10 |
| 2 | LAR-2 | 10 | CORE-5 | 18 | LAR-11 |
| 3 | LAR-3 | 11 | CORE-6 | 19 | LAR-12 |
| 4 | LAR-4 | 12 | CORE-7 | 20 | LAR-13 |
| 5 | LAR-5 | 13 | CORE-8 | 21 | LAR-14 |
| 6 | CORE-2 | 14 | LAR-7 | 22 | LAR-15 |
| 7 | LAR-6 | 15 | LAR-8 | 23 | LAR-16 |
| 8 | CORE-3 | 16 | LAR-9 | 24 | CORE-9 |

El antiguo punto 1 se dividió en dos: el principio agnóstico (CORE-1, que
ahora también aplica a Nest) y la convención concreta de Laravel (LAR-1: ≤15
líneas, Form Request, `App\Services`). Los antiguos puntos 2 y 7 figuraban
como "agnósticos", pero sus reglas son de Eloquent y de PHP 8.4, así que
pasaron a Laravel (LAR-2, LAR-6). Siguen siempre vivos cuando el diff toca PHP.

## Contrato de un módulo de stack (ej. agregar Python)

Un stack nuevo es un plugin nuevo; `sgc-core` no se toca.

1. `plugins/sgc-<stack>/.claude-plugin/plugin.json` con
   `"dependencies": ["sgc-core"]`, más su entrada en `marketplace.json`.
2. `skills/<stack>-*/SKILL.md` con las convenciones, y
   `skills/<stack>-definition-of-done/SKILL.md` con sus puntos `<PREFIJO>-N`.
3. `agents/dod-reviewer.md`: copia el de `sgc-nestjs` y cambia la lista de
   puntos, las skills precargadas (siempre con nombre completo
   `plugin:skill`) y el módulo de la línea de aprobación.
4. `hooks/register-dod-module.js`: **cópialo tal cual** de `sgc-laravel`.
5. `hooks/hooks.json`: el mismo `SessionStart` que `sgc-laravel`.
6. `dod/module.json`:
   ```json
   { "name": "python", "prefilter": "dod/prefilter.sh",
     "detect": { "manifests": ["pyproject.toml", "requirements.txt"], "contains": "django" } }
   ```
7. `dod/prefilter.sh`. El gate le pasa por entorno:
   - `DOD_FILES`: archivo con las rutas del diff dentro de las carpetas del
     módulo, una por línea, relativas a la raíz del repo, incluidos los
     archivos no trackeados.
   - `DOD_DIFF`: archivo con el diff de esas carpetas, más el contenido de
     los archivos no trackeados como líneas `+`.
   - `DOD_NUM_FILES`, `DOD_NUM_LINES`: tamaño del diff del módulo.
     `DOD_TOTAL_FILES`, `DOD_TOTAL_LINES`: tamaño del diff completo.
     `DOD_PROJECT_DIR`: raíz del repo.

   Y debe imprimir por stdout:
   ```
   ACTIVE=true|false               # false = el diff no toca este stack
   REVIEWER=sgc-python:dod-reviewer
   REVIEWER_NOTE=<una línea, opcional>
   LIVE=PY-1 PY-3                  # puntos del módulo a evaluar a fondo
   NA=PY-2|<razón>                 # una línea por punto descartado
   ```
   Si el pre-filtro falla (exit ≠ 0), el gate no se cae: exige la revisión
   completa del módulo y lo avisa en el mensaje.

## Requisitos

`git`, `bash` y `node` en el PATH que usa Claude Code (en Windows: Git Bash).
Los hooks no usan `jq` ni `find`, y están escritos para bash 3.2 (macOS).

## Probado antes de entregarlo

En repos git desechables (Linux, bash 5), con los hooks tal como los llama
Claude Code (JSON por stdin, exit 2 + stderr para bloquear):

- **Laravel.** Sin cambios deja cerrar. Un `catch` en un archivo nuevo sin
  `git add` activa LAR-4 y pide revisión completa. Un diff chico sin rutas
  sensibles pide `dod-reviewer-lite` con LAR-2 y LAR-6 vivos. Un diff que solo
  toca JS lo revisa el core.
- **Aprobación.** Registrada desde una subcarpeta con la ruta explícita, se
  respeta. Un cambio posterior vuelve a bloquear. La válvula deja pasar al
  tercer intento. `dod-mark-approved.sh` sin módulo, o con un nombre
  inválido, falla con un mensaje de uso.
- **NestJS.** En un repo Nest, `sgc-laravel` no se registra aunque esté
  habilitado. Un service con `interface` inline, imports y `any` deja vivos
  NEST-1, 3, 4, 5 y 6. Un `util.ts` sin imports deja vivo solo NEST-1.
- **Monorepo** (`backend/` Laravel, `apps/api` Nest, `frontend/` Vue con
  TypeScript, un `package.json` de Nest dentro de `node_modules`). Registra
  `root=backend` y `root=apps/api`, e ignora `node_modules`. Un cambio solo en
  `frontend/*.ts` no activa Nest. Un diff que toca los dos stacks exige dos
  aprobaciones: con una sola, sigue bloqueado y marca la otra como "YA
  APROBADO". Una sesión abierta en `apps/api/src` también registra
  `root=apps/api`.
- **Robustez.** Si el pre-filtro de un módulo desaparece a mitad de sesión, el
  gate avisa y cae al revisor core. Si falla, exige la revisión completa del
  módulo.

## Limitaciones conocidas

- El hash del diff sigue siendo `git diff HEAD` + `git status --porcelain`: el
  **contenido** de un archivo nuevo sin `git add` no entra al hash (su nombre
  sí). El pre-filtrado ahora sí ve esos archivos y su contenido.
- Un módulo se registra al inicio de la sesión. Si instalas o habilitas un
  plugin de stack a mitad de sesión (`/reload-plugins`), su módulo no existe
  hasta la próxima sesión, y mientras tanto el cierre lo revisa el core.
- Los pre-filtros usan convenciones de nombres: rutas estándar de Laravel
  (`Http/Controllers/`, `database/migrations/`…) y sufijos del CLI de Nest
  (`*.service.ts`, `*.dto.ts`…). Con otra estructura, algunos puntos podrían
  quedar mal clasificados como N/A: ajusta los patrones de la sección
  "Categorías" de cada `dod/prefilter.sh`.
- Los umbrales de "diff pequeño" para `dod-reviewer-lite` (`LINE_THRESHOLD`,
  `FILE_THRESHOLD` en `sgc-laravel/dod/prefilter.sh`) son un punto de partida
  arbitrario, no un dato medido.
- Las skills precargadas en los revisores usan nombre completo
  (`sgc-core:core-zero-magic-values`). Si Claude Code no encuentra una, la
  omite y solo lo registra en el log de depuración. Por eso cada revisor
  repite en su cuerpo la lista de puntos que evalúa.
- `multi-tenant-architecture` vive en `sgc-laravel` porque su contenido usa la
  API de tenancy de Laravel. Si un proyecto Nest también es multi-tenant,
  conviene moverla a `sgc-core` con ejemplos neutrales.

## Pendiente

- NestJS: variante `dod-reviewer-lite` y equivalentes de Filter, Service y
  excepciones de dominio (hoy solo hay repositorios).
- Un hook `PostToolUse` liviano (heurísticas grep, Larastan, ESLint) para
  atrapar lo mecánico sin gastar una pasada de revisor en cada guardado.
