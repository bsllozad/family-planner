# Recompensas

**Estado:** Borrador

## Requisitos

- `REW-001`: El padre puede crear título, descripción, icono, costo en XP y
  disponibilidad.
- `REW-002`: Puede limitar una recompensa a uno o varios niños.
- `REW-003`: El niño puede solicitar una recompensa si tiene XP suficiente.
- `REW-004`: La solicitud descuenta XP disponible de forma atómica.
- `REW-005`: El padre puede aprobar, entregar, rechazar o cancelar el canje.
- `REW-006`: Rechazar o cancelar devuelve los XP cuando corresponda.
- `REW-007`: El historial de canjes no se elimina.

## Catálogo inicial de ejemplo

- 100 XP: 30 minutos de Nintendo.
- 300 XP: elegir la película del viernes.
- 500 XP: salida a tomar helado.
- 1.000 XP: premio especial.

## Estados propuestos

`requested` → `approved` → `fulfilled`

También: `requested` → `rejected` o `cancelled`.

## Conversión semanal a dinero

Cada viernes, el niño puede solicitar convertir XP disponible a dólares
canadienses.

- `REW-008`: La tasa inicial es 35 XP = CAD $1.
- `REW-009`: El canje mínimo es 175 XP = CAD $5.
- `REW-010`: El máximo es 700 XP = CAD $20 por niño por semana.
- `REW-011`: La solicitud requiere aprobación y confirmación de pago de un
  administrador.
- `REW-012`: Los XP se descuentan al crear la solicitud y se devuelven si esta
  se rechaza o cancela.
- `REW-013`: El sistema registra importe, tasa aplicada, fecha, administrador y
  estado del pago.
- `REW-014`: La familia puede desactivar temporalmente el canje en efectivo.

La conversión nunca reduce el XP histórico ni el nivel.

La tasa y los límites serán preferencias configurables más adelante; para el
MVP se utilizarán los valores familiares anteriores.

## Proyección semanal

Con una referencia de 50 XP ganados por día:

- 350 XP por semana = CAD $10.
- 175 XP = canje mínimo de CAD $5.
- 700 XP = máximo semanal de CAD $20.

El valor monetario se calcula únicamente con XP disponible. Las penalizaciones
y los canjes no reducen el XP histórico utilizado para niveles.
