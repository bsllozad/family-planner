# F06 — Recompensas y canjes

**Estado:** Borrador

## F06-US01 — Administrar recompensas

Como padre quiero crear recompensas para motivar a los niños.

### Criterios de aceptación

- Se puede definir título bilingüe, descripción, icono, costo y disponibilidad.
- Se puede limitar una recompensa a determinados niños.
- Archivar una recompensa conserva su historial.

## F06-US02 — Solicitar una recompensa

Como niño quiero gastar XP en una recompensa que pueda pagar.

### Criterios de aceptación

- La solicitud solo se crea si existe saldo suficiente.
- El costo se descuenta de forma atómica.
- El padre puede aprobar, rechazar, entregar o cancelar.
- Rechazar o cancelar devuelve exactamente el XP descontado.

## F06-US03 — Cambiar XP por dinero

Como niño quiero cambiar parte de mi XP por dinero los viernes.

### Criterios de aceptación

- La conversión está disponible los viernes en la zona horaria familiar.
- 35 XP equivalen a CAD $1.
- El mínimo es 175 XP = CAD $5.
- El máximo es 700 XP = CAD $20 por niño por semana.
- Un administrador debe aprobar y confirmar el pago.
- Rechazar o cancelar devuelve el XP reservado.
- El canje no reduce XP histórico, nivel ni desbloqueables.

