# F04 — Misiones del niño

**Estado:** Borrador

## F04-US01 — Ver misiones

Como niño quiero ver claramente qué debo hacer hoy para organizarme.

### Criterios de aceptación

- Las misiones obligatorias aparecen antes que las opcionales.
- Cada misión muestra icono, título, XP disponible y estado.
- Las misiones atrasadas se identifican y muestran su XP reducido.
- Una misión semanal flexible muestra su fecha límite.

## F04-US02 — Completar una misión

Como niño quiero marcar una misión terminada para ganar XP inmediatamente.

### Criterios de aceptación

- Una acción clara permite completar una misión pendiente.
- La operación concede XP exactamente una vez.
- Una segunda solicitud o doble toque no duplica XP.
- La interfaz actualiza saldo, progreso y celebración.

## F04-US03 — Acumular misiones atrasadas

Como niño quiero completar misiones atrasadas aunque valgan menos XP.

### Criterios de aceptación

- Una misión de día fijo concede 100% el día correcto, 50% tarde durante esa
  semana y 25% después del cierre semanal.
- Una misión semanal flexible concede 100% durante la semana y 25% después.
- Al cerrar el domingo a las 23:59, una misión obligatoria pendiente descuenta
  una sola vez el 25% de su valor original.
- Una misión opcional nunca genera penalización.
- El saldo disponible nunca queda debajo de cero.

