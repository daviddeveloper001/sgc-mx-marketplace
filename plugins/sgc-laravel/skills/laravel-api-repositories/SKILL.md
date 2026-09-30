---
name: laravel-api-repositories
description: Usar siempre que se cree o modifique un Repository, o que un Service de API necesite acceso a datos de un solo registro (CRUD puntual) — exige extender BaseRepositoryV1 en vez de queries directas. No aplica a listados filtrados (ver laravel-api-filters) ni a servicios/repositorios de un flujo web normal, que solo siguen laravel-eloquent-encapsulation.
---

# Repositorio de acceso a datos puntual (BaseRepositoryV1)

Convención de la capa de datos para CRUD de un solo registro dentro de servicios de API. Para listados con filtros/orden, ver `laravel-api-filters` — el Repository no cubre ese caso (su contrato no incluye filtrado ni paginación).

## Reglas

- El acceso a datos de un solo registro (buscar, crear, actualizar, eliminar) desde un Service de API pasa por una clase Repository, nunca por queries Eloquent directas en el Service.
- El Repository concreto extiende `App\Repositories\V1\BaseRepositoryV1` e implementa `BaseRepositoryInterfaceV1` (heredado), tipando el modelo correspondiente en su propio constructor:

  ```php
  class AuditLogRepositoryV1 extends BaseRepositoryV1
  {
      const RELATIONS = [];

      public function __construct(AuditLog $auditLog)
      {
          parent::__construct($auditLog, self::RELATIONS);
      }
  }
  ```

- Las relaciones a eager-cargar por defecto se declaran como constante de clase `RELATIONS` (no como propiedad de instancia ni hardcodeadas dentro de cada método), y se pasan al constructor del padre.
- El Repository **no** es el lugar para filtrado dinámico ni paginación de listados — su contrato (`BaseRepositoryInterfaceV1`) solo define `all()`, `find()`, `findBy()`, `create()`, `update()`, `delete()`. Un listado con filtros/orden va directo al modelo vía scope (ver `laravel-api-filters`), sin pasar por el Repository.

## Ejemplo de referencia

```php
interface BaseRepositoryInterfaceV1
{
    public function all();
    public function find(Model $model);
    public function findBy(int $id);
    public function create(array $data);
    public function update(Model $model, array $data);
    public function delete(Model $model);
}

class BaseRepositoryV1 implements BaseRepositoryInterfaceV1
{
    protected $model;
    protected $relations = [];

    public function __construct(Model $model, array $relations = [])
    {
        $this->model = $model;
        $this->relations = $relations;
    }

    public function create(array $data)
    {
        return $this->model->create($data);
    }

    public function update(Model $model, array $data)
    {
        $model->fill($data);
        $model->save();
        return $model;
    }

    public function delete(Model $model)
    {
        return $model->delete();
    }
}
```

## Señales de que se está violando esta regla

- Un Service de API con `Model::where(...)->first()` o `Model::find($id)` directo, en vez de invocar su Repository.
- Un Repository concreto que no extiende `BaseRepositoryV1`, o que reimplementa `create`/`update`/`delete` en vez de heredarlos.
- Relaciones eager-cargadas hardcodeadas dentro de un método del Repository en vez de la constante `RELATIONS` pasada al constructor del padre.
- Un Repository al que se le agregó un método de filtrado/paginación — esa responsabilidad no le corresponde (ver `laravel-api-filters`).

## Checklist rápido
- ¿El acceso a un solo registro desde el Service pasa por un Repository, no por queries directas?
- ¿El Repository concreto extiende `BaseRepositoryV1` y tipa el modelo en su propio constructor?
- ¿Las relaciones por defecto están en una constante `RELATIONS`, no hardcodeadas?
- ¿El Repository se mantiene fuera de la lógica de filtrado/paginación de listados?
