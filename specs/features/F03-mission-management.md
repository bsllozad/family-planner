# F03 — Administración de misiones

**Estado:** Borrador

## F03-US01 — Crear una misión

Como padre quiero crear una misión para asignar una responsabilidad y su XP.

### Criterios de aceptación

- Se puede definir título bilingüe, descripción, icono, categoría y XP.
- Se puede asignar a uno, varios o todos los niños.
- Se debe indicar si la misión es obligatoria u opcional.
- El XP debe ser un entero positivo dentro de límites configurados.

## F03-US02 — Programar recurrencia

Como padre quiero programar misiones para no recrearlas manualmente.

### Criterios de aceptación

- Una misión puede ser única, diaria o semanal.
- Una misión semanal puede ocurrir en días específicos.
- Una misión semanal flexible puede completarse una vez antes del cierre del
  domingo.
- Las instancias usan la zona horaria de la familia.

## F03-US03 — Editar y archivar

Como padre quiero modificar o retirar una misión sin perder el historial.

### Criterios de aceptación

- Los cambios futuros no alteran el XP histórico.
- Archivar impide crear nuevas instancias.
- Las instancias pasadas permanecen consultables.

## F03-US04 — Corregir o justificar

Como padre quiero corregir una finalización o justificar una misión para manejar
errores y excepciones.

### Criterios de aceptación

- Revertir una misión retira exactamente el XP que concedió.
- La corrección crea un movimiento auditable.
- Justificar una misión evita penalización y no concede XP.
- Solo un administrador puede realizar estas acciones.

