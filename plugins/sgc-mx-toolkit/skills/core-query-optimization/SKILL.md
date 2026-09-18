---
name: core-query-optimization
description: Usar siempre que se escriba, modifique o revise una consulta a base de datos (ORM o SQL crudo), especialmente dentro de loops, listados, reportes o relaciones anidadas, en cualquier stack.
---

# Optimización de consultas (Zero N+1)

Ninguna consulta se agrega "porque funciona": su costo debe justificarse antes de escribirla.

## Reglas
- Prohibido iterar una colección de registros accediendo a una relación no precargada dentro del ciclo (`foreach`, `map`, o su render en la vista/template). Se debe precargar (eager loading) toda relación que se vaya a consumir.
- Evitar `SELECT *` cuando solo se necesita un subconjunto de columnas.
- Usar paginación o procesamiento en streaming (`paginate`, `cursor`, `chunk` o equivalente) en listados que puedan crecer, en vez de traer todo el conjunto a memoria.
- Si una consulta filtra, ordena o hace `join` por una columna, esa columna debe tener índice — si no lo tiene, se debe proponer/agregar en la migración correspondiente.
- Ante consultas dentro de bucles, relaciones anidadas o reportes, revisar (o dejar evidencia de haber considerado) el SQL resultante para confirmar que no hay consultas redundantes por registro.

## Cómo aplicar esto por stack
La sintaxis exacta de eager loading (`with`, `load`, `loadCount` en Eloquent) vive en `laravel-eloquent-encapsulation`. Este skill cubre el principio, aplicable igual en TypeORM/Prisma/Drizzle u otro ORM.

## Checklist rápido
- ¿Hay algún acceso a relación dentro de un loop sin precarga?
- ¿El listado puede crecer sin límite? ¿Está paginado?
- ¿Las columnas usadas en `WHERE`/`ORDER BY`/`JOIN` tienen índice?
