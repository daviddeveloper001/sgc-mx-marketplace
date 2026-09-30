---
name: laravel-definition-of-done
description: Usar antes de dar por terminada una tarea que modificó código PHP de un proyecto Laravel. Puntos LAR-1…LAR-16 del checklist de cierre (controladores, queries, i18n, errores, Blade, sintaxis moderna, multi-tenant, Form Requests y ecosistema de API, migraciones, modelos), que se suman a los CORE-* de process-definition-of-done.
---

# Checklist de cierre — módulo Laravel (LAR-*)

Complementa a `process-definition-of-done` (plugin `sgc-core`): los puntos CORE-* aplican siempre, y estos se suman cuando el diff toca PHP dentro de las carpetas Laravel del repo. El revisor que los verifica es `sgc-laravel:dod-reviewer` (o `sgc-laravel:dod-reviewer-lite` para diffs pequeños sin rutas sensibles). El gate `dod-stop-gate.sh` indica cuál usar y qué puntos ya vienen descartados mecánicamente según los archivos tocados.

1. **LAR-1 · Controladores delgados (Laravel).** ¿Métodos de ≤15 líneas, sin lógica de negocio ni queries, con validación vía Form Request y delegación a `App\Services`? (`laravel-thin-controllers`)
2. **LAR-2 · Queries.** ¿Toda consulta compleja vive en el modelo (scope o método), no en el controlador ni en el servicio? (`laravel-eloquent-encapsulation`)
3. **LAR-3 · Textos.** ¿Cada string visible pasa por `__()`/`@lang()` y tiene su entrada en `lang/*/...php`? (`laravel-i18n`)
4. **LAR-4 · Errores.** ¿Los `catch` usan `App\Traits\Error::saveErrorLog`? (`laravel-error-logging`)
5. **LAR-5 · Blade.** ¿Sin `<script>`/`<style>` inline ni lógica compleja? (`laravel-blade-views`)
6. **LAR-6 · PHP/Laravel moderno.** ¿Tipado estricto, sintaxis PHP 8.4 / Laravel 12, y toda dependencia inyectada por constructor, nunca instanciada con `new` dentro de un método? (`laravel-modern-syntax`)
7. **LAR-7 · Multi-tenant.** Si el cambio toca más de un tenant: ¿se encola por tenant, es idempotente, y el test cubre más de uno? (`multi-tenant-architecture`)
8. **LAR-8 · Form Requests.** ¿Toda validación de entrada usa un Form Request dedicado con `messages()` personalizado, nunca inline ni con mensajes por defecto? (`laravel-form-requests`)
9. **LAR-9 · Resources de API.** ¿Toda respuesta de API se formatea con una clase Resource (`type`/`id`/`attributes`/`includes`/`links`), nunca el modelo ni un array armado a mano? (`laravel-api-resources`)
10. **LAR-10 · Controlador base de API.** ¿Extiende `ApiControllerV1`, usa `ApiResponses` para responder, y delega errores a `handleException()` (con `saveErrorLog`, no `Log::error`)? (`laravel-api-controllers`)
11. **LAR-11 · Filters de API.** ¿El listado usa un `QueryFilter` concreto tipado en la firma, con `$sortable` como allowlist de orden? (`laravel-api-filters`)
12. **LAR-12 · Repositories.** ¿El CRUD puntual de un registro pasa por un Repository que extiende `BaseRepositoryV1`, no por queries directas en el Service? (`laravel-api-repositories`)
13. **LAR-13 · Services de API.** ¿El Service orquesta Repository (CRUD puntual) y scope de modelo (listados filtrados), y traduce toda excepción atrapada a una excepción de dominio? (`laravel-api-services`)
14. **LAR-14 · Excepciones de dominio API.** ¿Implementa `ApiRenderableExceptionV1` y se construye siempre con argumentos nombrados? (`laravel-api-exceptions`)
15. **LAR-15 · Migraciones.** ¿Foreign keys con `onDelete()` explícito y justificado, índices y soft deletes evaluados, y `created_at`/`updated_at` como últimas columnas (cualquier campo nuevo se declara antes de ellas, nunca después)? (`laravel-migrations`)
16. **LAR-16 · Modelos Eloquent.** ¿`$fillable` explícito, `$casts` completo, y `SoftDeletes` sincronizado con la migración? (`laravel-eloquent-models`)

## Equivalencia con la numeración anterior (checklist único de 24 puntos)

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
