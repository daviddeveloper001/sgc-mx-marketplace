---
name: process-definition-of-done
description: Usar antes de responder "listo" o entregar cualquier resultado de código (bug, feature, refactor) en este workspace. Checklist de cierre obligatorio contra el diff real.
---

# Checklist de cierre (Definition of Done)

Ninguna implementación se declara terminada solo porque el código corre. Antes de responder "listo", repasa explícitamente — uno por uno — estos puntos contra el `git diff` real de los archivos tocados. Si una regla no aplica a esta tarea, dilo explícitamente ("N/A: no hay controladores en este cambio"); no la omitas en silencio.

Si el proyecto es Laravel y tiene disponible el subagente `dod-reviewer` (o
su variante `dod-reviewer-lite` para diffs pequeños sin rutas sensibles),
prefiere invocarlo a él — el hook `dod-stop-gate.sh` ya calcula qué puntos
son mecánicamente N/A según los archivos tocados, así que ninguno de los dos
necesita "investigar hasta lo obviamente inaplicable": un punto sin sus
archivos disparadores en el diff se marca N/A directo, con la razón que da
el propio hook. El escepticismo ("nunca un PASS optimista") se reserva para
los puntos que sí están vivos, no para demostrar de más que algo no aplica.
Usa esta skill genérica cuando el stack no tiene todavía su propio subagente
de revisión (por ejemplo, NestJS por ahora) — el mismo criterio de "un punto
sin archivos que lo disparen es N/A directo" aplica igual repasando la lista
a mano.

1. **Controladores** — ¿delgados, sin lógica de negocio ni queries? (`core-clean-architecture`, `laravel-thin-controllers`)
2. **Queries** — ¿toda consulta compleja vive en el modelo, no en controlador/servicio? (`laravel-eloquent-encapsulation`)
3. **Textos** — ¿cada string visible pasa por `__()`/`@lang()` con su entrada en `lang/*/...php`? (`laravel-i18n`)
4. **Errores** — ¿los `catch` usan `App\Traits\Error::saveErrorLog`? (`laravel-error-logging`)
5. **Blade** — ¿sin `<script>`/`<style>` inline ni lógica compleja? (`laravel-blade-views`)
6. **Magic strings/numbers** — ¿todo literal de estado/rol/tipo usa Enum o constante? (`core-zero-magic-values`)
7. **PHP/Laravel moderno** — ¿tipado estricto, sintaxis PHP 8.4/Laravel 12, y toda dependencia inyectada por constructor (nunca instanciada con `new` dentro de un método)? (`laravel-modern-syntax`)
8. **Impacto** — ¿se buscó en todo el proyecto dónde más se usa cada estructura modificada? (`core-impact-analysis`)
9. **Configuración dinámica** — ¿ningún valor operativo quedó quemado en código/`config`? (`core-config-zero-deploy`)
10. **Patrones de diseño** — ¿se evitó acumular `if/else`/`switch` para variantes que van a crecer? (`core-design-patterns-ocp`)
11. **N+1 y performance** — ¿SQL revisado, eager loading donde corresponde? (`core-query-optimization`)
12. **Edge cases** — ¿errores externos, respuestas vacías/nulas, datos parciales, bordes? (`core-edge-case-analysis`)
13. **Explicación al usuario** — ¿la respuesta indica qué pasaba antes vs. ahora, causa raíz con archivo:línea, el recorrido de archivos/funciones, y el trade-off de la decisión tomada?
14. **Multi-tenant** — si el cambio toca más de un tenant: ¿se encola por tenant, es idempotente, y el test cubre más de uno? (`multi-tenant-architecture`)
15. **Form Requests** — ¿toda validación de entrada usa un Form Request dedicado con `messages()` personalizado (nunca inline ni mensajes por defecto)? (`laravel-form-requests`)
16. **Resources de API** — ¿toda respuesta de API se formatea con una clase Resource (`type`/`id`/`attributes`/`includes`/`links`), nunca el modelo o un array armado a mano? (`laravel-api-resources`)
17. **Controlador base de API** — ¿el controlador extiende `ApiControllerV1`, usa `ApiResponses` para responder, y delega errores a `handleException()` (con `saveErrorLog`, no `Log::error`)? (`laravel-api-controllers`)
18. **Filters de API** — ¿el listado usa un `QueryFilter` concreto tipado en la firma, con `$sortable` como allowlist de orden? (`laravel-api-filters`)
19. **Repositories** — ¿el CRUD puntual de un registro pasa por un Repository que extiende `BaseRepositoryV1`, no por queries directas en el Service? (`laravel-api-repositories`)
20. **Services de API** — ¿el Service orquesta Repository (CRUD puntual) y scope de modelo (listados filtrados), y traduce toda excepción atrapada a una excepción de dominio? (`laravel-api-services`)
21. **Excepciones de dominio API** — ¿la excepción implementa `ApiRenderableExceptionV1` y se construye siempre con argumentos nombrados? (`laravel-api-exceptions`)
22. **Migraciones** — ¿foreign keys con `onDelete()` explícito y justificado, índices evaluados, soft deletes evaluado, y `created_at`/`updated_at` como últimas columnas (cualquier campo nuevo declarado antes de ellas, nunca después)? (`laravel-migrations`)
23. **Modelos Eloquent** — ¿`$fillable` explícito, `$casts` completo, y `SoftDeletes` sincronizado con la migración? (`laravel-eloquent-models`)
24. **Tamaño de funciones y clases** — ¿ninguna función/método tocado supera 4 `return`, y ninguna clase tocada supera 20 métodos? (`core-function-class-size`)

Si al repasar esta lista se detecta un incumplimiento, corrígelo antes de responder — no lo reportes como pendiente salvo que el usuario haya limitado explícitamente el alcance de la tarea.

## Registro de la aprobación

Si vas a dar la tarea por cerrada y ya repasaste esta lista completa sin incumplimientos pendientes (o corregiste los que encontraste), ejecuta con Bash el script `dod-mark-approved.sh`. La ruta exacta a ese script viene siempre en el mensaje de bloqueo que generó `dod-stop-gate.sh` (línea `bash "/ruta/absoluta/.../dod-mark-approved.sh"`) — usa esa ruta literal, no la adivines ni la reconstruyas, porque cambia según si el toolkit está instalado como plugin o copiado a mano en `.claude/hooks/`.

Esto registra el hash del diff actual como revisado, para que el hook `dod-stop-gate.sh` deje cerrar la tarea sin depender de su válvula de escape por intentos agotados. Si detectaste incumplimientos y no los corregiste (por ejemplo, porque el usuario limitó el alcance), NO ejecutes ese script — deja que el hook vuelva a bloquear.

Este paso aplica sin importar el stack: es el mismo mecanismo que usa el subagente `dod-reviewer` para Laravel. Si el proyecto es Laravel y `dod-reviewer` está disponible, prefiere invocarlo a él en vez de esta skill — tiene un checklist más específico y un veredicto PASS/FAIL explícito por punto. Usa esta skill genérica cuando el stack no tiene todavía su propio subagente de revisión (por ejemplo, NestJS por ahora).

> Nota de evolución: este checklist es candidato a convertirse en un subagente de verificación automática por stack (equivalente a `dod-reviewer`/`dod-reviewer-lite` pero para NestJS u otros), en vez de depender de que el modelo principal se acuerde de repasarlo. Ese es el siguiente nivel del sistema, no lo resuelve este skill por sí solo.
