---
name: nestjs-circular-dependencies
description: Usar siempre que se cree o modifique un import entre módulos, servicios o providers en NestJS — exige evitar dependencias circulares mediante rediseño (extraer lo compartido) en vez de forwardRef() como solución por defecto.
---

# Cero dependencias circulares (NestJS)

## Reglas

- Ningún módulo/servicio importa, directa o indirectamente, algo que termine importándolo a él mismo. Antes de agregar un import nuevo, se verifica que no cierre un ciclo con lo que el archivo destino ya importa.
- La solución por defecto ante una dependencia circular real es **rediseñar**, no `forwardRef()`: extraer la lógica/el contrato compartido a un tercer módulo/servicio del que ambos dependan (sin depender entre sí), o invertir la dependencia hacia una interfaz (ver `nestjs-interfaces-structure`).
- `forwardRef()` (`@Inject(forwardRef(() => X))` + `forwardRef(() => XModule)`) se usa solo como último recurso, cuando el ciclo es estructural e inevitable en el dominio (ej. dos entidades que genuinamente se referencian entre sí) — y esa decisión debe quedar justificada en la explicación al usuario, no aplicada por defecto ante el primer error de NestJS al arrancar.

## Ejemplo de referencia

```typescript
// Incorrecto: CategoryService y ProductService se importan mutuamente
// category.service.ts
import { ProductService } from '../product/product.service';
// product.service.ts
import { CategoryService } from '../category/category.service';

// Correcto: la lógica compartida se extrae a un tercer servicio
// catalog-stock.service.ts
@Injectable()
export class CatalogStockService {
  // usado por CategoryService y ProductService, ninguno de los dos
  // depende del otro directamente
}
```

## Señales de que se está violando esta regla

- `forwardRef()` agregado como primera reacción a un error de "Nest can't resolve dependencies" al arrancar la app, sin evaluar si el diseño se puede reordenar.
- Dos servicios que se inyectan mutuamente sin que el dominio realmente lo exija.
- Un módulo A que importa el módulo B, y B que importa A, sin `forwardRef()` ni justificación (fallaría al arrancar, pero es la señal más temprana de un ciclo mal resuelto).

## Checklist rápido
- ¿El import nuevo cierra un ciclo con algo que el archivo destino ya importa?
- Si hay un ciclo real, ¿se evaluó extraer la lógica compartida antes de usar `forwardRef()`?
- Si se usó `forwardRef()`, ¿está justificado como caso estructural, no como atajo?
