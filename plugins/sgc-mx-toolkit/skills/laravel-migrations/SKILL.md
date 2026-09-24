---
name: laravel-migrations
description: Usar siempre que se cree o modifique una migración de Laravel — exige índices donde corresponda, evaluar explícitamente la necesidad de soft deletes, foreign keys con onDelete() explícito (cascade/set null/restrict) justificado según el caso de negocio, y created_at/updated_at siempre como últimas columnas.
---

# Estructura de migraciones (Laravel)

## Reglas

- **Foreign keys**: toda relación se declara con la sintaxis moderna `$table->foreignId('<entidad>_id')->constrained()->onDelete('<accion>')` (o `foreignIdFor(Model::class)` cuando el nombre de columna no sigue la convención por defecto) — nunca `unsignedBigInteger` + `foreign()` por separado, salvo que la relación no siga la convención estándar de Laravel.
- **`onDelete()` siempre explícito, nunca implícito**: toda foreign key declara su acción de borrado — `cascade`, `set null`, o `restrict` — evaluando el caso de negocio real, no dejando el default del motor.
  - `cascade`: cuando el registro hijo no tiene sentido sin el padre (ej. `products` de una `category` eliminada).
  - `set null` (+ columna `nullable()`): cuando el registro hijo debe sobrevivir a la eliminación del padre, quedando "sin asignar" (ej. un `order` cuyo `assigned_user_id` se pone en null si el usuario se elimina).
  - `restrict` (o ausencia de acción): cuando eliminar el padre mientras tenga hijos debe fallar explícitamente, nunca en silencio.
  - La justificación de por qué se eligió una u otra va en la explicación al usuario (punto 13 del checklist — causa raíz/trade-off de la decisión), no solo en el código.
- **Índices**: se evalúa explícitamente (no por omisión) si cada columna nueva usada en `WHERE`, `ORDER BY`, `JOIN` o unicidad de negocio necesita `->index()` o `->unique()`. Las columnas de foreign key ya quedan indexadas automáticamente por `constrained()`, no hace falta duplicarlo.
- **Soft deletes**: se evalúa explícitamente si la tabla necesita borrado lógico (`$table->softDeletes()`) — típicamente cuando el registro puede tener referencias históricas que no deben desaparecer (ej. una `Category` referenciada en reportes o `products` ya vendidos), y no aplica cuando el registro es efímero o no tiene relaciones dependientes relevantes. Si se agrega `softDeletes()` en la migración, el Modelo correspondiente **debe** usar el trait `SoftDeletes` (ver `laravel-eloquent-models`) — y viceversa: un Modelo con `SoftDeletes` exige la columna en la migración.
- **Orden de columnas: `created_at`/`updated_at` siempre al final**: `$table->timestamps()` (o las columnas `created_at`/`updated_at` declaradas a mano) va siempre como lo último del bloque de columnas de la tabla — nunca en medio ni al principio. Si se agrega una columna nueva a una tabla ya existente, esa columna se declara **antes** de `timestamps()`, nunca después. Esto es una convención de orden de columnas, no de sintaxis de Laravel — aplica igual sin importar el stack o el motor de migraciones.

## Ejemplo de referencia

```php
Schema::create('products', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->text('description')->nullable();
    $table->foreignId('category_id')->constrained()->onDelete('cascade');
    $table->foreignId('assigned_user_id')->nullable()->constrained('users')->onDelete('set null');
    $table->unique(['category_id', 'name']);
    $table->softDeletes();
    $table->timestamps(); // siempre al final — cualquier columna nueva va antes de esta línea
});
```

## Señales de que se está violando esta regla

- `$table->foreignId('category_id')->constrained();` sin `->onDelete(...)` — queda en el default del motor (usualmente `RESTRICT`), sin que sea una decisión explícita ni documentada.
- Una foreign key con `onDelete('set null')` sobre una columna que no es `nullable()` — falla en el primer borrado del padre.
- Una tabla que en la práctica necesita borrado lógico (referenciada por otras tablas con reportes/históricos) sin `softDeletes()`, o un Modelo con `SoftDeletes` cuya migración no tiene la columna `deleted_at`.
- Una columna usada en filtros frecuentes (`WHERE status = ...`, `WHERE tenant_id = ...`) sin índice.
- Una migración que agrega una columna nueva a una tabla existente **después** de `$table->timestamps()`, dejando los campos de auditoría en medio de la tabla en vez de al final.

## Checklist rápido
- ¿Toda foreign key usa `foreignId()->constrained()` (o `foreignIdFor()`) con `onDelete()` explícito?
- ¿La elección de `cascade`/`set null`/`restrict` está justificada según el caso de negocio, y si es `set null` la columna es `nullable()`?
- ¿Se evaluaron índices en columnas de filtro/orden/unicidad de negocio?
- ¿Se evaluó explícitamente si la tabla necesita `softDeletes()`, y coincide con lo que declara el Modelo?
- ¿`created_at`/`updated_at` (`timestamps()`) quedan como las últimas columnas declaradas, y cualquier columna nueva se agregó antes de ellas, nunca después?
