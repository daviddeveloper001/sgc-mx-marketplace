# sgc-mx — marketplace personal de Claude Code

Este repo es una **marketplace de Claude Code** con un solo plugin,
`sgc-mx-toolkit`: los 24 skills de estándares SGC-MX (core + Laravel +
multi-tenant), el subagente `dod-reviewer`, y el hook que bloquea el cierre
de una tarea hasta que el diff pasa el Definition of Done.

Es la evolución de dos entregas anteriores (`sgc-mx-skills.zip`, entregado
como carpetas sueltas para copiar a mano): ahora es instalable con un
comando, igual en cualquier máquina, y actualizable con otro comando — sin
copiar carpetas ni tocar `claude_desktop_config.json` como proponía el
servidor MCP original.

```
sgc-mx-marketplace/
├── .claude-plugin/
│   └── marketplace.json          # catálogo: qué plugins ofrece este repo
└── plugins/
    └── sgc-mx-toolkit/
        ├── .claude-plugin/
        │   └── plugin.json       # metadata del plugin
        ├── skills/                # los 24 skills (ver detalle abajo)
        ├── agents/
        │   └── dod-reviewer.md
        ├── hooks/
        │   ├── hooks.json         # declara el hook Stop
        │   ├── dod-stop-gate.sh
        │   └── dod-mark-approved.sh
        ├── CLAUDE.md.global.example
        └── CLAUDE.md.laravel-project.example
```

## Instalación

**Opción A — probarlo ya, desde esta carpeta descomprimida (sin git):**

```
/plugin marketplace add /ruta/donde/descomprimiste/sgc-mx-marketplace
/plugin install sgc-mx-toolkit@sgc-mx
```

**Opción B — para tenerlo sincronizado en todas tus máquinas:** subí esta
carpeta tal cual a un repo git tuyo (GitHub o GitLab, privado), y en cada
máquina:

```
/plugin marketplace add <tu-usuario>/sgc-mx-marketplace
/plugin install sgc-mx-toolkit@sgc-mx
```

Cuando cambies algo en el vault (agregar un skill, ajustar una regla),
hacés commit + push una vez, y en cada máquina corrés:

```
/plugin marketplace update
```

Con eso se actualizan skills, agente y hooks a la vez — ya no hay que copiar
carpetas a mano ni recompilar nada (a diferencia del servidor MCP en
TypeScript de la propuesta original).

## Qué trae el plugin

- **24 skills** organizados en `core-*` (agnósticos de stack), `laravel-*`
  (convenciones de Laravel/PHP), `multi-tenant-architecture` (específico de
  que este SaaS es multi-tenant) y `process-definition-of-done` (el
  checklist de cierre). Se disparan solos según la `description` de cada
  uno — no hace falta mencionarlos.
- **`dod-reviewer`**: subagente de solo lectura que verifica el diff real
  contra los 23 puntos del checklist, citando `archivo:línea`, antes de dar
  una tarea por terminada.
- **Hook `Stop`**: bloquea el cierre de la tarea hasta que `dod-reviewer`
  registre una aprobación para el diff vigente (máximo 2 intentos de
  bloqueo por diff — al tercero deja pasar con una advertencia, para nunca
  generar un loop infinito).
- **Dos `CLAUDE.md` de ejemplo**: uno global corto (regla de explicación y
  trazabilidad, que debe aplicar siempre) y uno de proyecto Laravel
  (referencia a que el plugin ya trae las convenciones).

## Requisitos

`git`, `bash` y `node` en el PATH que usa Claude Code (en Windows: Git Bash,
que ya tenés instalado). Los hooks no usan `jq` a propósito.

## Probado antes de entregarlo

El hook se probó de punta a punta en un repo git descartable simulando: sin
cambios, cambio nuevo bloqueado dos veces, válvula de seguridad al tercer
intento, aprobación, y un cambio nuevo reiniciando el contador — tanto en la
ubicación de plugin (`hooks/` dentro del plugin instalado) como en la
instalación manual anterior (`.claude/hooks/` de un proyecto). En el camino
se encontraron y corrigieron dos bugs reales antes de esta entrega:

1. El directorio de estado del hook vivía dentro del repo del proyecto, así
   que `git status` lo veía como archivo nuevo y el hash del diff cambiaba
   solo en cada corrida (nunca dejaba de bloquear). Se movió fuera del repo,
   a `~/.claude/dod-state/<hash-del-proyecto>/`.
2. La ruta al script de aprobación (`dod-mark-approved.sh`) estaba fija a
   `.claude/hooks/...`, lo cual se rompe en cuanto el toolkit se instala
   como plugin (vive en otra carpeta). Ahora el propio hook resuelve la
   ruta relativa a sí mismo y se la da a `dod-reviewer` en el mensaje de
   bloqueo, para que nunca tenga que adivinarla.

## Limitaciones honestas

- El hash del diff se arma con `git diff HEAD` + `git status --porcelain`.
  Un archivo nuevo aún no trackeado (`git add`) no entra al hash por su
  contenido hasta que lo agregues al índice — recomendación: `git add -A`
  antes de pedir el cierre de la tarea.
- Requiere que el proyecto sea un repo git; si no lo es, el hook se
  desactiva solo (no bloquea nada).
- La skill `multi-tenant-architecture` asume el patrón de tenancy descrito
  en la regla 14 original; si tu paquete de tenancy usa otra API, ajustá
  esa skill puntual.

## Pendiente (no incluido en esta entrega)

- `skills/nestjs-*` — convenciones de NestJS (falta que las definas, igual
  que hiciste con Laravel).
- Un hook `PostToolUse` liviano (heurísticas grep o Larastan/PHP-CS-Fixer)
  para atrapar lo mecánico sin gastar una pasada completa de `dod-reviewer`
  en cada guardado.
- Publicar el repo en tu cuenta de git para que `/plugin marketplace add`
  funcione igual desde cualquier máquina sin depender de una carpeta local.
# SGC-MX-Standards-workflow-and-automation
