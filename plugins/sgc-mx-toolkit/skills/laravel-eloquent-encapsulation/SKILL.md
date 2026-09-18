---
name: laravel-eloquent-encapsulation
description: Usar siempre que se escriba una consulta Eloquent en Laravel, especialmente si es compleja o se repite. Define dónde deben vivir las consultas y la sintaxis de eager loading.
---

# Consultas y persistencia en modelos (Laravel/Eloquent)

## Reglas
- No escribir consultas Eloquent complejas directamente en controladores o servicios de orquestación.
- Las consultas personalizadas o complejas deben vivir en el Modelo correspondiente, mediante:
  - Query Scopes (ej. `scopeActive($query)`)
  - Métodos específicos del modelo (ej. `findByName($name)`)
- El controlador o servicio solo debe invocar esos scopes/métodos del modelo, nunca construir el query directamente.
- Eager loading obligatorio (`with`, `load`, `loadCount`) para toda relación que se vaya a consumir en un loop, vista o serialización — ver también `core-query-optimization` para el principio general de N+1.
- Usar `select()` para evitar `SELECT *` innecesario, y `paginate`/`cursor`/`chunk` en listados que puedan crecer.

## Checklist rápido
- ¿Hay un `Model::where(...)->where(...)` complejo armado directamente en un controlador o servicio, en vez de un scope?
- ¿Toda relación accedida en un loop/vista está precargada con `with`/`load`/`loadCount`?
