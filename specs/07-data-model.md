# Modelo de datos

**Estado:** Borrador

## Entidades principales

| Entidad | Propósito |
|---|---|
| `families` | Familia, zona horaria y preferencias |
| `profiles` | Adultos y niños pertenecientes a la familia |
| `family_members` | Relación entre usuarios autenticados y familia |
| `mission_templates` | Definición reutilizable de una misión |
| `mission_assignees` | Niños asignados a cada plantilla |
| `mission_instances` | Misión concreta por niño y fecha |
| `xp_transactions` | Libro mayor inmutable de XP |
| `rewards` | Catálogo familiar de recompensas |
| `reward_redemptions` | Solicitudes y entrega de recompensas |
| `cash_redemptions` | Conversión semanal de XP a dinero |
| `badges` | Catálogo de insignias |
| `profile_badges` | Insignias desbloqueadas |
| `avatar_items` | Catálogo de ropa, mascotas, fondos y accesorios |
| `profile_avatar_items` | Elementos desbloqueados por cada niño |
| `profile_avatar_loadouts` | Elementos actualmente equipados |

## Decisiones de integridad

- IDs UUID.
- Fechas almacenadas en UTC; cálculo diario usando la zona horaria familiar.
- Borrado lógico para plantillas, perfiles y recompensas con historial.
- `xp_transactions` es la fuente de verdad del saldo.
- Restricciones únicas evitan XP duplicado por una misma instancia.
- Restricciones únicas evitan más de una penalización semanal por instancia.
- Todas las tablas familiares incluyen `family_id` para aplicar RLS.
- Un usuario autenticado puede estar asociado con un perfil adulto o infantil.

## Campos clave de una instancia

- `mission_template_id`
- `profile_id`
- `scheduled_for`
- `status`
- `xp_value`
- `xp_awarded`
- `penalty_xp`
- `penalty_applied_at`
- `is_excused`
- `completed_at`
- `reviewed_at`
- `reviewed_by`

El esquema SQL definitivo se creará al aprobar las reglas funcionales.
