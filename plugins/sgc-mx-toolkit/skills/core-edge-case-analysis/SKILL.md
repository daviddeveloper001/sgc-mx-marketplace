---
name: core-edge-case-analysis
description: Usar antes de dar por terminada cualquier implementación o fix, en cualquier stack, para verificar que se contemplaron escenarios más allá del happy path descrito en la historia de usuario.
---

# Análisis exhaustivo de escenarios e impacto (Edge Case Deep-Dive)

No basta con resolver lo que describe la historia de usuario. Antes de cerrar una tarea, evalúa explícitamente, entre otros:

- **Error/falla del servicio o petición:** timeouts, errores HTTP 4xx/5xx, excepciones no controladas.
- **Respuesta vacía o nula:** arreglos vacíos, objetos `null`, colecciones sin elementos — no deben romper al iterar, formatear o renderizar (una vista o componente que itera un dato vacío debe mostrar un estado vacío controlado, no fallar).
- **Datos parciales o con estructura inesperada:** campos faltantes, tipos distintos a los esperados, formatos inconsistentes.
- **Condiciones de borde:** valores límite (0, negativos, máximos), duplicados, concurrencia y latencia alta.

## Regla de comunicación
Cuando se identifiquen escenarios no cubiertos explícitamente por la historia de usuario, se deben dejar explícitos en el código, el PR o la respuesta al usuario — para que quede claro qué se contempló más allá de lo pedido y por qué era necesario.

## Checklist rápido
- ¿Qué pasa si el servicio externo falla o tarda demasiado?
- ¿Qué pasa si la respuesta viene vacía, nula, o con un campo faltante?
- ¿Qué pasa en los valores límite (0, negativo, el máximo permitido, un duplicado)?
- ¿Se documentaron los escenarios adicionales que se cubrieron sin que se pidieran explícitamente?
