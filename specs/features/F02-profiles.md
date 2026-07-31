# F02 — Perfiles y modo compartido

**Estado:** Borrador

## F02-US01 — Administrar perfiles infantiles

Como padre quiero crear y editar perfiles para configurar la experiencia de
cada niño.

### Criterios de aceptación

- Se puede definir nombre, fecha de nacimiento, idioma y avatar inicial.
- El sistema funciona con más de dos perfiles infantiles.
- Archivar un perfil no elimina su historial de XP, misiones o canjes.

## F02-US02 — Seleccionar perfil compartido

Como familia quiero cambiar a un perfil infantil desde la sesión del padre para
usar la aplicación en una computadora compartida.

### Criterios de aceptación

- El dropdown muestra los perfiles activos de la familia.
- Al elegir un niño, la interfaz cambia a modo infantil y muestra únicamente su
  contenido.
- Cambiar entre perfiles infantiles no concede permisos administrativos.
- Para regresar al modo administrador se exige el PIN adulto.

## F02-US03 — Proteger el modo administrador

Como padre quiero proteger el regreso al modo administrador para que los niños
no modifiquen reglas o puntos.

### Criterios de aceptación

- El PIN tiene entre 4 y 6 dígitos y se almacena como hash.
- Un PIN incorrecto no permite abandonar el modo infantil.
- Varios intentos incorrectos activan un bloqueo temporal.
- El PIN nunca aparece en logs ni respuestas del cliente.

