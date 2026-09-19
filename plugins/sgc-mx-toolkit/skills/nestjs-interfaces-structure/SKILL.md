---
name: nestjs-interfaces-structure
description: Usar siempre que se declare una interfaz TypeScript en el backend NestJS — exige que viva en su propio archivo, nunca declarada dentro del archivo que la consume, e importada donde se necesite.
---

# Interfaces en archivo propio (NestJS/TypeScript)

## Reglas

- Toda interfaz (contrato de datos, contrato de repositorio, forma de un payload) se declara en su propio archivo (`<nombre>.interface.ts`), nunca inline en el archivo del Service/Controller/Repository que la usa.
- El archivo de la interfaz no importa nada de la clase que la implementa — la dependencia va en un solo sentido (la implementación importa la interfaz, nunca al revés), para evitar dependencias circulares (ver `nestjs-circular-dependencies`).
- Una interfaz usada por múltiples módulos vive en una carpeta compartida (`common/interfaces/` o equivalente del proyecto), no duplicada en cada módulo que la necesita.
- Convención de nombre de archivo: `kebab-case.interface.ts`, exportando una interfaz con `PascalCase`.

## Ejemplo de referencia

```typescript
// category-repository.interface.ts
import { Category } from './category.entity';

export interface CategoryRepositoryInterface {
  findAll(): Promise<Category[]>;
  findById(id: number): Promise<Category | null>;
}
```

```typescript
// category.repository.ts
import { Injectable } from '@nestjs/common';
import { CategoryRepositoryInterface } from './category-repository.interface';

@Injectable()
export class CategoryRepository implements CategoryRepositoryInterface {
  // ...
}
```

## Señales de que se está violando esta regla

- `interface CategoryRepositoryInterface { ... }` declarada arriba de la clase `CategoryRepository` en el mismo archivo.
- Una interfaz duplicada en dos módulos distintos en vez de vivir en un solo archivo compartido e importado.
- Un archivo `.interface.ts` que importa la clase que lo implementa (dependencia invertida, candidata a circular).

## Checklist rápido
- ¿Cada interfaz nueva vive en su propio archivo `.interface.ts`?
- ¿El archivo de la interfaz no importa la implementación?
- ¿Una interfaz compartida entre módulos vive en un solo lugar, no duplicada?
