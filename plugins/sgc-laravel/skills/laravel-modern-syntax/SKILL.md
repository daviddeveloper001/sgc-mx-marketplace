---
name: laravel-modern-syntax
description: Usar como referencia de versión al escribir código nuevo en el backend Laravel de este workspace — confirma que se use sintaxis moderna de PHP 8.4 y Laravel 12, que la inyección de dependencias use constructor property promotion, y que ninguna clase colaboradora se instancie con `new` dentro de otra clase en vez de inyectarse.
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

- **Prohibido instanciar una clase colaboradora con `new` dentro de otra clase**: si una clase necesita colaborar con otra clase propia del proyecto (un Service, Repository, Model usado como colaborador, cliente HTTP, etc.), esa dependencia se recibe siempre por constructor — nunca se crea con `new` dentro de un método. Instanciar manualmente acopla la clase a una implementación concreta y hace imposible sustituirla en un test sin levantar toda la cadena real.

  ```php
  // Incorrecto — instancia la dependencia dentro del método
  class RequestService
  {
      public function getRequest(): Request
      {
          $customer = new Customer();

          return $customer->findRequest();
      }
  }

  // Correcto — la dependencia se recibe por constructor
  class RequestService
  {
      public function __construct(private CustomerRepository $customerRepository) {}

      public function getRequest(): Request
      {
          return $this->customerRepository->findRequest();
      }
  }
  ```

  **Excepción explícita**: esto no aplica a value objects/DTOs sin dependencias propias que solo empaquetan datos (`new CategoryData(...)`), ni a clases del lenguaje/framework que no son colaboradores de negocio (`new Carbon()`, `new Collection()`, `throw new ...Exception(...)`). La regla es sobre colaboradores con lógica o dependencias propias, no sobre cualquier uso de `new` en el código.

## Señales de que se está violando esta regla

- Una propiedad declarada arriba del constructor y asignada con `$this->x = $x;` dentro del cuerpo, en vez de promoted property.
- Un constructor con lógica además de la asignación de dependencias (motivo aparte para revisar `laravel-thin-controllers`/`core-clean-architecture` si la clase es un controlador).
- Un método que hace `new` de un Service, Repository, cliente HTTP o cualquier otra clase propia del proyecto que debería haber llegado por constructor.

## Checklist rápido
- ¿El código nuevo usa tipado estricto (`declare(strict_types=1)` donde aplique, tipos de retorno y parámetros explícitos)?
- ¿Toda dependencia inyectada por constructor usa `private <Tipo> $propiedad` directamente en la firma del `__construct`, sin propiedad + asignación separada?
- ¿Los estados/roles/tipos usan `enum` nativo (ver `core-zero-magic-values`) en vez de constantes de clase, cuando el contexto lo permite?
- ¿Ninguna clase colaboradora (Service, Repository, Model usado como colaborador, cliente externo) se instancia con `new` dentro de un método, en vez de recibirse por constructor?
