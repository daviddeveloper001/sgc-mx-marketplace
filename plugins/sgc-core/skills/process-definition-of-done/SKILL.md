---
name: process-definition-of-done
description: Usar antes de responder "listo" o entregar cualquier resultado de código (bug, feature, refactor) en cualquier stack. Checklist de cierre obligatorio contra el diff real — puntos CORE-* agnósticos, más los puntos del módulo de stack que aplique (LAR-*, NEST-*...).
---

# Checklist de cierre (Definition of Done)

Ninguna implementación se declara terminada solo porque el código corre. Antes de responder "listo", el diff real (`git diff HEAD` + archivos nuevos) se revisa punto por punto. Si una regla no aplica a esta tarea, se dice explícitamente ("N/A: no hay puntos de entrada en este cambio"); nunca se omite en silencio.

## Cómo se compone el checklist

El checklist ya no es una lista única. Tiene dos capas:

- **Puntos CORE-\*** (esta skill, plugin `sgc-core`): agnósticos de stack. Siempre vivos, en cualquier proyecto, y se evalúan sobre todo el diff.
- **Puntos de módulo**: cada plugin de stack aporta los suyos y su propio revisor. `sgc-laravel` aporta `LAR-*` (skill `laravel-definition-of-done`) y `sgc-nestjs` aporta `NEST-*` (skill `nestjs-definition-of-done`). Un stack nuevo (ej. Python) sería otro plugin con su propio prefijo.

El hook `dod-stop-gate.sh` de `sgc-core` arma la combinación en cada intento de cierre. Mira qué módulos registró esta sesión y qué archivos tocó el diff, y responde con:

- qué subagente revisor invocar (`sgc-laravel:dod-reviewer`, `sgc-laravel:dod-reviewer-lite`, `sgc-nestjs:dod-reviewer`, o `sgc-core:dod-reviewer` si ningún módulo aplica);
- qué puntos del módulo quedan vivos;
- qué puntos se descartaron mecánicamente (con su razón): se citan N/A tal cual, sin re-investigarlos;
- la línea exacta con la que el revisor registra su aprobación.

**Prefiere siempre invocar al subagente que indica el gate.** Tiene el checklist específico precargado y da un veredicto PASS/FAIL auditable por punto. Si un diff toca dos stacks (monorepo), el gate lista un revisor por módulo y el cierre se libera cuando todos aprueban el mismo diff.

## Puntos CORE

1. **CORE-1 · Puntos de entrada delgados.** ¿El controlador/handler/resolver/comando tocado solo recibe, valida la forma, delega a un servicio y responde, sin lógica de negocio ni queries? (`core-clean-architecture`)
2. **CORE-2 · Magic strings/numbers.** ¿Todo literal de estado/rol/tipo/configuración usa Enum o constante? Aplica también a valores por defecto en parámetros (ej. `request()->input('per_page', 15)`, `limit = 20`), límites, timeouts y cualquier literal operativo, no solo a comparaciones dentro de un `if`. (`core-zero-magic-values`)
3. **CORE-3 · Impacto.** ¿Se buscó en todo el proyecto dónde más se usa cada estructura modificada? (`core-impact-analysis`)
4. **CORE-4 · Configuración dinámica.** ¿Ningún valor operativo quedó quemado en código ni en archivos de config? (`core-config-zero-deploy`)
5. **CORE-5 · Patrones de diseño.** ¿Se evitó acumular `if/else`/`switch` para variantes que van a crecer? (`core-design-patterns-ocp`)
6. **CORE-6 · N+1 y performance.** ¿SQL revisado, eager loading donde corresponde, columnas e índices? (`core-query-optimization`)
7. **CORE-7 · Edge cases.** ¿Errores externos, respuestas vacías/nulas, datos parciales, bordes? (`core-edge-case-analysis`)
8. **CORE-8 · Explicación al usuario.** ¿La respuesta indica qué pasaba antes vs. ahora, la causa raíz con archivo:línea, el recorrido de archivos/funciones y el trade-off de la decisión tomada?
9. **CORE-9 · Tamaño de funciones y clases.** ¿Ninguna función/método tocado supera 4 `return`, y ninguna clase tocada supera 20 métodos? (`core-function-class-size`)
10. **CORE-10 · Tests con mocks.** ¿Cada función/método/clase con lógica tocada tiene su test (se buscó si existía; si no, se creó; si existía y el cambio lo afecta, se ajustó sin debilitarlo ni saltarlo), se ejecutaron, y ninguno abre conexión a base de datos (real ni en memoria), usando dobles y datos mock? N/A si el diff no toca lógica (solo docs, config, estilos). (`core-test-mock-data`)
11. **CORE-11 · Índices en migraciones.** ¿Toda migración que crea o altera una tabla declara los índices que necesita (FK, filtros, orden, joins, unicidad de negocio, `tenant_id`) o justifica por qué ninguno? N/A si el diff no toca migraciones. (`core-migration-indexes`)

Si al repasar se detecta un incumplimiento, se corrige antes de responder. No se reporta como pendiente, salvo que el usuario haya limitado explícitamente el alcance de la tarea.

## Registro de la aprobación

La aprobación se registra por módulo. El mensaje de bloqueo del gate trae, para cada módulo pendiente, la línea exacta:

```
bash "/ruta/absoluta/.../dod-mark-approved.sh" <modulo> "<raiz-del-proyecto>"
```

Se usa esa línea literal: no se adivina ni se reconstruye, porque la ruta cambia según dónde esté instalado el plugin. La ejecuta el revisor cuando su veredicto es APROBADO.

Si no hay subagente disponible y repasas el checklist a mano (CORE + los puntos del módulo que liste el gate), sin incumplimientos pendientes o ya corregidos, ejecuta tú mismo la línea de cada módulo pendiente. Si hay incumplimientos sin corregir (por ejemplo, porque el usuario limitó el alcance), NO la ejecutes: deja que el hook vuelva a bloquear.
