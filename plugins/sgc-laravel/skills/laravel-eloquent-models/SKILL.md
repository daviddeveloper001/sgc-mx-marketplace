---
name: laravel-eloquent-models
description: Usar siempre que se cree o modifique un Modelo Eloquent en Laravel — exige $fillable explícito, $casts para todo campo que lo requiera, y el trait SoftDeletes cuando la migración tiene la columna deleted_at.
---

# Estructura de Modelos Eloquent (Laravel)

Complementa a `laravel-eloquent-encapsulation` (que cubre las queries/scopes del modelo): este skill cubre la estructura de atributos del modelo en sí.

## Reglas

- **`$fillable` siempre explícito**: todo modelo declara `protected $fillable = [...]` con los campos que se pueden asignar masivamente (`create()`/`fill()`), nunca `$guarded = []` como atajo genérico salvo justificación explícita.
- **`$casts` para todo campo que lo requiera**: fechas adicionales a `created_at`/`updated_at` (esos ya los castea Eloquent), booleanos, columnas JSON/array, decimales, y enums nativos de PHP deben declararse en `protected $casts = [...]`. Un `$casts` vacío es una señal a verificar contra la migración, no un default aceptable si el modelo tiene alguno de esos tipos de columna.
- **`SoftDeletes`**: si la migración de la tabla tiene `softDeletes()` (columna `deleted_at`), el modelo usa el trait `Illuminate\Database\Eloquent\SoftDeletes` — y viceversa, un modelo con el trait exige la columna en la migración (ver `laravel-migrations`). Ambos archivos deben mantenerse sincronizados.
- **Transformación de datos vía accessors/mutators**: normalización de un atributo al leer/escribir (capitalización, trim, lowercase, formateo) vive en el propio modelo vía `get<Atributo>Attribute()`/`set<Atributo>Attribute()` (o su equivalente `Attribute::make()` de Laravel 12), nunca repetida en el controlador o el servicio cada vez que se usa el campo.

## Ejemplo de referencia

```php
class Category extends Model
{
    use SoftDeletes;

    protected $table = 'categories';

    protected $fillable = [
        'name',
        'description',
    ];

    protected $casts = [];

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function getNameAttribute($value)
    {
        return ucfirst($value);
    }

    public function setNameAttribute($value)
    {
        $this->attributes['name'] = strtolower($value);
    }
}
```

## Señales de que se está violando esta regla

- Un modelo con `$guarded = []` sin justificación (abre mass assignment a cualquier campo, incluidos los que no deberían venir del cliente).
- Una columna `boolean`/`json`/`date` en la migración que no aparece en `$casts` del modelo — el atributo llega como string crudo en vez de tipado.
- Un modelo con `SoftDeletes` cuya migración no tiene `deleted_at`, o una migración con `softDeletes()` cuyo modelo no usa el trait (los borrados no serían lógicos pese a la intención).
- Formateo/normalización de un campo (`ucfirst`, `trim`, `strtolower`) repetido en varios controladores/servicios en vez de vivir en un accessor/mutator del modelo.

## Checklist rápido
- ¿`$fillable` está declarado explícitamente con los campos correctos?
- ¿`$casts` cubre fechas extra, booleanos, JSON/array y enums de la tabla?
- ¿El uso de `SoftDeletes` en el modelo coincide con `softDeletes()` en la migración?
- ¿La transformación de atributos vive en accessors/mutators del modelo, no duplicada fuera?
