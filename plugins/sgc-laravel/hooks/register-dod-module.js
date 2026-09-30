#!/usr/bin/env node
// hooks/register-dod-module.js  (hook SessionStart de un plugin de stack)
//
// Registra este plugin como "módulo" del gate de cierre de sgc-core
// (dod-stop-gate.sh) para la sesión actual. Es el MISMO archivo en todos los
// plugins de stack (sgc-laravel, sgc-nestjs, ...): lo único que cambia entre
// ellos es dod/module.json. Para un stack nuevo, copia este archivo tal cual.
//
// Qué hace:
//   1. Lee dod/module.json del plugin (nombre, pre-filtro, cómo detectar el
//      stack).
//   2. Busca en el proyecto los manifiestos del stack (ej. composer.json con
//      "laravel/framework"): hacia arriba desde el directorio del proyecto
//      hasta la raíz del repo, y hacia abajo hasta 3 niveles (monorepos),
//      ignorando node_modules, vendor, etc.
//   3. Si el proyecto NO usa ese stack, no registra nada: el plugin puede
//      estar habilitado a nivel de usuario sin interferir en otros repos.
//   4. Si lo usa, escribe
//        ~/.claude/dod-state/sessions/<session_id>/modules/<nombre>.mod
//      con name=, prefilter= (ruta absoluta) y una línea root= por cada
//      carpeta del repo donde vive ese stack ("." = raíz del repo).
//
// Nunca bloquea el inicio de sesión ni imprime por stdout (en SessionStart,
// stdout se inyecta como contexto para Claude). Los errores van a stderr.

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const SKIP_DIRS = new Set([
  'node_modules', 'vendor', 'dist', 'build', 'coverage', 'storage',
  'bootstrap', 'public', 'tmp', 'target', 'out',
]);
const MAX_DEPTH_DOWN = 3;

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch (e) {
    return '';
  }
}

function realpath(p) {
  try {
    return fs.realpathSync.native(p);
  } catch (e) {
    return p;
  }
}

function toPosix(p) {
  return p.split(path.sep).join('/');
}

function manifestMatches(file, contains) {
  try {
    return fs.readFileSync(file, 'utf8').includes(contains);
  } catch (e) {
    return false;
  }
}

function dirHasStack(dir, detect) {
  return detect.manifests.some((m) => manifestMatches(path.join(dir, m), detect.contains));
}

// Directorios con el stack, desde `start` hacia abajo (hasta MAX_DEPTH_DOWN).
function findDown(start, detect, depth, found) {
  if (dirHasStack(start, detect)) found.add(start);
  if (depth >= MAX_DEPTH_DOWN) return;
  let entries = [];
  try {
    entries = fs.readdirSync(start, { withFileTypes: true });
  } catch (e) {
    return;
  }
  for (const e of entries) {
    if (!e.isDirectory() || e.name.startsWith('.') || SKIP_DIRS.has(e.name)) continue;
    findDown(path.join(start, e.name), detect, depth + 1, found);
  }
}

function main() {
  const pluginRoot = path.resolve(__dirname, '..');
  const config = JSON.parse(fs.readFileSync(path.join(pluginRoot, 'dod', 'module.json'), 'utf8'));
  const name = String(config.name || '');
  if (!/^[a-z0-9][a-z0-9-]*$/.test(name)) throw new Error(`nombre de módulo inválido: "${name}"`);
  const prefilter = path.join(pluginRoot, config.prefilter || 'dod/prefilter.sh');
  const detect = {
    manifests: [].concat(config.detect && config.detect.manifests ? config.detect.manifests : []),
    contains: String((config.detect && config.detect.contains) || ''),
  };
  if (!detect.manifests.length || !detect.contains) throw new Error('dod/module.json sin "detect.manifests"/"detect.contains"');

  let input = {};
  try {
    input = JSON.parse(readStdin() || '{}');
  } catch (e) {
    input = {};
  }
  const sessionId = String(input.session_id || '');
  if (!sessionId || /[\\/]|\.\./.test(sessionId)) return; // sin sesión válida no hay dónde registrar

  // realpath en ambos lados: en macOS /var → /private/var, y git devuelve la
  // ruta real; sin esto path.relative daría "../.." y no se registraría nada.
  const projectDir = realpath(path.resolve(process.env.CLAUDE_PROJECT_DIR || input.cwd || process.cwd()));

  let toplevel;
  try {
    toplevel = execFileSync('git', ['-C', projectDir, 'rev-parse', '--show-toplevel'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch (e) {
    return; // no es un repo git: el gate tampoco revisa nada
  }
  toplevel = realpath(path.resolve(toplevel));

  const found = new Set();
  // Hacia arriba: el proyecto puede estar abierto en una subcarpeta del stack.
  for (let dir = projectDir; ; dir = path.dirname(dir)) {
    if (dirHasStack(dir, detect)) found.add(dir);
    const rel = path.relative(toplevel, dir);
    if (rel === '' || rel.startsWith('..') || path.dirname(dir) === dir) break;
  }
  // Hacia abajo: monorepos (apps/api, backend/, ...).
  findDown(projectDir, detect, 0, found);

  const roots = [...found]
    .map((dir) => toPosix(path.relative(toplevel, dir)) || '.')
    .filter((rel) => !rel.startsWith('..'))
    .sort();
  if (!roots.length) return; // este proyecto no usa el stack del módulo

  const home = process.env.HOME || os.homedir();
  const modulesDir = path.join(home, '.claude', 'dod-state', 'sessions', sessionId, 'modules');
  fs.mkdirSync(modulesDir, { recursive: true });

  const lines = [`name=${name}`, `prefilter=${toPosix(prefilter)}`, ...roots.map((r) => `root=${r}`)];
  const target = path.join(modulesDir, `${name}.mod`);
  const tmp = `${target}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, lines.join('\n') + '\n');
  fs.renameSync(tmp, target);
}

try {
  main();
} catch (e) {
  process.stderr.write(`[register-dod-module] ${e && e.message ? e.message : e}\n`);
}
process.exit(0);
