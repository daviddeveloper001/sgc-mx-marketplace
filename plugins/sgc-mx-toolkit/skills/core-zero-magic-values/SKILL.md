---
name: core-zero-magic-values
description: Usar siempre que se escriba una comparación, condicional o asignación de estado/rol/tipo/configuración usando un literal de texto o número suelto, en cualquier lenguaje. Aplica a PHP, TypeScript, SQL, o configuración.
---

# Cero cadenas o números mágicos

Prohibido usar literales (`'activo'`, `'pendiente'`, `1`, `2`) para representar estados, roles, tipos o configuraciones estáticas dentro de lógica de control de flujo.

## Reglas
- Todo estado/rol/tipo/flag debe representarse con un Enum nativo del lenguaje (`enum` de PHP 8.1+, `enum` de TypeScript, o su equivalente) o, si el lenguaje/contexto no lo permite, una constante de clase con nombre explícito.
- El nombre del enum/constante debe expresar el significado de negocio, no el valor técnico (`OrderStatus::PENDING`, no `Status::TWO`).
- Esto aplica también a comparaciones dentro de queries (`where('status', OrderStatus::PENDING->value)`), no solo a condicionales en memoria.

## Señales de que se está violando esta regla
- `if ($status === 1)`, `case 'admin':`, `WHERE type = 2` con el número sin explicar en ningún lado.
- Un valor que se repite en más de un archivo sin una fuente única de verdad (el enum).

## Checklist rápido
- ¿Cada literal de control de flujo tiene un Enum o constante detrás?
- ¿Si mañana cambia el valor interno (ej. de int a string), solo hay que tocar un lugar?
