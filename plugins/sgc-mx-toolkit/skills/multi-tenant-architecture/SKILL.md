---
name: multi-tenant-architecture
description: Usar siempre que una tarea toque un job, comando, servicio o listener que procese datos de más de un tenant (planes, sincronización masiva, operaciones que iteran Plan->tenants()). Específico de arquitectura SaaS multi-tenant, no de un stack en particular.
---

# Diseño multi-tenant a escala

Este sistema es multi-tenant: un plan puede tener asociados muchos tenants, y cada tenant puede tener muchos usuarios, créditos, clientes, integraciones, roles, etc. "Funciona probado con un tenant" no es criterio de aceptación.

## Reglas
- Toda implementación (jobs, comandos, servicios, listeners) debe diseñarse asumiendo N tenants × M registros por tenant desde el primer borrador, no como optimización posterior.
- **Prohibido** procesar todos los tenants de un plan/operación dentro de un solo job/request. Si una operación afecta a varios tenants, el job debe encolar una unidad de trabajo por tenant, en vez de iterar sobre todos ellos en un único método síncrono (`foreach ($plan->tenants as $tenant)` dentro de un mismo `handle()` no escala: sin paralelismo, un tenant lento/fallido bloquea al resto, y choca con el timeout del job).
- **Capacidad de colas real:** antes de asumir que "está en cola" resuelve el problema, verificar cuántos workers atienden esa cola específica y si compiten por el mismo worker con otras operaciones críticas (ej. aprovisionamiento de tenants nuevos).
- **Aislamiento de tenant en cachés y conexiones:** cualquier caché (permisos, roles, configuración) debe evaluarse explícitamente — si el key es genérico/global mientras el backend es compartido entre tenants, cualquier switch de tenant (`tenancy()->initialize()`/`end()`) debe invalidar o namespacear ese caché. Mismo criterio para cualquier código que cambie de conexión de BD (central ↔ tenant): trazar explícitamente en qué conexión queda el proceso después de cada llamada a un job/servicio externo.
- **Idempotencia y recuperación parcial:** cualquier operación que toque varios tenants debe poder fallar para uno sin afectar a los demás, y poder re-ejecutarse de forma segura sin duplicar ni corromper datos ya procesados.
- **Cobertura de test:** cuando se implemente o corrija lógica que cruza el límite de tenant, la prueba mínima aceptable incluye más de un tenant simulado — el bug puede no manifestarse hasta que hay datos de más de un tenant en juego.
- **Dimensionamiento de workers según fan-out:** un job que se dispara una vez por evento puede vivir con `numprocs=1`. Un job que se dispara una vez por cada tenant de un plan (fan-out) necesita `numprocs` proporcional a esa naturaleza — el número exacto se valida contra la capacidad real (conexiones a BD, cores del servidor) y el volumen esperado de tenants por plan, nunca se copia de otra cola.

## Checklist rápido
- ¿Esta operación puede afectar a más de un tenant? Si sí, ¿está encolada por tenant, no iterada en un solo job?
- ¿Alguna caché usada aquí tiene un key global que podría mezclar datos de distintos tenants?
- ¿Qué pasa si falla el tenant 3 de 10? ¿Se puede reintentar solo ese sin duplicar los otros 9?
- ¿El test cubre al menos 2 tenants simulados, no solo 1?
