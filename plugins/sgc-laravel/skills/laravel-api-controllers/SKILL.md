---
name: laravel-api-controllers
description: Usar siempre que se cree o modifique un controlador dentro del flujo de API (namespace Http\Controllers\Api\...) — exige extender ApiControllerV1, usar el trait ApiResponses para las respuestas, y delegar el manejo de excepciones a handleException(). No aplica a controladores de rutas web.
---

# Controlador base de API (ApiControllerV1)

Convención exclusiva del flujo de API. Un controlador de una ruta web normal (que no extiende `ApiControllerV1`) no se evalúa contra este skill.

## Reglas

- Todo controlador de API extiende `App\Http\Controllers\Api\V1\ApiControllerV1` (o el equivalente de la versión correspondiente), nunca directamente `Controller`.
- Toda respuesta exitosa se construye con el trait `ApiResponses` (`$this->ok($message, $data)` para 200, `$this->success($message, $data, $statusCode)` para otros códigos 2xx), nunca `response()->json(...)` armado a mano dentro del controlador.
- Cada acción del controlador envuelve la llamada al Service en un `try { ... } catch (\Throwable $e) { return $this->handleException($e); }` — nunca un `catch` que loguea y responde manualmente dentro de la acción.
- `handleException()` (heredado de `ApiControllerV1`) es el único lugar donde se registra el error, y lo hace con `saveErrorLog` (trait `App\Traits\Error`, ver `laravel-error-logging`) — nunca `Log::error(...)` directo, ni siquiera dentro de este método centralizado.
- Envelope de respuesta fijo:
  - Éxito (`ok`/`success`): `{ data, message, status }`.
  - Error con excepción de dominio (`ApiRenderableExceptionV1`): `{ message, error_code }` — `message` es siempre el mensaje seguro para el usuario (`getUserMessage()`), nunca el detalle técnico.
  - Error no controlado: `{ message }` genérico con `500`, el detalle real solo queda en el log vía `saveErrorLog`.

## Ejemplo de referencia

```php
class ApiControllerV1 extends Controller
{
    use ApiResponses, Error;

    protected function handleException(Throwable $e)
    {
        if ($e instanceof ApiRenderableExceptionV1) {
            $this->saveErrorLog(get_class($e), $e, [
                'developer_hint' => $e->getDeveloperHint(),
            ]);

            return response()->json([
                'message' => $e->getUserMessage(),
                'error_code' => $e->getStatusCode(),
            ], $e->getStatusCode());
        }

        $this->saveErrorLog('UnhandledException', $e);

        return response()->json([
            'message' => 'An unexpected error occurred',
        ], 500);
    }
}

class AuditLogControllerV1 extends ApiControllerV1
{
    public function __construct(private AuditLogServiceV1 $auditLogService) {}

    public function index(AuditLogFilter $filters)
    {
        try {
            $perPage = request()->input('per_page', 10);
            $auditLogs = $this->auditLogService->getAllAuditLogs($filters, $perPage);

            return $this->ok('AuditLogs retrieved successfully', AuditLogResourceV1::collection($auditLogs));
        } catch (\Throwable $e) {
            return $this->handleException($e);
        }
    }
}
```

## Señales de que se está violando esta regla

- Un controlador de `Http\Controllers\Api\...` que extiende `Controller` directamente, no `ApiControllerV1`.
- `response()->json(...)` construido a mano dentro de una acción, en vez de `$this->ok(...)`/`$this->success(...)`.
- Un `catch` dentro de una acción que hace algo distinto a `return $this->handleException($e);` (loguear aparte, responder manualmente, catch silencioso).
- `Log::error(...)` dentro de `handleException()` en vez de `saveErrorLog`.

## Checklist rápido
- ¿El controlador extiende `ApiControllerV1`?
- ¿Toda respuesta usa `ApiResponses` (`ok`/`success`), nunca `response()->json` a mano?
- ¿Cada acción envuelve la llamada al Service en try/catch delegando a `handleException()`?
- ¿`handleException()` usa `saveErrorLog`, no `Log::error`?
