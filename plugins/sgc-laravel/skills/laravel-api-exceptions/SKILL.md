---
name: laravel-api-exceptions
description: Usar siempre que se cree o lance una excepción de negocio dentro del flujo de API — exige que implemente ApiRenderableExceptionV1 y se construya siempre con argumentos nombrados. No aplica a excepciones de un flujo web normal.
---

# Excepciones de dominio de API (ApiRenderableExceptionV1)

Convención exclusiva del flujo de API. Una excepción lanzada desde un controlador/servicio/repositorio de una ruta web normal no necesita implementar esta interfaz.

## Reglas

- Toda excepción de negocio que deba llegar como respuesta HTTP formateada implementa `App\Interfaces\V1\ApiRenderableExceptionV1`, con sus tres métodos:
  - `getStatusCode(): int` — el código HTTP a devolver.
  - `getUserMessage(): string` — el mensaje seguro para el cliente.
  - `getDeveloperHint(): ?string` — detalle técnico, solo para logs, nunca expuesto al cliente.
- Al construir la excepción, **siempre con argumentos nombrados**, nunca posicionales — el constructor típico tiene varios parámetros opcionales (`message`, `developerHint`, `code`, `previous`) y un desorden posicional hace que un valor caiga en el parámetro equivocado sin que PHP lo marque como error (coacción de tipos silenciosa).

  ```php
  // Correcto
  throw new AuditLogException('AuditLog not found', code: Response::HTTP_NOT_FOUND);

  // Incorrecto — el segundo argumento cae en $developerHint, no en $code;
  // el código HTTP real queda en el valor por defecto del constructor (400),
  // no en el 404 que se pretendía.
  throw new AuditLogException('AuditLog not found', Response::HTTP_NOT_FOUND);
  ```

- El mensaje de usuario (`getUserMessage()`) debe ser genérico y seguro de mostrar (ej. "Failed to retrieve AuditLogs"), nunca el mensaje técnico real de la excepción original — ese va en `developerHint`.

## Ejemplo de referencia

```php
interface ApiRenderableExceptionV1
{
    public function getStatusCode(): int;
    public function getUserMessage(): string;
    public function getDeveloperHint(): ?string;
}

class AuditLogException extends Exception implements ApiRenderableExceptionV1
{
    private ?string $developerHint;

    public function __construct(
        string $message = 'AuditLog error occurred',
        ?string $developerHint = null,
        int $code = Response::HTTP_BAD_REQUEST,
        ?Exception $previous = null
    ) {
        parent::__construct($message, $code, $previous);
        $this->developerHint = $developerHint;
    }

    public function getStatusCode(): int
    {
        return $this->getCode();
    }

    public function getUserMessage(): string
    {
        return $this->getMessage();
    }

    public function getDeveloperHint(): ?string
    {
        return $this->developerHint;
    }
}
```

## Señales de que se está violando esta regla

- Una excepción lanzada en un Service/Repository de API que no implementa `ApiRenderableExceptionV1` (llegaría a `handleException()` como "no controlada", perdiendo el código HTTP y mensaje específicos).
- Una construcción con 2+ argumentos posicionales cuando el constructor tiene parámetros opcionales de por medio (`new AuditLogException('mensaje', 404)` en vez de `new AuditLogException('mensaje', code: 404)`).
- `getUserMessage()` devolviendo el mensaje técnico real de una excepción interna (SQL, HTTP client, etc.) en vez de un mensaje de negocio genérico.

## Checklist rápido
- ¿La excepción implementa `ApiRenderableExceptionV1`?
- ¿Se construye siempre con argumentos nombrados?
- ¿`getUserMessage()` es un mensaje de negocio seguro, no el detalle técnico?
