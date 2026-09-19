---
name: laravel-modern-syntax
description: Usar como referencia de versión al escribir código nuevo en el backend Laravel de este workspace — confirma que se use sintaxis moderna de PHP 8.4 y Laravel 12, y que la inyección de dependencias use constructor property promotion.
---

# Entorno y versiones

El proyecto está desarrollado bajo PHP 8.4 y Laravel 12. Usar las capacidades y sintaxis modernas correspondientes: tipado estricto, constructor property promotion, enumeraciones nativas (`enum`), e interfaces estrictas.

## Reglas

- Tipado estricto: tipos de retorno y de parámetros explícitos en todo método/función nuevo.
- Estados/roles/tipos vía `enum` nativo (ver `core-zero-magic-values`) en vez de constantes de clase, cuando el contexto lo permite.
- **Inyección de dependencias**: siempre vía constructor property promotion, nunca declarando la propiedad aparte y asignándola en el cuerpo del constructor. Aplica a controladores, servicios, jobs, listeners y cualquier clase que reciba dependencias por constructor.

  ```php
  // Correcto
  public function __construct(private CategoryServiceV1 $categoryService) {}

  // Incorrecto — verboso, no es la sintaxis moderna del proyecto
  private CategoryServiceV1 $categoryService;

  public function __construct(CategoryServiceV1 $categoryService)
  {
      $this->categoryService = $categoryService;
  }
  ```

## Señales de que se está violando esta regla

- Una propiedad declarada arriba del constructor y asignada con `$this->x = $x;` dentro del cuerpo, en vez de promoted property.
- Un constructor con lógica además de la asignación de dependencias (motivo aparte para revisar `laravel-thin-controllers`/`core-clean-architecture` si la clase es un controlador).

## Checklist rápido
- ¿El código nuevo usa tipado estricto (`declare(strict_types=1)` donde aplique, tipos de retorno y parámetros explícitos)?
- ¿Toda dependencia inyectada por constructor usa `private <Tipo> $propiedad` directamente en la firma del `__construct`, sin propiedad + asignación separada?
- ¿Los estados/roles/tipos usan `enum` nativo (ver `core-zero-magic-values`) en vez de constantes de clase, cuando el contexto lo permite?
