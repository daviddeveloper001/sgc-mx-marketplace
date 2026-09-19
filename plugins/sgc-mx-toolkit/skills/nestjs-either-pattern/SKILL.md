---
name: nestjs-either-pattern
description: Usar siempre que un Service/Repository de NestJS necesite comunicar un resultado que puede fallar de forma esperada (regla de negocio, no encontrado, validación) — exige el patrón Either en vez de lanzar excepciones para control de flujo esperado.
---

# Patrón Either para errores esperados (NestJS)

## Reglas

- Un fallo **esperado** dentro de una regla de negocio (ej. "el email ya existe", "el registro no se encontró", "el saldo es insuficiente") se comunica devolviendo un `Either<Error, T>`, no lanzando una excepción — las excepciones quedan reservadas para fallos genuinamente inesperados (infraestructura caída, un bug).
- El tipo `Either<L, R>` vive en un archivo compartido (ver `nestjs-interfaces-structure`), con sus dos constructores (`left`/`right`) y una forma de distinguir el caso en el consumidor (`isLeft`/`isRight`).
- El Controller (o el Service que llama a otro Service) siempre revisa explícitamente el resultado (`isLeft`/`isRight`) antes de continuar — nunca asume el lado feliz sin comprobarlo.
- El valor del lado izquierdo (`Left`) es un tipo de error de negocio propio (no un `string` suelto ni una excepción genérica), para que el consumidor pueda diferenciar casos sin parsear mensajes.

## Ejemplo de referencia

```typescript
// either.ts
export class Left<L, R> {
  constructor(readonly value: L) {}
  isLeft(): this is Left<L, R> { return true; }
  isRight(): this is Right<L, R> { return false; }
}

export class Right<L, R> {
  constructor(readonly value: R) {}
  isLeft(): this is Left<L, R> { return false; }
  isRight(): this is Right<L, R> { return true; }
}

export type Either<L, R> = Left<L, R> | Right<L, R>;

export const left = <L, R>(value: L): Either<L, R> => new Left(value);
export const right = <L, R>(value: R): Either<L, R> => new Right(value);
```

```typescript
// category.service.ts
async createCategory(
  data: CreateCategoryDto,
): Promise<Either<CategoryError, Category>> {
  const exists = await this.categoryRepository.findByName(data.name);

  if (exists) {
    return left(new CategoryError('CATEGORY_NAME_TAKEN', 'El nombre ya existe'));
  }

  const category = await this.categoryRepository.create(data);
  return right(category);
}
```

```typescript
// category.controller.ts
const result = await this.categoryService.createCategory(dto);

if (result.isLeft()) {
  throw new ConflictException(result.value.message);
}

return result.value;
```

## Señales de que se está violando esta regla

- Un `throw new BadRequestException(...)` dentro del Service para un caso de negocio esperado (email duplicado, stock insuficiente) en vez de devolver `left(...)`.
- Un Controller que asume `result.value` sin comprobar `isLeft()`/`isRight()` antes.
- Un `Either` cuyo lado izquierdo es un `string` suelto en vez de un tipo de error propio.

## Checklist rápido
- ¿Los fallos esperados de negocio devuelven `Either`, no una excepción lanzada?
- ¿El consumidor comprueba `isLeft()`/`isRight()` antes de usar el resultado?
- ¿El lado izquierdo es un tipo de error propio, no un string suelto?
