---
name: nestjs-dtos
description: Usar siempre que se cree o modifique un DTO de entrada en NestJS (Create*Dto, Update*Dto, query params) — exige clases con decoradores de class-validator, tipado explícito, y validación global activa, nunca un objeto plano o any como shape de entrada.
---

# DTOs de entrada (NestJS)

## Reglas

- Toda entrada de un endpoint (body, query params relevantes) se tipa con una clase DTO dedicada (`CreateCategoryDto`, `UpdateCategoryDto`, etc.), nunca un objeto/`Record<string, any>` sin forma ni un tipo inline en la firma del controlador.
- Cada propiedad del DTO usa el decorador de `class-validator` correspondiente a su regla de negocio (`@IsString()`, `@IsInt()`, `@IsOptional()`, `@IsEnum(...)`, etc.) — un campo sin decorador de validación es una señal a revisar, no un default aceptable.
- El tipo de cada propiedad es explícito (`string`, `number`, un enum, una interfaz) — nunca `any` (ver `nestjs-strict-typing`).
- `UpdateDto` normalmente extiende `PartialType(CreateDto)` de `@nestjs/mapped-types` en vez de duplicar las propiedades.
- La validación global (`ValidationPipe` con `whitelist: true, forbidNonWhitelisted: true`) debe estar activa a nivel de aplicación, para que cualquier propiedad no declarada en el DTO sea rechazada, no ignorada en silencio.

## Ejemplo de referencia

```typescript
// create-category.dto.ts
import { IsString, IsOptional, MaxLength } from 'class-validator';

export class CreateCategoryDto {
  @IsString()
  @MaxLength(255)
  name: string;

  @IsOptional()
  @IsString()
  description?: string;
}
```

```typescript
// update-category.dto.ts
import { PartialType } from '@nestjs/mapped-types';
import { CreateCategoryDto } from './create-category.dto';

export class UpdateCategoryDto extends PartialType(CreateCategoryDto) {}
```

## Señales de que se está violando esta regla

- Un método de controlador con `@Body() body: any` o `@Body() body: Record<string, any>` en vez de un DTO tipado.
- Una propiedad del DTO sin ningún decorador de `class-validator`.
- Un `UpdateDto` que repite manualmente las propiedades de su `CreateDto` en vez de usar `PartialType`.
- `ValidationPipe` global ausente o sin `whitelist`/`forbidNonWhitelisted`.

## Checklist rápido
- ¿La entrada del endpoint está tipada con un DTO dedicado, no un objeto suelto?
- ¿Cada propiedad tiene su decorador de `class-validator` correspondiente?
- ¿`UpdateDto` usa `PartialType` en vez de duplicar campos?
- ¿La validación global está activa con `whitelist`/`forbidNonWhitelisted`?
