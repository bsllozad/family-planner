# F01 — Cuenta familiar y autenticación

**Estado:** Borrador

## F01-US01 — Iniciar sesión como adulto

Como padre quiero iniciar sesión con mi correo para administrar mi familia desde
cualquier dispositivo.

### Criterios de aceptación

- Dado un adulto registrado, cuando inicia sesión correctamente, entonces entra
  al dashboard de su familia.
- Dadas credenciales inválidas, cuando intenta ingresar, entonces ve un error
  claro sin revelar información sensible.
- Dada una sesión válida, cuando recarga la aplicación, entonces conserva la
  sesión de forma segura.

## F01-US02 — Invitar administradores

Como administrador quiero invitar a otros padres para compartir la gestión.

### Criterios de aceptación

- Dado un administrador, cuando invita un correo, entonces se crea una
  invitación limitada a su familia.
- Cuando el invitado acepta, obtiene los mismos permisos administrativos.
- Un administrador nunca puede ver ni modificar otra familia.

## F01-US03 — Iniciar sesión como niño

Como niño quiero ingresar con mi correo desde mi celular para ver mis propias
misiones.

### Criterios de aceptación

- Cuando Mathias o Nicolás inicia sesión, entra directamente en su perfil.
- Un niño no puede acceder a configuración administrativa.
- Un niño no puede consultar información privada de otra familia.

