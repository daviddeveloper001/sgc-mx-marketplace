---
name: laravel-api-services
description: Usar siempre que se cree o modifique un Service dentro del flujo de API — exige orquestar Repository (CRUD puntual) y scope de modelo (listados filtrados), y traducir cualquier excepción capturada a una excepción de dominio con argumentos nombrados. No aplica a servicios de un flujo web normal, que no dependen de ApiRenderableExceptionV1.
---

# Service de orquestación de API

Convención exclusiva del flujo de API para la capa que conecta el controlador con Repository/modelo. Un servicio de una ruta web normal sigue las reglas generales (`core-clean-architecture`) pero no depende de `ApiRenderableExceptionV1`.

## Reglas

- El Service inyecta su Repository correspondiente vía constructor property promotion (ver `laravel-modern-syntax`).
- CRUD de un solo registro (buscar/crear/actualizar/eliminar) se delega al Repository (ver `laravel-api-repositories`). Listados con filtros/orden van directo al modelo vía scope (`Model::filter($filters)->paginate($perPage)`, ver `laravel-api-filters`) — el Service no arma queries a mano en ninguno de los dos casos.
- Cada método público envuelve la llamada al Repository/modelo en un `try/catch`, y cualquier excepción atrapada se retraduce a una excepción de dominio que implemente `ApiRenderableExceptionV1` (ver `laravel-api-exceptions`), siempre con argumentos nombrados, pasando el mensaje técnico real como `developerHint` y un mensaje de negocio genérico como mensaje de usuario.
- Un caso de negocio esperado (ej. "no encontrado") se lanza explícitamente con su propio código HTTP correcto (`404`), separado del `catch` genérico que traduce fallos inesperados a `500`.

## Ejemplo de referencia

```php
class AuditLogServiceV1
{
    public function __construct(private AuditLogRepositoryV1 $auditLogRepository) {}

    public function getAllAuditLogs($filters, $perPage)
    {
        try {
            return AuditLog::filter($filters)->paginate($perPage);
        } catch (\Exception $e) {
            throw new AuditLogException(
                'Failed to retrieve AuditLogs',
                developerHint: $e->getMessage(),
                code: Response::HTTP_INTERNAL_SERVER_ERROR,
                previous: $e
            );
        }
    }

    public function getAuditLogById(AuditLog $auditLog)
    {
        try {
            $result = $this->auditLogRepository->find($auditLog);

            if (!$result) {
                throw new AuditLogException('AuditLog not found', code: Response::HTTP_NOT_FOUND);
            }

            return $result;
        } catch (\Exception $e) {
            throw new AuditLogException(
                'Failed to retrieve AuditLog',
                developerHint: $e->getMessage(),
                code: Response::HTTP_INTERNAL_SERVER_ERROR,
                previous: $e
            );
        }
    }
}
```

## Señales de que se está violando esta regla

- Un `catch` en el Service que relanza la excepción original (`throw $e;`) o una `\Exception` genérica, en vez de traducirla a una excepción de dominio.
- Una excepción de dominio construida con argumentos posicionales (ver `laravel-api-exceptions`).
- Un caso "no encontrado" que cae en el mismo `catch` genérico de 500 en vez de lanzarse explícitamente con 404.
- Queries Eloquent directas dentro del Service para CRUD de un solo registro, en vez de invocar el Repository.

## Checklist rápido
- ¿El Repository se inyecta vía constructor property promotion?
- ¿El CRUD puntual pasa por el Repository y los listados filtrados por el scope del modelo?
- ¿Toda excepción atrapada se retraduce a una excepción de dominio con argumentos nombrados?
- ¿Los casos esperados (ej. "no encontrado") tienen su propio código HTTP explícito, separados del catch genérico de 500?
