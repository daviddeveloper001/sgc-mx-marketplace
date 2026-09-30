---
name: laravel-i18n
description: Usar siempre que se escriba un string visible para el usuario en Laravel — mensajes, errores, labels de vista, respuestas JSON, redirecciones.
---

# Internacionalización y textos (Laravel)

## Reglas
- Prohibido quemar strings, alertas, mensajes de error o etiquetas de vista directamente en español, inglés o cualquier otro idioma.
- Todo texto de retorno, respuesta JSON, mensaje de redirección, o elemento de vista Blade debe resolverse mediante el sistema de localización de Laravel: el helper `__(...)` o la directiva `@lang(...)`, apuntando a los archivos de idioma correspondientes (ej. `lang/es/messages.php`).
- Cada string nuevo debe tener su entrada correspondiente creada en el archivo de idioma, no solo la llamada a `__()` sin la clave definida.

## Checklist rápido
- ¿Hay algún string literal visible para el usuario sin pasar por `__()`/`@lang()`?
- ¿La clave usada en `__()` existe realmente en `lang/*/....php`?
