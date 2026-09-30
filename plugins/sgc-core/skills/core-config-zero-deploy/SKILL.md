---
name: core-config-zero-deploy
description: Usar cuando se vaya a agregar o modificar un valor de configuración de negocio (montos, porcentajes, límites, llaves operativas, listas de destinatarios, flags de características) en cualquier stack.
---

# Configuración dinámica y Zero Deploy

Prohibido quemar valores de configuración de negocio o reglas dinámicas directamente en código fuente o en archivos estáticos de configuración (`config/*.php`, `.env`, `appsettings.json`, etc.) cuando se trata de parámetros sujetos a cambio operativo.

## Reglas
- Los valores operacionales (montos, porcentajes, límites, llaves, listas, flags) deben almacenarse en base de datos: tablas de configuración, settings, catálogos o parámetros del sistema.
- El objetivo es que un cambio en estos valores pueda hacerse directamente en BD o desde un panel de administración, reflejándose en tiempo real sin requerir cambio de código, PR, QA ni despliegue.

## Cómo distinguir qué va en BD vs qué va en `.env`/`config`
- `.env`/`config` es para configuración de infraestructura (credenciales, endpoints, modo debug) que cambia por ambiente, no por decisión de negocio.
- Base de datos es para cualquier valor que el negocio pueda querer cambiar sin pasar por un despliegue.

## Checklist rápido
- ¿Este valor lo puede querer cambiar alguien de negocio/soporte sin depender de un desarrollador?
- Si sí: ¿está en BD (o un panel), o quedó quemado en código/`.env`?
