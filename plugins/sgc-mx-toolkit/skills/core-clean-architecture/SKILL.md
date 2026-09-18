---
name: core-clean-architecture
description: Usar siempre que se cree o modifique un controlador, endpoint, handler o punto de entrada HTTP/RPC en cualquier stack (Laravel, NestJS u otro). Valida que ese punto de entrada sea delgado y que la lógica de negocio viva en una capa de servicio separada.
---

# Aislamiento de lógica (agnóstico de stack)

Principio universal, independiente del framework: el punto de entrada de una request (controlador, handler, resolver, comando de consola) NO es el lugar para lógica de negocio, transformación de datos compleja ni persistencia directa.

## Reglas
- El punto de entrada solo debe: recibir la solicitud, validar su forma (no sus reglas de negocio), invocar la capa de servicio, y devolver la respuesta.
- Toda lógica de negocio, orquestación de varios pasos, o reglas de dominio debe vivir en una clase de servicio (o equivalente: use case, application service).
- Un punto de entrada que hace queries directas, cálculos de negocio o `if/else` de reglas de dominio es una señal de que falta una capa de servicio.

## Cómo aplicar esto por stack
Este skill define el principio. La convención concreta de implementación (nombres de carpeta, límites de líneas, herramientas de validación de forma) vive en el skill específico del stack:
- Laravel → ver `laravel-thin-controllers` (Form Requests, `App\Services\...`, límite de 15 líneas).
- NestJS → (pendiente de escribir: DTOs + `class-validator` en el controller, lógica en un `*.service.ts` inyectado).

## Checklist rápido antes de cerrar la tarea
- ¿El controlador/handler tocado tiene más de una responsabilidad además de recibir y despachar?
- ¿Hay una clase de servicio que un test unitario podría probar sin levantar el framework HTTP?
- ¿Se podría mover este controlador a otro protocolo (CLI, cola, gRPC) reutilizando el servicio sin duplicar lógica?
