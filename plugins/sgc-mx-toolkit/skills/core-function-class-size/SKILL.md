---
name: core-function-class-size
description: Usar siempre que se cree o modifique una función, método o clase en cualquier stack — limita a 4 el número de `return` por función/método y a 20 el número de métodos por clase; señal de que hace falta dividir en funciones o servicios más específicos.
---

# Tamaño y complejidad de funciones y clases (agnóstico de stack)

## Reglas

- **Máximo 4 `return` por función o método** (contando guard clauses, early returns y el retorno final). Superar ese límite es señal de que la función está resolviendo más de una responsabilidad o tiene demasiadas ramas condicionales — hay que dividirla en funciones más pequeñas o simplificar la lógica (tabla de casos, early return consolidado, patrón Strategy — ver `core-design-patterns-ocp`).
- **Máximo 20 métodos por clase** (públicos + privados + protegidos). Superar ese límite es señal de que la clase acumula más de una responsabilidad — se extraen uno o más servicios específicos (principio de responsabilidad única), en vez de seguir agregando métodos a la clase existente.
- Estos límites son señales de diseño, no una meta a maquillar: no se resuelve partiendo una función en dos que ejecutan el mismo flujo fragmentado sin cohesión propia, ni moviendo métodos a una clase `Helper`/`Utils` genérica solo para bajar el conteo — la clase o función nueva debe tener su propia responsabilidad clara.

## Señales de que se está violando esta regla

- Una función con 5+ `return` repartidos entre validaciones, ifs anidados y el flujo feliz — típicamente valida, transforma y decide en el mismo bloque.
- Una clase tipo `UserService`/`OrderService` que fue creciendo método a método hasta superar 20 — normalmente mezcla creación, notificación, reportes y validación, cuando debería dividirse en servicios específicos (`UserNotifier`, `UserReportBuilder`, etc.).
- Un refactor que "resuelve" el límite creando una clase `XHelper`/`XUtils` que junta métodos sin relación entre sí, solo para que la clase original baje de 20.

## Checklist rápido
- ¿Alguna función/método tocado en este diff tiene más de 4 `return`?
- ¿Alguna clase tocada en este diff superó (o ya tenía) más de 20 métodos?
- Si se dividió código para cumplir el límite, ¿la función/clase nueva tiene una responsabilidad propia y cohesiva, o es solo un contenedor para bajar el número?
