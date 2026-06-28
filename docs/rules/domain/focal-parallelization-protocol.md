---
context_tier: L2
token_budget: 600
---

# Focal Parallelization Protocol (SE-230)

> Soporte cognitivo para directores de múltiples Savias en paralelo.

## Problema central

Dirigir 2-4 Savias en paralelo no es multitasking — es time-slicing con coste
de conmutación del 20-40% por cambio (Rubinstein et al. 2001). Este protocolo
reduce ese coste sin impedir el trabajo paralelo.

## Reglas de uso

### 1. Siempre focal-switch antes de cambiar de nido activo

```bash
bash scripts/focal-switch.sh --from <nido-actual> --to <nido-destino>
```

El off-load explícito es obligatorio. Libera working memory activa y registra
el switch en `.switch-log` para medir carga cognitiva.

Alternativa cuando solo guardas sin cambiar:
```bash
bash scripts/focal-switch.sh --save-only --nido <nombre> --task "desc"
```

### 2. Interpretar STALE

Un nido es **STALE** cuando `updated_at` supera `2 × check_in_interval_min` sin
heartbeat. Puede significar: proceso muerto, terminal cerrada, o Savia bloqueada.

Acciones ante STALE:
- Abrir terminal en el nido y verificar estado
- Si proceso muerto: `focal-switch.sh --save-only --nido <n> --task "verificar"`
- Si sigue activo: `focal-checkin.sh --nido <n>` para actualizar timestamp

### 3. BLOCKING vs URGENT

| Campo | Definición | Acción requerida |
|-------|-----------|-----------------|
| `blocking: true` | Savia no puede avanzar ningún slice | Respuesta antes del próximo check-in |
| `urgency: 2-3` | Ventana temporal acotada; retraso tiene coste | Respuesta antes del check-in siguiente |
| `urgency: 0-1` | Informativo | Puede esperar al próximo ciclo de atención |

Un nido puede tener urgency alto sin blocking (Savia avanza en otra rama mientras espera).

### 4. Escala cognitive_cost (1-5)

La Savia del nido asigna este valor al generar `next_human_decision`:

| Valor | Descripción | Ejemplo |
|-------|-------------|---------|
| 1 | Confirmación mecánica | Merge con CI 9/9 verde |
| 2 | Revisión rápida | Diff < 50 líneas, scope claro |
| 3 | Revisión profunda | Diff > 50 líneas, o múltiples ficheros |
| 4 | Decisión de diseño sin precedente | Nuevo patrón sin spec anterior |
| 5 | Decisión arquitectónica cross-nido | Impacta otros nidos o el repo principal |

**Default**: 2 si la Savia no especifica.

### 5. Señal LOAD

`focal-checkin.sh --load` devuelve:

| Señal | Condición |
|-------|----------|
| `OK` | ≤2 switches/hora Y <3 decisiones pendientes |
| `HIGH` | 3-5 switches/hora O 3-5 decisiones pendientes |
| `OVERLOAD` | >5 switches/hora O >5 decisiones pendientes |

OVERLOAD es una señal — no bloquea. El director puede continuar; el sistema
dobla los intervalos de check-in de nidos no-BLOCKING para reducir interrupciones.

## Herramientas

| Script | Uso |
|--------|-----|
| `focal-status.sh` | Vista agregada de todos los nidos |
| `focal-status.sh --summary` | Una línea para el banner de sesión |
| `focal-switch.sh --from A --to B` | Cambio de foco con off-load |
| `focal-dispatch.sh` | Decisión más crítica pendiente |
| `focal-dispatch.sh --all-blocking` | Todas las decisiones BLOCKING |
| `focal-checkin.sh --nido <n>` | Heartbeat de un nido |
| `focal-checkin.sh --load` | Señal de carga cognitiva actual |
| `focal-decisions-log.sh` | Registrar una decisión tomada |

## Estado por nido

Fichero: `~/.savia/focal-state/<nido>.json`
Gitignored. Local. Solo el director lo escribe (via focal-switch o focal-checkin).

Valores de `status`: `active`, `paused`, `waiting`, `done`, `abandoned`, `stale`
