---
name: core-test-mock-data
description: Usar siempre que se implemente una refactorización, un feature, un fix o cualquier mejora que toque lógica de una función, método o clase, en cualquier stack (Laravel, NestJS u otro) — exige verificar si ya existe un test de esa unidad; si no existe se crea, si existe se valida que el cambio no lo rompa y se ajusta cuando lo afecta. Todo test usa datos mock y dobles de prueba, nunca una conexión real a base de datos, porque el pipeline de Sonar no tiene BD y fallaría.
---

# Tests con datos mock (agnóstico de stack)

Ningún cambio de lógica se cierra sin su test. El test no es un extra: es la evidencia de que la unidad modificada hace lo que dice.

## Flujo obligatorio

Para cada función/método/clase que se crea o modifica:

1. **Buscar si ya existe un test de esa unidad.** Buscar en el proyecto (`tests/`, `*.spec.ts`, `*.test.ts`, `*Test.php`) por el nombre de la clase y del método, no solo por el nombre del archivo.
2. **Si NO existe test → crearlo.** Cubre como mínimo: el camino feliz, cada rama condicional nueva o tocada y los edge cases relevantes (nulo/vacío, error de una dependencia externa, valor límite — ver `core-edge-case-analysis`).
3. **Si existe y el cambio NO lo afecta → dejarlo como está**, pero ejecutarlo para confirmarlo; no se asume que pasa.
4. **Si existe y el cambio SÍ lo afecta (firma, retorno, efectos, excepciones, dependencias) → modificarlo** para reflejar el comportamiento nuevo. Se ajusta la expectativa porque el requisito cambió; nunca se debilita un assert, ni se borra, ni se marca `skip`/`todo` para que pase.
5. **Ejecutar los tests tocados** y reportar el resultado real. Si no se pueden ejecutar (falta entorno o dependencia), decirlo explícitamente; nunca declarar "pasan" sin haberlos corrido.

Si se corrige un bug, el test nuevo debe fallar sin el fix y pasar con él.

## Regla dura: sin base de datos

Los tests corren en el pipeline de Sonar, que **no tiene base de datos**. Un test que abre una conexión real rompe el pipeline. Por eso:

- Prohibido conectarse a una BD real **o embebida/en memoria** (SQLite `:memory:`, `pg-mem`, Testcontainers): sigue siendo una conexión con migraciones corriendo dentro del test.
- Las dependencias de acceso a datos (repositorios, modelos, ORM, cliente de BD, cache, colas, HTTP externo) se **reemplazan por dobles**: mocks, stubs o fakes en memoria.
- Los datos de entrada y de retorno son **datos mock** construidos en el test (objetos literales, builders, factories en modo "make" que no persisten).
- El test de una unidad prueba la lógica de esa unidad con sus colaboradores simulados. De la capa de datos solo se verifica que se le llamó con los argumentos correctos (`expects` / `toHaveBeenCalledWith`), no que persistió.
- Si una clase no se puede probar sin BD porque crea sus dependencias con `new` o consulta de forma estática, es una señal de diseño: se inyecta la dependencia (ver `core-clean-architecture`) en vez de levantar una BD.

## Cómo aplicarlo por stack

### Laravel (PHPUnit/Pest + Mockery)

- Usar `PHPUnit\Framework\TestCase` (o `Tests\TestCase` sin tocar BD) y `Mockery::mock(Repositorio::class)` inyectado por constructor.
- Prohibidos en tests: los traits `RefreshDatabase`, `DatabaseMigrations`, `DatabaseTransactions`, `LazilyRefreshDatabase`; `Model::factory()->create()` / `createMany()`; `DB::`; `assertDatabaseHas` / `assertDatabaseMissing`; `artisan migrate`.
- Datos: `Model::factory()->make()` (no persiste) o `new Model([...])`.
- Un Service se prueba con su Repository mockeado; un Controller, con el Service mockeado. Las reglas de validación `exists:` / `unique:` consultan la BD: se aíslan del test de la unidad o se prueba con un presence verifier mockeado.
- HTTP, colas, mail y eventos: `Http::fake()`, `Queue::fake()`, `Mail::fake()`, `Event::fake()`.

### NestJS (Jest)

- `Test.createTestingModule({ providers: [ServiceBajoPrueba, { provide: Repository, useValue: mockRepository }] })`, con `mockRepository` hecho de `jest.fn()` tipado, sin `any` (ver `nestjs-strict-typing`).
- Prohibidos en tests: `TypeOrmModule.forRoot` / `forRootAsync`, `PrismaClient` o `PrismaService` reales, `DataSource.initialize()`, e2e que levanten la app contra una BD.
- Un Service se prueba con el repositorio mockeado (`findById.mockResolvedValue(...)`), cubriendo también la rama de error del patrón Either (ver `nestjs-either-pattern`). Un Controller, con el Service mockeado.
- Datos: objetos literales o builders tipados con la interfaz/entidad del dominio.

### Otro stack

Mismo principio: inyectar dobles de las dependencias de datos y construir los datos dentro del test. Nunca un motor de BD real o embebido.

## Señales de que se está violando esta regla

- Un cambio de lógica sin ningún archivo de test en el diff y sin haber buscado si ya existía uno.
- Un test que deja de pasar y se "arregla" borrándolo, comentándolo, relajando el assert o con `skip`.
- Un test que usa `RefreshDatabase`, `factory()->create()`, `TypeOrmModule.forRoot`, un `PrismaClient` real o una BD en memoria.
- Un test sin asserts sobre el comportamiento modificado (`expect(true).toBe(true)`).
- Un test que solo pasa por el orden de ejecución o por estado compartido con otro test.

## Checklist rápido
- ¿Se buscó, por clase y método, si ya existía un test de cada unidad tocada?
- ¿Si no existía, se creó con camino feliz, ramas nuevas y edge cases?
- ¿Si existía, se corrió y se ajustó solo porque el comportamiento cambió, sin debilitarlo ni saltarlo?
- ¿Ningún test abre conexión a BD (real ni en memoria) y las dependencias de datos están mockeadas?
- ¿Se ejecutaron los tests y se reporta el resultado real, o se dice que no se pudo correr?
