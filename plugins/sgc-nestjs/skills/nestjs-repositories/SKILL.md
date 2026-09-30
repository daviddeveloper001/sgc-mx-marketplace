---
name: nestjs-repositories
description: Usar siempre que se cree o modifique un repositorio de acceso a datos en NestJS — exige una interfaz base con las operaciones CRUD genéricas y un repositorio que la implemente sobre el ORM del proyecto (TypeORM o Prisma). Equivalente de laravel-api-repositories, pero limitado por ahora a este nivel (sin Filter/Service/Exception todavía para NestJS).
---

# Repositorio base de acceso a datos (NestJS)

Convención de la capa de datos, equivalente al patrón `BaseRepositoryV1` de Laravel — pero limitado por ahora a la interfaz + repositorio genérico. No hay (todavía) un equivalente NestJS de `QueryFilter`, `Service` de orquestación ni excepciones de dominio de API; eso se define en otra ronda.

**El ORM varía por proyecto** (TypeORM en unos, Prisma en otros) — el contrato (`BaseRepositoryInterface<T>`) es el mismo en ambos casos; solo cambia cómo se implementa.

## Reglas

- Toda operación de acceso a datos de un solo registro (buscar, crear, actualizar, eliminar) pasa por una clase Repository, nunca queries directas en el Service/Controller — sin importar el ORM.
- Existe una interfaz genérica `BaseRepositoryInterface<T, CreateInput, UpdateInput>` que define las operaciones básicas. Los parámetros `CreateInput`/`UpdateInput` existen porque el shape de "crear"/"actualizar" no es necesariamente igual a `T` en ningún ORM (TypeORM usa `DeepPartial<T>`/`QueryDeepPartialEntity<T>`; Prisma genera un tipo `<Modelo>CreateInput`/`<Modelo>UpdateInput` propio por modelo) — nunca se fuerza con `any` para evitar declarar estos tipos.
- **Con TypeORM**: existe una clase abstracta `BaseRepository<T>` que implementa la interfaz envolviendo `Repository<T>` de TypeORM; un repositorio concreto la extiende e inyecta su propio `Repository<Entidad>` — nunca reimplementa `create`/`update`/`delete` desde cero si el genérico ya lo cubre.
- **Con Prisma**: no existe una clase base genérica equivalente (los delegates de Prisma —`prisma.category`, `prisma.product`— son tipados por modelo, no bajo un genérico común útil sin type-gymnastics innecesaria) — cada repositorio concreto implementa `BaseRepositoryInterface<T, ...>` directamente, inyectando `PrismaService` y llamando a su propio delegate (`this.prisma.category.findMany()`, etc.).
- La interfaz vive en su propio archivo, nunca declarada en el mismo archivo que la usa (ver `nestjs-interfaces-structure`).
- Sin `any` en ningún punto de la implementación (ver `nestjs-strict-typing`).

## Ejemplo de referencia

```typescript
// base-repository.interface.ts
export interface BaseRepositoryInterface<T, CreateInput = Partial<T>, UpdateInput = Partial<T>> {
  findAll(): Promise<T[]>;
  findById(id: number): Promise<T | null>;
  create(data: CreateInput): Promise<T>;
  update(id: number, data: UpdateInput): Promise<T>;
  delete(id: number): Promise<void>;
}
```

### Con TypeORM

```typescript
// base.repository.ts
import { DeepPartial, FindOptionsWhere, Repository } from 'typeorm';
import { QueryDeepPartialEntity } from 'typeorm/query-builder/QueryPartialEntity';
import { BaseRepositoryInterface } from './base-repository.interface';

export abstract class BaseRepository<T extends { id: number }>
  implements BaseRepositoryInterface<T, DeepPartial<T>, QueryDeepPartialEntity<T>>
{
  protected constructor(protected readonly repository: Repository<T>) {}

  findAll(): Promise<T[]> {
    return this.repository.find();
  }

  findById(id: number): Promise<T | null> {
    return this.repository.findOneBy({ id } as FindOptionsWhere<T>);
  }

  create(data: DeepPartial<T>): Promise<T> {
    const entity = this.repository.create(data);
    return this.repository.save(entity);
  }

  async update(id: number, data: QueryDeepPartialEntity<T>): Promise<T> {
    await this.repository.update(id, data);
    return this.findById(id) as Promise<T>;
  }

  async delete(id: number): Promise<void> {
    await this.repository.delete(id);
  }
}
```

```typescript
// category.repository.ts
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BaseRepository } from '../common/base.repository';
import { Category } from './category.entity';

@Injectable()
export class CategoryRepository extends BaseRepository<Category> {
  constructor(@InjectRepository(Category) repository: Repository<Category>) {
    super(repository);
  }
}
```

### Con Prisma

```typescript
// category.repository.ts
import { Injectable } from '@nestjs/common';
import { Prisma, Category } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { BaseRepositoryInterface } from '../common/base-repository.interface';

@Injectable()
export class CategoryRepository
  implements BaseRepositoryInterface<Category, Prisma.CategoryCreateInput, Prisma.CategoryUpdateInput>
{
  constructor(private readonly prisma: PrismaService) {}

  findAll(): Promise<Category[]> {
    return this.prisma.category.findMany();
  }

  findById(id: number): Promise<Category | null> {
    return this.prisma.category.findUnique({ where: { id } });
  }

  create(data: Prisma.CategoryCreateInput): Promise<Category> {
    return this.prisma.category.create({ data });
  }

  update(id: number, data: Prisma.CategoryUpdateInput): Promise<Category> {
    return this.prisma.category.update({ where: { id }, data });
  }

  async delete(id: number): Promise<void> {
    await this.prisma.category.delete({ where: { id } });
  }
}
```

## Señales de que se está violando esta regla

- Un Service que inyecta `Repository<Entidad>` de TypeORM o `PrismaService` directamente y arma queries ahí, en vez de pasar por su propio Repository.
- En un proyecto TypeORM: un Repository concreto que no extiende `BaseRepository<T>`, o que reimplementa `create`/`delete` sin necesidad.
- En un proyecto Prisma: un repositorio que usa `any` para el tipo de `data` en `create`/`update` en vez de `Prisma.<Modelo>CreateInput`/`UpdateInput`.
- La interfaz `BaseRepositoryInterface` declarada en el mismo archivo que la implementa o la consume.

## Checklist rápido
- ¿El acceso a un solo registro pasa por un Repository, no por queries directas en el Service?
- ¿El repositorio implementa (o extiende, en TypeORM) `BaseRepositoryInterface<T, ...>`?
- Si es TypeORM: ¿el repositorio concreto extiende `BaseRepository<T>` en vez de reimplementar CRUD desde cero?
- Si es Prisma: ¿usa los tipos `Prisma.<Modelo>CreateInput`/`UpdateInput` en vez de `any`?
- ¿La interfaz vive en su propio archivo?
