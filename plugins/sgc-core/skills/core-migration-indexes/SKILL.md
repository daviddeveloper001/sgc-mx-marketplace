---
name: core-migration-indexes
description: Usar siempre que se cree o modifique una migración que crea o altera una tabla de base de datos, en cualquier stack y ORM (Laravel, TypeORM, Prisma, Knex, SQL plano) — exige evaluar y declarar explícitamente los índices que la tabla necesita (llaves foráneas, filtros, orden, joins, unicidad de negocio, multi-tenant) o dejar dicho por qué no hace falta ninguno.
---

# Índices en migraciones (agnóstico de stack)

Una tabla sin índices funciona en desarrollo y se degrada en producción cuando crece. Los índices se deciden **en la migración que crea la tabla**, no después de que aparezca la lentitud.

## Reglas

- **Toda migración que crea una tabla declara sus índices** según cómo se va a consultar. No se entrega una tabla con solo la llave primaria por omisión: se evalúa explícitamente y el resultado queda en el código (los índices) o en la explicación (por qué ninguno).
- **Llaves foráneas**: cada columna FK tiene índice. Algunos motores/ORM lo crean solos (MySQL/InnoDB, `constrained()` de Laravel); otros no (PostgreSQL, SQL Server, TypeORM, Prisma, SQL plano). Si el stack no lo crea, se declara a mano.
- **Columnas de consulta**: toda columna usada en `WHERE`, `ORDER BY`, `JOIN` o `GROUP BY` de los listados y reportes previsibles lleva índice (ver `core-query-optimization`). Se piensa en las consultas del feature que se implementa: filtros del listado, búsquedas por código o estado, orden por fecha.
- **Unicidad de negocio**: lo que no debe repetirse (email, código, par `tenant_id + slug`) se garantiza con un índice `unique`, no solo con validación en la aplicación. Con borrado lógico, la unicidad debe contemplar `deleted_at` (índice único parcial o compuesto) para no bloquear la recreación de un registro borrado.
- **Multi-tenant**: si la tabla tiene `tenant_id` (o equivalente) y las consultas filtran por él, ese campo encabeza los índices compuestos.
- **Índices compuestos**: el orden de columnas importa. Primero las de igualdad, después la de rango u ordenamiento (`status, created_at`). Un compuesto `(a, b)` ya cubre las consultas por `a`: no se agrega además un índice simple sobre `a`.
- **No sobre-indexar**: cada índice encarece `INSERT`/`UPDATE` y ocupa espacio. No se indexa sola una columna booleana o de muy baja cardinalidad, ni columnas que nunca se filtran, ni se duplican índices que otro ya cubre.
- **Tablas existentes**: al agregar una columna a una tabla ya creada se evalúa igual si necesita índice. En tablas grandes se advierte el costo o bloqueo de crearlo, y se usa creación concurrente/online si el motor la soporta.
- **Reversible**: el `down` elimina lo que el `up` creó, índices incluidos. Los índices llevan nombre explícito cuando el autogenerado excede el límite del motor o se referencia desde otro lado.

## Cómo aplicarlo por stack

- **Laravel**: `->index()`, `->unique()`, `$table->index(['tenant_id', 'status'])`, `$table->unique(['tenant_id', 'slug'])`. `foreignId()->constrained()` ya indexa la FK. Las demás convenciones de migración (`onDelete`, `softDeletes`, orden de `timestamps`) viven en `laravel-migrations`.
- **TypeORM**: `@Index()` / `@Index(['tenantId', 'status'])` en la entidad y `CREATE INDEX` en la migración; en PostgreSQL las FK no se indexan solas.
- **Prisma**: `@@index([tenantId, status])` y `@@unique([tenantId, slug])` en `schema.prisma`; en PostgreSQL las relaciones no generan índice automático.
- **SQL plano / Knex / otros**: `CREATE INDEX` / `CREATE UNIQUE INDEX` en la misma migración que el `CREATE TABLE`.

## Señales de que se está violando esta regla

- Una migración `create table` con columnas de filtro evidentes (`status`, `tenant_id`, `code`, `*_id`, fechas de corte) y ningún índice.
- Una FK sin índice en un motor que no la indexa por su cuenta.
- Un campo "único" (email, código) validado solo en el Form Request/DTO, sin `unique` en la tabla.
- Un índice compuesto con el orden invertido respecto a cómo se consulta, o un índice simple redundante con un compuesto que ya lo cubre.
- Un índice sobre una columna booleana sola, "por si acaso".
- Una migración cuyo `down` no elimina los índices que creó el `up`.

## Checklist rápido
- ¿Cada tabla creada declara los índices de sus llaves foráneas, filtros, orden y joins previsibles?
- ¿La unicidad de negocio está garantizada con `unique` en la tabla (considerando `deleted_at` y `tenant_id`)?
- ¿Los índices compuestos tienen el orden igualdad → rango/orden y no duplican otro índice?
- ¿Se evitó indexar columnas de baja cardinalidad o que nadie consulta?
- ¿El `down` revierte los índices y, en una tabla grande, se advirtió el costo de crearlos?
- ¿En la explicación al usuario quedó por qué se eligió cada índice, o por qué no hace falta ninguno?
