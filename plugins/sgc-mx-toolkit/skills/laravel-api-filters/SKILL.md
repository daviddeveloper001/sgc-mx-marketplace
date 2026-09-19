---
name: laravel-api-filters
description: Usar siempre que se cree o modifique un endpoint de listado en la API con filtros u orden por query string — exige una clase QueryFilter concreta con $sortable como allowlist. No aplica a listados de un flujo web normal.
---

# Filtrado y orden de listados de API (QueryFilter)

Convención exclusiva del flujo de API. Un listado de una ruta web normal (una vista Blade paginada, por ejemplo) no necesita este patrón.

## Reglas

- Todo endpoint de listado (`index()`) que acepte filtros u orden por query string tipa un Filter concreto directamente en la firma del método (ej. `index(AuditLogFilter $filters)`) — Laravel lo resuelve automáticamente inyectando la Request actual al constructor del Filter, sin pasarla a mano.
- El Filter concreto extiende la clase abstracta `App\Filters\QueryFilter`, que ya resuelve el despacho dinámico (`apply()`: por cada parámetro de la query string, si existe un método con ese mismo nombre en la subclase, lo invoca) y el orden (`sort()`).
- Cada filtro disponible es un método público con el mismo nombre que el parámetro de query string que representa (`?action=foo` → método `action(string $value)`).
- El orden (`?sort=name,-created_at`) está protegido por la propiedad `$sortable`: un array que declara explícitamente qué columnas se pueden ordenar. Puede ser una lista simple (`'action'`) o mapear un alias camelCase público a la columna real (`'createdAt' => 'created_at'`). Ordenar por una columna que no está en `$sortable` se ignora silenciosamente, nunca se ejecuta.
- El Filter se conecta al modelo vía un scope local (`AuditLog::filter($filters)`, respaldado por `scopeFilter(Builder $query, QueryFilter $filters)` en el modelo, que internamente llama `$filters->apply($query)`), coherente con `laravel-eloquent-encapsulation` (las queries complejas viven en el modelo).

## Ejemplo de referencia

```php
abstract class QueryFilter
{
    protected Builder $builder;
    protected Request $request;
    protected array $sortable = [];

    public function __construct(Request $request)
    {
        $this->request = $request;
    }

    public function apply(Builder $builder): Builder
    {
        $this->builder = $builder;

        foreach ($this->request->all() as $key => $value) {
            if (method_exists($this, $key)) {
                $this->$key($value);
            }
        }

        return $builder;
    }

    protected function sort(string $value): void
    {
        $sortAttributes = explode(',', $value);

        foreach ($sortAttributes as $sortAttribute) {
            $direction = 'asc';

            if (strpos($sortAttribute, '-') === 0) {
                $direction = 'desc';
                $sortAttribute = substr($sortAttribute, 1);
            }

            if (!in_array($sortAttribute, $this->sortable) && !array_key_exists($sortAttribute, $this->sortable)) {
                continue;
            }

            $columnName = $this->sortable[$sortAttribute] ?? $sortAttribute;

            $this->builder->orderBy($columnName, $direction);
        }
    }
}

class AuditLogFilter extends QueryFilter
{
    protected array $sortable = [
        'action',
        'createdAt' => 'created_at',
        'updatedAt' => 'updated_at',
    ];

    public function action(string $value): void
    {
        $this->builder->where('action', 'LIKE', "%$value%");
    }

    public function createdAt(string $value): void
    {
        $dates = explode(',', $value);

        if (count($dates) > 1) {
            $this->builder->whereBetween('created_at', $dates);
        } else {
            $this->builder->whereDate('created_at', $value);
        }
    }
}
```

## Señales de que se está violando esta regla

- Un `index()` que arma filtros con `if ($request->has('action')) { $query->where(...); }` directo en el controlador o servicio, en vez de un Filter.
- Una subclase de `QueryFilter` sin `$sortable` definido (o vacío cuando sí acepta `?sort=`) — permite ordenar por cualquier columna, incluidas las que no deberían exponerse.
- Un método de filtro que no corresponde a ningún parámetro documentado del endpoint (dificulta saber qué filtros existen sin leer el código completo).

## Checklist rápido
- ¿El `index()` tipa el Filter concreto directo en la firma?
- ¿El Filter extiende `QueryFilter` y cada filtro es un método público nombrado igual que el parámetro?
- ¿`$sortable` está definido y protege el orden contra columnas no permitidas?
- ¿El Filter se aplica vía un scope del modelo, no con queries armadas en el controlador/servicio?
