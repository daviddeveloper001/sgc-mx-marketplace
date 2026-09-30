---
name: laravel-error-logging
description: Usar siempre que se agregue o modifique un bloque catch en un job, controlador, servicio o middleware de Laravel que pueda fallar (llamadas a APIs externas, operaciones críticas).
---

# Manejo de errores y logs (Error Trait)

## Reglas
- Para registrar errores técnicos o de comunicación con APIs externas, usar el trait `App\Traits\Error`.
- Cuando ocurra un error atrapable en un job, controlador, servicio o middleware, invocar `$this->saveErrorLog($type, $error, $data)`.
- Importar y usar `use App\Traits\Error;` en toda clase donde se capturen errores de este tipo.
- No usar `Log::error(...)` suelto ni `catch` silenciosos como sustituto de este mecanismo estándar.

## Checklist rápido
- ¿Cada `catch` en jobs/controladores/servicios/middleware usa `saveErrorLog`?
- ¿La clase tiene el trait `App\Traits\Error` importado y usado?
