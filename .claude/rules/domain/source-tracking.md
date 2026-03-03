# Source Tracking — Trazabilidad de Fuentes

> Cada output de Savia cita las fuentes que consultó.
> Inspirado en NotebookLM: source management para prevenir alucinaciones.

---

## Principio

Cuando Savia genera un output que depende de reglas, skills o docs
del workspace, DEBE citar las fuentes. Esto:

1. Previene alucinaciones (el usuario verifica contra la fuente)
2. Aumenta confianza (trazabilidad completa)
3. Facilita debugging (saber qué regla causó un comportamiento)

---

## Tipos de Fuente

| Tipo | Prefijo | Ejemplo |
|---|---|---|
| Rule | `rule:` | `rule:aepd-framework.md` |
| Skill | `skill:` | `skill:regulatory-compliance/SKILL.md` |
| Doc | `doc:` | `doc:best-practices-claude-code.md` |
| Agent | `agent:` | `agent:architect.md` |
| Command | `cmd:` | `cmd:governance-audit.md` |
| External | `ext:` | `ext:aepd.es (orientaciones IA)` |

---

## Formato de Citación

### Inline (en respuesta)

```markdown
Según las orientaciones AEPD [rule:aepd-framework.md], los agentes
autónomos requieren EIPD antes del despliegue.
```

### Footer (al final del output)

```markdown
---
📚 Fuentes:
- rule:aepd-framework.md (Fase 2 — Análisis de Cumplimiento)
- skill:regulatory-compliance/SKILL.md (Framework de Compliance)
- cmd:governance-audit.md (Verificaciones AEPD)
```

### Compacto (para outputs largos)

```markdown
📚 3 rules · 1 skill · 2 docs → output/sources-20260303.md
```

---

## Cuándo Citar

| Contexto | Citar | Formato |
|---|---|---|
| Slash command | Siempre | Footer |
| Informe generado | Siempre | Footer + fichero |
| Respuesta a pregunta técnica | Si usa rules/skills | Inline |
| Conversación casual | No | — |
| Saludo / onboarding | No | — |

---

## Almacenamiento

Las citaciones se guardan en el output del comando:
- Inline en el fichero de reporte
- Resumen al final del fichero
- Log opcional en `output/sources/` para análisis posterior

---

## Integración con /context-optimize

El log de fuentes alimenta `/context-optimize`:
- Fuentes nunca citadas → candidatas a poda
- Fuentes citadas frecuentemente → candidatas a pre-carga
- Fuentes citadas juntas → candidatas a merge
