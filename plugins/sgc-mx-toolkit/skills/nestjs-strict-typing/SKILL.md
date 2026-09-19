---
name: nestjs-strict-typing
description: Usar siempre que se escriba o modifique código TypeScript en el backend NestJS — prohíbe el tipo any (explícito o implícito) en cualquier variable, parámetro, retorno o catch, exigiendo un tipo, interfaz o unknown con type guard en su lugar.
---

# Tipado estricto, cero `any` (NestJS/TypeScript)

## Reglas

- Prohibido `any` explícito en cualquier variable, parámetro de función, tipo de retorno, o propiedad de clase/DTO/interfaz.
- Prohibido el `any` implícito — `strict` y `noImplicitAny` deben estar activos en `tsconfig.json`; un parámetro sin tipo declarado que TypeScript infiere como `any` es la misma violación que escribirlo explícito.
- Cuando el tipo real no se conoce en tiempo de compilación (ej. una respuesta externa, un payload de webhook), se usa `unknown` y se angosta con un type guard (`if (typeof x === '...')`, una función `is...`, o validación con `class-validator`/`zod`) antes de usarlo — nunca un cast directo a `any` para "silenciar" el error de tipos.
- Los bloques `catch` tipan el error como `unknown` (`catch (error: unknown)`), no `any` — TypeScript 4.4+ ya tipa `catch` como `unknown` por defecto si `useUnknownInCatchVariables` está activo, y no debe forzarse a `any`.
- Toda forma de datos usada más de una vez (parámetro de función, retorno, payload) tiene su tipo/interfaz declarado en su propio archivo (ver `nestjs-interfaces-structure`) — no un objeto anónimo repetido en varios lugares.

## Ejemplo de referencia

```typescript
// Incorrecto
async function getCategory(id: any): Promise<any> {
  try {
    return await this.categoryRepository.findById(id);
  } catch (error: any) {
    throw error;
  }
}

// Correcto
async function getCategory(id: number): Promise<Category | null> {
  try {
    return await this.categoryRepository.findById(id);
  } catch (error: unknown) {
    if (error instanceof QueryFailedError) {
      throw new CategoryException('Failed to retrieve category', { cause: error });
    }
    throw error;
  }
}
```

## Señales de que se está violando esta regla

- `any` explícito en una firma de función, DTO, interfaz, o variable.
- Un parámetro sin tipo que TypeScript infiere como `any` (falla silenciosa si `noImplicitAny` está apagado).
- `catch (error: any)` en vez de `catch (error: unknown)` con narrowing posterior.
- Un cast `as any` usado para evitar un error de tipos en vez de corregir el tipo real.

## Checklist rápido
- ¿Hay algún `any` explícito en el diff?
- ¿`tsconfig.json` tiene `strict`/`noImplicitAny` activos, y el código no lo elude con `as any`?
- ¿Los `catch` tipan el error como `unknown`, con narrowing antes de usarlo?
- ¿Cada forma de datos repetida tiene un tipo/interfaz propio, no un objeto anónimo?
