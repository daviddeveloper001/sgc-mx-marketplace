---
name: laravel-modern-syntax
description: Usar como referencia de versión al escribir código nuevo en el backend Laravel de este workspace — confirma que se use sintaxis moderna de PHP 8.4 y Laravel 12.
---

# Entorno y versiones

El proyecto está desarrollado bajo PHP 8.4 y Laravel 12. Usar las capacidades y sintaxis modernas correspondientes: tipado estricto, constructor property promotion, enumeraciones nativas (`enum`), e interfaces estrictas.

## Checklist rápido
- ¿El código nuevo usa tipado estricto (`declare(strict_types=1)` donde aplique, tipos de retorno y parámetros explícitos)?
- ¿Se usa constructor property promotion en vez de propiedades + constructor verboso?
- ¿Los estados/roles/tipos usan `enum` nativo (ver `core-zero-magic-values`) en vez de constantes de clase, cuando el contexto lo permite?
