---
name: process-definition-of-done
description: Usar antes de responder "listo" o entregar cualquier resultado de código (bug, feature, refactor) en este workspace. Checklist de cierre obligatorio contra el diff real.
---

# Checklist de cierre (Definition of Done)

Ninguna implementación se declara terminada solo porque el código corre. Antes de responder "listo", repasa explícitamente — uno por uno — estos puntos contra el `git diff` real de los archivos tocados. Si una regla no aplica a esta tarea, dilo explícitamente ("N/A: no hay controladores en este cambio"); no la omitas en silencio.

1. **Controladores** — ¿delgados, sin lógica de negocio ni queries? (`core-clean-architecture`, `laravel-thin-controllers`)
2. **Queries** — ¿toda consulta compleja vive en el modelo, no en controlador/servicio? (`laravel-eloquent-encapsulation`)
3. **Textos** — ¿cada string visible pasa por `__()`/`@lang()` con su entrada en `lang/*/...php`? (`laravel-i18n`)
4. **Errores** — ¿los `catch` usan `App\Traits\Error::saveErrorLog`? (`laravel-error-logging`)
5. **Blade** — ¿sin `<script>`/`<style>` inline ni lógica compleja? (`laravel-blade-views`)
6. **Magic strings/numbers** — ¿todo literal de estado/rol/tipo usa Enum o constante? (`core-zero-magic-values`)
7. **PHP/Laravel moderno** — ¿tipado estricto y sintaxis PHP 8.4/Laravel 12? (`laravel-modern-syntax`)
8. **Impacto** — ¿se buscó en todo el proyecto dónde más se usa cada estructura modificada? (`core-impact-analysis`)
9. **Configuración dinámica** — ¿ningún valor operativo quedó quemado en código/`config`? (`core-config-zero-deploy`)
10. **Patrones de diseño** — ¿se evitó acumular `if/else`/`switch` para variantes que van a crecer? (`core-design-patterns-ocp`)
11. **N+1 y performance** — ¿SQL revisado, eager loading donde corresponde? (`core-query-optimization`)
12. **Edge cases** — ¿errores externos, respuestas vacías/nulas, datos parciales, bordes? (`core-edge-case-analysis`)
13. **Explicación al usuario** — ¿la respuesta indica qué pasaba antes vs. ahora, causa raíz con archivo:línea, el recorrido de archivos/funciones, y el trade-off de la decisión tomada?
14. **Multi-tenant** — si el cambio toca más de un tenant: ¿se encola por tenant, es idempotente, y el test cubre más de uno? (`multi-tenant-architecture`)

Si al repasar esta lista se detecta un incumplimiento, corrígelo antes de responder — no lo reportes como pendiente salvo que el usuario haya limitado explícitamente el alcance de la tarea.

> Nota de evolución: este checklist es candidato a convertirse en un subagente de verificación automática (`dod-reviewer`) disparado por un hook al cerrar cada tarea, en vez de depender de que el modelo principal se acuerde de repasarlo. Ese es el siguiente nivel del sistema, no lo resuelve este skill por sí solo.
