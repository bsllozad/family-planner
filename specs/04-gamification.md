# XP, niveles, rachas e insignias

**Estado:** Borrador

## XP

- `GAM-001`: Cada misión guarda el XP concedido al completarse.
- `GAM-002`: El perfil muestra XP disponible y XP histórico.
- `GAM-003`: Canjear recompensas reduce el XP disponible, no el histórico.
- `GAM-004`: Todo cambio de XP crea un movimiento auditable.

## Niveles

- `GAM-005`: El nivel se calcula con XP histórico y no disminuye al canjear.
- `GAM-006`: El sistema muestra progreso hacia el siguiente nivel.
- `GAM-013`: Los niveles iniciales son Rookie, Explorer, Hero y Champion.
- `GAM-014`: Alcanzar un nivel puede desbloquear insignias, recompensas y
  elementos de avatar.

| Nivel | Nombre | XP histórico requerido |
|---|---|---:|
| 1 | Rookie | 0 XP |
| 2 | Explorer | 500 XP |
| 3 | Hero | 1.500 XP |
| 4 | Champion | 3.500 XP |

Estos umbrales se evaluarán después de las primeras semanas de uso para
comprobar que sean alcanzables con el volumen real de tareas.

## Rachas

- `GAM-007`: Un día cuenta para la racha cuando el niño completa todas las
  misiones obligatorias de ese día.
- `GAM-008`: Las misiones opcionales no afectan la racha.
- `GAM-009`: Los días sin misiones no rompen la racha.

## Insignias

- `GAM-010`: Las insignias se desbloquean automáticamente por hitos.
- Primera colección propuesta: primera misión, 7 días de racha, 100 XP, 500 XP,
  1.000 XP y todas las misiones de una semana.

## Ranking

- `GAM-011`: El ranking compara un periodo, no el XP acumulado de por vida.
- `GAM-012`: El padre puede desactivarlo para evitar competencia negativa.

## Avatar evolutivo

- `GAM-015`: Cada niño tiene un avatar asociado a su perfil.
- `GAM-016`: El avatar comienza con un personaje básico.
- `GAM-017`: Los niveles e insignias desbloquean ropa, mascotas, fondos y
  accesorios.
- `GAM-018`: Los desbloqueables son permanentes aunque se gasten los XP.
- `GAM-019`: El niño puede equipar los elementos que haya desbloqueado.
- `GAM-020`: Las penalizaciones reducen el XP disponible, pero nunca el XP
  histórico, el nivel, las insignias ni los elementos desbloqueados.

Para el MVP se utilizará un catálogo cerrado de elementos predefinidos.
