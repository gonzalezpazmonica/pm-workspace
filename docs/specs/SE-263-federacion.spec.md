# Spec: SE-263 — Federacion de Savias (cupulas, git, A2A)

**Status:** PROPOSED
**Fecha:** 2026-07-11 (v3: agnostica de infraestructura)
**Area:** Federation / Context domes / Git substrate / A2A / Constitutional boundary
**Branch:** agent/se263-federacion
**Estimacion total:** ~49h (7 slices)
**Sustituye a:** SE-261-coordinacion v1

**Developer Type:** agent-team
**Asignado a:** claude-agent-team
**Estado:** Pendiente

**Effort Estimation (Dual Model):**
| Dimension | Value |
|-----------|-------|
| Agent effort | 49h (7 slices) |
| Human effort | 12h (revision por slice + decision de arquitectura) |
| Review effort | 8h |
| Context risk | high |
| Agent-capable | partial |
| Fallback | Si agente falla: humano necesita ~40h desde cero |

**OpenCode Implementation Plan:**
| Componente | Claude Code | OpenCode v1.14 |
|---|---|---|
| Git plane | repo de coordinacion + .gates/ CI | Portable a cualquier remoto (bash gates) |
| A2A server | Python SDK A2A oficial | Mismo SDK |
| Identity cards | instancia.card.json firmada | Mismo schema |
| Dome export | context-dome-generate --export | Mismo script |
| Atestacion | savia-attest con matriz federada | Misma herramienta |

**Portability classification:** DUAL_BINDING — git plane PURE_BASH, A2A plane Python SDK.

---

## Clarificaciones del operador (2026-07-11)

1. **S1 AC-1.2 (ratificacion constitucional):** en un modelo federado hay una PM
   coordinadora, como en cualquier proyecto. El equipo trabaja coordinado con
   una persona que es la PM coordinando la cooperacion. La extension
   constitucional se ratifica via PR al repo de coordinacion, con aprobacion
   de la PM de la federacion.

2. **S5 AC-5.1 (federacion de laboratorio):** 3 instancias sinteticas. Sin
   dependencia de una instancia "real" que no existiria en CI.

3. **S4 (config vs cards):** federation.config.yaml declara parametros de red
   (interfaz, backend de secretos, remoto git). Las instancia.card.json
   declaran endpoints (host:puerto en la red privada). Sin redundancia.

4. **S4 — Agent Index (nuevo):** indice de agentes federados en la cupula de
   contexto de la federacion (coordinacion/domes/_federation/agent-index.json),
   exponiendo direcciones de red, puertos, skills y nivel maximo por agente.
   Generado automaticamente desde las cards commiteadas. Es la fuente canonica
   de descubrimiento para que los agentes localicen a sus pares.

### Agent Index — Schema

```json
{
  "generated": "ISO8601",
  "federation": "nombre",
  "agents": {
    "<instancia_id>": {
      "card": "cards/<id>.card.json",
      "endpoint": "https://<host>:<port>",
      "principal": "<slug>",
      "skills": ["skill1", "skill2"],
      "max_level": 2
    }
  }
}
```

Reglas del Agent Index:
- Generado deterministicamente desde cards/*.card.json commiteadas.
- Se regenera en cada commit que toca cards/ (gate CI).
- Solo incluye instancias NO revocadas.
- Dos ejecuciones sobre el mismo estado -> cero diff.
- Ruta fija: domes/_federation/agent-index.json.
- Consumido por el cliente A2A para descubrimiento sin broker.
