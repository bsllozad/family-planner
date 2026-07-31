# Kinquest — Family Planner

Aplicación familiar para convertir hábitos cotidianos en misiones. Esta versión implementa **F01: cuenta familiar y autenticación** con React, TypeScript y Supabase.

## Desarrollo local

1. Instala las dependencias con `npm install`.
2. Copia `.env.example` a `.env.local` y configura la URL y la clave anónima de Supabase.
3. Vincula el proyecto con Supabase CLI y aplica `supabase db push`, o pega la migración de `supabase/migrations` en el editor SQL.
4. Ejecuta `npm run dev`.

En Supabase Auth habilita correo/contraseña y, si usarás enlaces mágicos, agrega la URL local y la URL de producción a **Redirect URLs**.

## F01 incluido

- Registro, ingreso con contraseña y enlace mágico.
- Sesión persistente y restauración segura mediante Supabase Auth.
- Creación atómica de familia y primer administrador.
- Invitaciones de administrador de un solo uso, ligadas al correo y con caducidad de siete días.
- Entrada directa al perfil asociado, tanto para adultos como para niños.
- Protección de rutas administrativas en la interfaz y aislamiento en PostgreSQL mediante RLS.
- Mensajes de autenticación genéricos que no revelan si una cuenta existe.

El envío automático de invitaciones requiere configurar un proveedor de correo o una Edge Function. Mientras tanto, el administrador puede copiar el enlace seguro creado por la aplicación.

## Verificación

```sh
npm test
npm run build
```

La migración es la frontera de seguridad real: ocultar controles en React mejora la experiencia, pero los permisos se aplican en Supabase.
