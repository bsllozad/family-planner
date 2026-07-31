# Arquitectura y PWA

**Estado:** Borrador

## Stack recomendado

- React + Vite + TypeScript.
- React Router.
- Tailwind CSS.
- TanStack Query para estado remoto y caché.
- Supabase para PostgreSQL, Auth, Storage y funciones protegidas.
- Zod para validación compartida.
- Sistema de internacionalización para español e inglés.
- Vitest + Testing Library; Playwright para recorridos críticos.
- Vite PWA para manifest, service worker y experiencia instalable.
- Vercel para previews y producción.

## Backend

No se creará un servidor Node persistente en el MVP. El cliente accederá a
Supabase bajo RLS. Las operaciones sensibles —completar o revertir misiones,
conceder XP y canjear recompensas— usarán funciones SQL o Edge Functions
transaccionales.

Esto reduce infraestructura sin poner reglas críticas en el navegador.

## PWA

- `PWA-001`: Manifest con nombre, iconos, colores y modo standalone.
- `PWA-002`: Shell de aplicación disponible sin conexión.
- `PWA-003`: Lectura offline de la última información sincronizada.
- `PWA-004`: Acciones que modifican XP requieren conexión en el MVP.
- `PWA-005`: Mostrar claramente estado offline y errores de sincronización.
- `PWA-006`: Cumplir criterios instalables en navegadores compatibles.

## Despliegue

- Repositorio personal de GitHub.
- Integración GitHub–Vercel con preview por pull request.
- Variables públicas y secretos separados por ambiente.
- Migraciones de Supabase versionadas en el repositorio.
- Ambientes recomendados: local, preview/staging y producción.
