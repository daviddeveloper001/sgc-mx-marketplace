#!/usr/bin/env bash
# hooks/dod-session-cleanup.sh  (plugin sgc-core, hook SessionStart)
#
# Borra los registros de módulos de sesiones con más de 14 días
# (~/.claude/dod-state/sessions/<session_id>/). Son archivos de pocas líneas,
# pero se crea uno por sesión y nadie más los limpia.
#
# Nunca bloquea ni imprime nada por stdout: en SessionStart, stdout se
# inyecta como contexto para Claude.

set -uo pipefail

SESSIONS_DIR="${HOME:-/tmp}/.claude/dod-state/sessions"
[ -d "$SESSIONS_DIR" ] || exit 0

node -e "
  const fs = require('fs');
  const path = require('path');
  const dir = process.argv[1];
  const maxAgeMs = 14 * 24 * 60 * 60 * 1000;
  const now = Date.now();
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const full = path.join(dir, entry.name);
    try {
      if (now - fs.statSync(full).mtimeMs > maxAgeMs) {
        fs.rmSync(full, { recursive: true, force: true });
      }
    } catch (e) { /* otra sesión pudo borrarlo primero */ }
  }
" "$SESSIONS_DIR" >/dev/null 2>&1 || true

exit 0
