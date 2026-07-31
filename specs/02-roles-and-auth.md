# Roles y autenticación

**Estado:** Borrador

## Roles

### Padre o tutor

- `AUTH-001`: Crear y administrar la familia.
- `AUTH-002`: Invitar a otro administrador.
- `AUTH-003`: Crear y editar perfiles infantiles.
- `AUTH-004`: Administrar misiones, XP, recompensas y canjes.
- `AUTH-005`: Ver información de todos los miembros de su familia.

### Niño

- `AUTH-006`: Ver únicamente su experiencia y la información familiar
  permitida.
- `AUTH-007`: Completar misiones y solicitar recompensas.
- `AUTH-008`: No modificar XP, reglas, recompensas ni otros perfiles.
- `AUTH-012`: Iniciar sesión desde su propio dispositivo mediante su correo.

## Formas de acceso

- Padres: Supabase Auth con correo y enlace mágico o contraseña.
- Niños en su celular: cuenta de Supabase Auth asociada con su correo y perfil.
- Dispositivo compartido: un padre inicia sesión y selecciona el perfil activo
  desde un dropdown.

## Cambio de perfil en sesión compartida

- `AUTH-013`: El padre puede cambiar entre su dashboard y un perfil infantil
  desde un selector.
- `AUTH-014`: El modo infantil oculta las acciones administrativas.
- `AUTH-015`: Para regresar al modo padre o realizar una acción administrativa
  se requiere un PIN de adulto de 4–6 dígitos.

- `AUTH-016`: El PIN se almacena únicamente como hash seguro.
- `AUTH-017`: Después de varios intentos incorrectos se bloquea temporalmente el
  regreso al modo administrativo.

El simple dropdown no se considera una barrera de seguridad suficiente.

## Seguridad

- `AUTH-009`: Toda fila de negocio pertenece a una familia.
- `AUTH-010`: Las políticas de base de datos impiden acceso entre familias.
- `AUTH-011`: Las operaciones que conceden o descuentan XP son atómicas y se
  ejecutan del lado servidor.
