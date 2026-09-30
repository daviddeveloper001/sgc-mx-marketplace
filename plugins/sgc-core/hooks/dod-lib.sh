#!/usr/bin/env bash
# hooks/dod-lib.sh
#
# Funciones compartidas por dod-stop-gate.sh y dod-mark-approved.sh (ambos
# viven en sgc-core). Se carga con `. dod-lib.sh`; no se ejecuta sola.
#
# Requiere git y node en PATH (sin jq, a propósito). Escrito para bash 3.2+
# (macOS) y Git Bash (Windows): nada de arrays asociativos ni `find`.

# Estado del gate, SIEMPRE fuera del repo del proyecto: si viviera dentro,
# `git status --porcelain` lo vería como archivo nuevo y el hash del diff
# cambiaría solo en cada corrida del hook.
#   $DOD_HOME/<clave-proyecto>/            aprobaciones e intentos por proyecto
#   $DOD_HOME/sessions/<session_id>/modules/<modulo>.mod
#                                          módulos de stack registrados en esa
#                                          sesión por su hook SessionStart
DOD_HOME="${HOME:-/tmp}/.claude/dod-state"

# sha256 de la cadena vacía: diff sin cambios pendientes.
DOD_EMPTY_HASH="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

# Puntos del checklist que pertenecen a sgc-core. Siempre vivos: se evalúan
# sobre TODO el diff, sin importar el stack. Si agregas un punto CORE, súmalo
# aquí, en skills/process-definition-of-done y en los revisores.
DOD_CORE_POINTS="CORE-1 CORE-2 CORE-3 CORE-4 CORE-5 CORE-6 CORE-7 CORE-8 CORE-9"

# Nombre válido de módulo: minúsculas, dígitos y guiones (se usa en nombres
# de archivo del estado).
dod_valid_module_name() {
  case "$1" in
    ''|*[!a-z0-9-]*|-*) return 1 ;;
    *) return 0 ;;
  esac
}

dod_sha256_stdin() {
  node -e "
    const crypto = require('crypto');
    let d = '';
    process.stdin.on('data', c => d += c);
    process.stdin.on('end', () => process.stdout.write(crypto.createHash('sha256').update(d).digest('hex')));
  "
}

# $1 = directorio del proyecto. Clave corta y estable por proyecto.
dod_project_key() {
  printf '%s' "$1" | dod_sha256_stdin | cut -c1-16
}

# $1 = directorio del proyecto. Hash del trabajo pendiente: mismo criterio
# que las versiones anteriores (git diff HEAD + git status --porcelain).
dod_diff_hash() {
  { git -C "$1" diff HEAD 2>/dev/null; \
    git -C "$1" status --porcelain 2>/dev/null; } | dod_sha256_stdin
}

# Lee un campo de primer nivel del JSON que llega por stdin.
# $1 = nombre del campo. Imprime '' si no existe o el JSON es inválido.
dod_json_field() {
  node -e "
    let d = '';
    process.stdin.on('data', c => d += c);
    process.stdin.on('end', () => {
      try {
        const v = JSON.parse(d)[process.argv[1]];
        process.stdout.write(v === undefined || v === null ? '' : String(v));
      } catch (e) { process.stdout.write(''); }
    });
  " "$1"
}
