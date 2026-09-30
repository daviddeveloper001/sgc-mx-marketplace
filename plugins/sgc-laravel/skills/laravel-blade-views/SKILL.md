---
name: laravel-blade-views
description: Usar siempre que se cree o modifique una vista Blade en Laravel — evita JS/CSS inline y lógica compleja en la vista.
---

# Estilo de frontend y vistas (Blade)

## Reglas
- Las vistas Blade no deben contener etiquetas `<script>` o `<style>` inline.
- Toda lógica JavaScript de frontend debe residir en archivos estáticos dedicados bajo `public/assets/js/scripts/pages/` e inyectarse en la vista mediante `@push('scripts')`.
- Las vistas Blade deben limitarse a renderizar información: prohibido escribir lógica de negocio, cálculos o condicionales complejos dentro del archivo Blade.
- Encapsular esas evaluaciones en Accessors y Mutators del modelo, o delegarlas a ViewModels/DTOs, de modo que la vista reciba los datos ya listos y formateados.

## Checklist rápido
- ¿Hay `<script>` o `<style>` inline en la vista tocada?
- ¿Hay un `@if` con lógica de negocio (no solo presentación) o un cálculo hecho directamente en el Blade?
