---
name: core-design-patterns-ocp
description: Usar al implementar una característica que hoy tiene una sola variante pero es previsible que crezca a múltiples canales o proveedores (notificaciones, pasarelas de pago, integraciones externas, formatos de exportación). Evita resolver con acumulación de if/else o switch.
---

# Escalabilidad, extensibilidad y patrones de diseño

Antes de implementar, analiza cómo puede crecer el sistema y cuánto costará su evolución o mantenimiento.

## Reglas
- Si una característica es susceptible de tener múltiples variantes o canales (SMS hoy, Telegram/Email/WhatsApp mañana; una pasarela de pago hoy, varias después), está prohibido resolverlo acumulando condicionales (`if/else`, `switch`).
- Usa patrones de comportamiento y creacionales (Factory, Strategy) con interfaces y polimorfismo, de modo que agregar una nueva variante no requiera modificar la lógica central existente (principio Abierto/Cerrado).
- Esto no es "usar patrones porque sí": aplica cuando hay evidencia razonable de que habrá más de una variante — no lo apliques preventivamente a algo que genuinamente tiene una sola forma posible (sobre-ingeniería es también una violación de esta regla, en sentido inverso).

## Checklist rápido
- ¿Esta lógica tiene más de una variante hoy, o es razonablemente previsible que la tenga?
- Si sí: ¿agregar una nueva variante requiere tocar la clase orquestadora central, o solo agregar una nueva implementación de la interfaz?
- ¿Se justificó la elección del patrón en la respuesta al usuario, o se aplicó en silencio sin exponer el trade-off?
