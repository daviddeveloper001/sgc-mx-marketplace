---
name: laravel-api-resources
description: Usar siempre que un controlador de Laravel devuelva datos vía API/JSON — toda respuesta debe formatearse con una clase Resource, nunca devolviendo el modelo o un array armado a mano.
---

# Formato de respuesta de API vía Resource (Laravel)

Convención de respuesta de API específica de este proyecto, para que todo endpoint exponga el mismo contrato.

## Reglas

- Ningún controlador devuelve un modelo Eloquent, una colección, o un array armado a mano directamente como respuesta JSON. Toda respuesta de API pasa por una clase que extiende `Illuminate\Http\Resources\Json\JsonResource` (o `JsonResource::collection()` para listados).
- El nombre de la clase sigue la convención `<Entidad>Resource<Versión>` (ej. `CategoryResourceV1`), en línea con el versionado de controladores/servicios del proyecto (`CategoryControllerV1`, `CategoryServiceV1`).
- El método `toArray(Request $request): array` devuelve siempre esta estructura fija:
  - `type`: string plano con el nombre del recurso en plural (ej. `'categories'`).
  - `id`: el identificador del recurso.
  - `attributes`: los campos propios del recurso. Un campo que solo debe exponerse en ciertos contextos (ej. un detalle más pesado solo en el endpoint `show`) usa `$this->when(...)`, nunca un `if` fuera del array de retorno.
  - `includes`: recursos relacionados, cada uno formateado con su propia clase Resource vía `<Entidad>Resource<Versión>::collection($this->whenLoaded('relacion'))` — nunca la relación cruda. Se incluye esta llave cuando el recurso tiene relaciones anidadas relevantes al contrato, aunque en ese momento no vengan cargadas (`whenLoaded` la deja vacía automáticamente); se omite por completo si el recurso no expone relaciones.
  - `links`: acciones disponibles sobre el recurso, mínimo `self` con `route(...)` — nunca una URL armada a mano con concatenación de strings.
- Toda relación expuesta en `includes` debe venir de `whenLoaded(...)`, nunca de acceder a la relación directamente (dispararía una query N+1 — ver también `core-query-optimization`).
- El docblock `@return array<string, mixed>` es obligatorio sobre `toArray()`, en línea con `laravel-modern-syntax` (tipado estricto).

## Ejemplo de referencia

```php
class CategoryResourceV1 extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'type' => 'categories',
            'id' => $this->id,
            'attributes' => [
                'name' => $this->name,
                'description' => $this->when(
                    $request->routeIs('categories.show'),
                    $this->description,
                ),
                'created_at' => $this->created_at,
                'updated_at' => $this->updated_at,
            ],
            'includes' => ProductResourceV1::collection($this->whenLoaded('products')),
            'links' => [
                ['self' => route('categories.show', ['category' => $this->id])],
            ],
        ];
    }
}
```

## Señales de que se está violando esta regla

- Un controlador con `return response()->json($category);` o `return $category;` directo.
- Una clase Resource sin las cuatro llaves (`type`, `id`, `attributes`, `links`), o con campos de negocio sueltos fuera de `attributes`.
- Un campo condicional resuelto con `if ($condicion) { $data['x'] = ...; }` en vez de `$this->when(...)`.
- `includes` construido accediendo a `$this->relacion` en vez de `$this->whenLoaded('relacion')`.
- Un link armado como `'/api/categories/' . $this->id` en vez de `route(...)`.

## Checklist rápido
- ¿La respuesta del controlador pasa por una clase `*Resource*`, individual o `::collection()`?
- ¿`toArray()` devuelve exactamente `type`, `id`, `attributes`, `includes`, `links`?
- ¿Los campos condicionales usan `$this->when(...)`?
- ¿Las relaciones en `includes` vienen de `whenLoaded(...)` y están formateadas con su propia Resource?
- ¿`links.self` usa `route(...)` en vez de una URL armada a mano?
