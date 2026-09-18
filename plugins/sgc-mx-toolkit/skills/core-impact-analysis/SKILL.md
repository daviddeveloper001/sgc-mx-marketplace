---
name: core-impact-analysis
description: Usar antes de modificar cualquier función, método, modelo, servicio, trait, clase o tabla que ya existe en el proyecto y puede tener otros consumidores.
---

# Análisis de impacto y no regresión

Antes de modificar cualquier estructura existente, es responsabilidad del agente validar y buscar en todo el proyecto dónde más se invoca o utiliza esa estructura.

## Reglas
- Buscar (grep/búsqueda semántica) todos los puntos de consumo de la estructura antes de tocarla.
- Si la estructura es usada en otros módulos, validar rigurosamente que el cambio no rompe, altera ni afecta negativamente esos flujos.
- Siempre preservar compatibilidad, o adaptar todos los puntos de consumo afectados para evitar regresiones — no basta con que el caso que motivó el cambio funcione.

## Regla de comunicación (impacto colateral)
Si al investigar se descubre que el mismo problema o patrón de riesgo aplica a otras partes del sistema no mencionadas explícitamente por quien pidió la tarea (otros módulos, roles, flujos), se debe reportar explícitamente qué se revisó, qué sí está afectado y qué no — con evidencia, no limitarse al caso puntual reportado.

## Checklist rápido
- ¿Se buscó en todo el proyecto dónde se usa esta estructura antes de modificarla?
- ¿Cada punto de consumo encontrado sigue funcionando igual (o se adaptó a propósito)?
- ¿Se encontró el mismo patrón de riesgo en otro lugar no pedido explícitamente? Si sí, ¿se reportó?
