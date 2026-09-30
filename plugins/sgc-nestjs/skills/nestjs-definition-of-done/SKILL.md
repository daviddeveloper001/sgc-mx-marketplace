---
name: nestjs-definition-of-done
description: Usar antes de dar por terminada una tarea que modificó código TypeScript de un backend NestJS. Puntos NEST-1…NEST-6 del checklist de cierre (tipado estricto, DTOs, patrón Either, interfaces en archivo propio, repositorios, dependencias circulares), que se suman a los CORE-* de process-definition-of-done.
---

# Checklist de cierre — módulo NestJS (NEST-*)

Complementa a `process-definition-of-done` (plugin `sgc-core`): los puntos CORE-* aplican siempre, y estos se suman cuando el diff toca TypeScript dentro de las carpetas NestJS del repo. El revisor que los verifica es `sgc-nestjs:dod-reviewer`. El gate `dod-stop-gate.sh` indica qué puntos ya vienen descartados mecánicamente según los archivos tocados.

Recordatorio: el principio de controlador delgado de Nest (DTO + `class-validator` en el controller, lógica en un `*.service.ts` inyectado) lo cubre **CORE-1**, y los literales de estado/rol/tipo los cubre **CORE-2**.

1. **NEST-1 · Tipado estricto.** ¿Cero `any` explícito o implícito en variables, parámetros, retornos o propiedades? ¿Los `catch` tipan el error como `unknown` y hacen narrowing antes de usarlo? ¿Nada de `as any` para silenciar errores, y `strict`/`noImplicitAny` siguen activos en `tsconfig.json`? (`nestjs-strict-typing`)
2. **NEST-2 · DTOs de entrada.** ¿Toda entrada de endpoint (body, query params relevantes) está tipada con una clase DTO dedicada, cada propiedad con su decorador de `class-validator`, `UpdateDto` extendiendo `PartialType(CreateDto)`, y `ValidationPipe` global con `whitelist`/`forbidNonWhitelisted`? (`nestjs-dtos`)
3. **NEST-3 · Either para fallos esperados.** ¿Los fallos esperados de negocio (no encontrado, duplicado, saldo insuficiente…) devuelven `Either<ErrorPropio, T>` en vez de lanzar una excepción? ¿El consumidor comprueba `isLeft()`/`isRight()` antes de usar el resultado? ¿El lado izquierdo es un tipo de error propio, no un `string` suelto? (`nestjs-either-pattern`)
4. **NEST-4 · Interfaces en archivo propio.** ¿Cada interfaz nueva vive en su `kebab-case.interface.ts`, no declarada dentro del archivo que la consume? ¿El archivo de la interfaz no importa su implementación, y una interfaz compartida vive en un solo lugar? (`nestjs-interfaces-structure`)
5. **NEST-5 · Repositories.** ¿El acceso a un solo registro pasa por un Repository que implementa `BaseRepositoryInterface<T, ...>` (TypeORM: extiende `BaseRepository<T>`; Prisma: tipos `Prisma.<Modelo>CreateInput`/`UpdateInput`), y no por queries directas en el Service? (`nestjs-repositories`)
6. **NEST-6 · Dependencias circulares.** ¿Ningún import nuevo cierra un ciclo entre módulos/servicios/providers? Si hay un ciclo real, ¿se evaluó extraer lo compartido antes de usar `forwardRef()`, y su uso está justificado como caso estructural? (`nestjs-circular-dependencies`)
