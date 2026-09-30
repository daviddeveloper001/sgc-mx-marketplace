---
name: laravel-form-requests
description: Usar siempre que se valide entrada de un controlador en Laravel, o se cree/edite una clase Form Request — exige Form Request dedicado (nunca validación inline) y mensajes personalizados en messages().
---

# Form Requests con mensajes personalizados (Laravel)

Convención concreta de Laravel para la validación de entrada, complementaria a `laravel-thin-controllers` (que prohíbe la validación inline en el controlador).

## Reglas

- Toda validación de entrada de un endpoint debe vivir en una clase Form Request dedicada (`php artisan make:request ...`), nunca con `$request->validate(...)` inline en el controlador ni un Form Request genérico reutilizado entre endpoints distintos con reglas que en realidad difieren.
- Todo Form Request debe sobreescribir el método `messages()` con mensajes personalizados para cada regla relevante — no se deja `messages()` sin definir ni se confía en los mensajes por defecto de Laravel/`lang/en/validation.php`.
- Los mensajes definidos en `messages()` son textos visibles al usuario: deben pasar por `__()`/`@lang()` igual que cualquier otro string de UI (ver `laravel-i18n`), no quedar quemados en español/inglés directo.
- Si un Form Request realmente no necesita mensajes personalizados porque ninguna de sus reglas es ambigua con el mensaje por defecto, esa decisión debe quedar explícita: el método `messages()` sigue presente (aunque devuelva solo lo mínimo necesario), nunca ausente por omisión.

## Señales de que se está violando esta regla

- Una clase que extiende `FormRequest` sin método `messages()` en absoluto.
- `$request->validate([...])` directamente en un método de controlador.
- Un Form Request compartido entre `store()` y `update()` con reglas que en realidad difieren (ej. `unique` que debería ignorar el registro actual en `update`).
- `messages()` presente pero con los mismos textos genéricos de Laravel, sin aportar contexto de negocio, o con texto quemado en vez de `__()`/`@lang()`.

## Checklist rápido
- ¿Existe una clase Form Request dedicada para este endpoint, en vez de validación inline?
- ¿`messages()` está definido con mensajes personalizados para las reglas de esta clase?
- ¿Esos mensajes pasan por `__()`/`@lang()` en vez de texto quemado?
