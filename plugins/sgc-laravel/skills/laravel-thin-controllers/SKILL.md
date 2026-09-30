---
name: laravel-thin-controllers
description: Usar siempre que se cree o modifique un controlador de Laravel. Define el límite de líneas, el uso obligatorio de Form Requests, y la delegación a App\Services.
---

# Controladores delgados (Laravel)

Convención concreta de Laravel para el principio general descrito en `core-clean-architecture`.

## Reglas
- Los controladores actúan únicamente como receptores de solicitudes: validación inicial de HTTP (vía Form Requests), e invocación del flujo.
- Prohibido colocar lógica de negocio, manipulación de datos compleja o persistencia directamente en el controlador. Debe delegarse a una clase de servicio en `App\Services\...`.
- Cada acción/método del controlador no debe superar las 15 líneas de código.
- Toda validación de entrada va en un Form Request dedicado, no inline en el método del controlador con `$request->validate()`.

## Checklist rápido
- ¿El método del controlador supera 15 líneas?
- ¿Hay validación inline (`$request->validate(...)`) en vez de un Form Request?
- ¿Hay una query, un cálculo de negocio, o un `if` de reglas de dominio directamente en el controlador?
