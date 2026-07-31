# Misiones

**Estado:** Borrador

## Definición

Una plantilla de misión describe la actividad y su recurrencia. Una instancia
representa la misión concreta asignada a un niño en una fecha.

## Requisitos

- `MIS-001`: El padre puede crear título, descripción opcional, icono, XP y
  categoría.
- `MIS-002`: Puede asignar la misión a uno o varios niños.
- `MIS-003`: Puede definirla como única, diaria o semanal.
- `MIS-004`: Una misión semanal puede seleccionar días específicos o permitir
  que se complete en cualquier momento de la semana.
- `MIS-005`: Al marcar una misión como terminada se concede XP
  automáticamente.
- `MIS-006`: El niño ve primero las misiones correspondientes a hoy.
- `MIS-007`: El niño puede marcar una misión pendiente como completada.
- `MIS-008`: El padre puede revertir una finalización incorrecta desde el
  historial.
- `MIS-009`: Revertir retira exactamente el XP concedido por esa finalización y
  crea un movimiento auditable.
- `MIS-010`: Completar concede XP exactamente una vez.
- `MIS-011`: Una misión puede ser obligatoria u opcional.
- `MIS-012`: Archivar una plantilla no borra el historial.
- `MIS-013`: Una misión no completada permanece disponible como atrasada.
- `MIS-014`: La interfaz muestra claramente el XP actual que puede ganarse,
  incluyendo cualquier reducción por atraso.

## Estados

`pending` → `completed`

Una corrección administrativa devuelve `completed` → `pending` y registra
quién realizó el cambio.

## Reglas iniciales

- Una instancia solo puede conceder XP una vez.
- Cambiar el valor de una plantilla no altera el XP histórico.
- La zona horaria de la familia determina qué significa “hoy”.
- Las misiones opcionales conceden XP extra, pero no cuentan para conservar o
  perder la racha.
- Una misión semanal flexible permanece disponible hasta terminar la semana.

## Misiones atrasadas y penalizaciones

La zona horaria familiar determina el cierre de cada día. La semana termina el
domingo a las 23:59:59 en esa zona horaria.

### Misión con día específico

- Completada en la fecha programada: concede 100% del XP.
- Completada tarde, pero antes de terminar esa semana: concede 50% del XP.
- Sin completar al cierre de la semana: se conserva como atrasada, aplica una
  penalización y posteriormente concede 25% del XP si se completa.

### Misión semanal flexible

- Completada antes de terminar la semana: concede 100% del XP.
- Sin completar al cierre de la semana: se conserva como atrasada, aplica una
  penalización y posteriormente concede 25% del XP si se completa.

### Penalización al cerrar la semana

- La penalización es 25% del valor original de la misión, redondeada al entero
  más cercano.
- Solo se aplica una vez por instancia.
- Reduce el XP disponible, pero no el XP histórico ni el nivel.
- El saldo disponible nunca puede quedar por debajo de cero.
- Las misiones opcionales atrasadas no generan penalización.
- Un administrador puede justificar o perdonar una misión para evitar la
  penalización por enfermedad, viaje u otra excepción.

## Ejemplos de recurrencia

- Sacar la basura: todos los martes.
- Limpiar el cuarto: una vez en cualquier momento de la semana.
