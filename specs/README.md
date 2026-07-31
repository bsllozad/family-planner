# Especificaciones

Estos documentos son la fuente de verdad funcional y técnica del proyecto.
Cada requisito usa un identificador para poder relacionarlo con historias,
implementación y pruebas.

## Documentos

1. [Visión y principios](./00-vision.md)
2. [Alcance del MVP](./01-mvp-scope.md)
3. [Roles y autenticación](./02-roles-and-auth.md)
4. [Misiones](./03-missions.md)
5. [XP, niveles, rachas e insignias](./04-gamification.md)
6. [Recompensas](./05-rewards.md)
7. [Dashboard y calendario](./06-dashboard.md)
8. [Modelo de datos](./07-data-model.md)
9. [Arquitectura y PWA](./08-architecture.md)
10. [Roadmap](./09-roadmap.md)
11. [Decisiones abiertas](./10-open-decisions.md)
12. [Features e historias de usuario](./features/README.md)

## Estados

- `Borrador`: requiere revisión.
- `Aprobado`: listo para implementar.
- `Implementado`: construido y verificado.

Todos los documentos comienzan como `Borrador`.

## Implementación por feature

La carpeta [`features/`](./features/README.md) divide el producto en historias
de usuario con criterios de aceptación verificables. Los requisitos funcionales
explican qué debe hacer el sistema; los archivos de features definen entregables
que se pueden construir y probar uno por uno.
