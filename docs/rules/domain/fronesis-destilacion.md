---
context_tier: L2
token_budget: 800
---

# Regla: Destilación de fronemas (SE-344 · CRIT-001)

> Protocolo obligatorio antes de registrar cualquier fronema. La cúpula
> Frónesis (`vaults/Fronesia/`) solo contiene **versiones destiladas N2**.

## Principio

Sin consecuencia verificada no hay fronema. Y sin destilación no hay fronema
en la cúpula: **el caso completo vive en la cúpula del PROYECTO (N4) y jamás
sale de ahí**. Lo que entra en la cúpula de frónesis es la versión pública,
destilada, SIN datos identificativos.

**Prohibido** (CRIT-001): "anonimizar a mano y enviar fuera", truncar, o
trasladar cualquier dato N3+ del workspace. Nada N3+ sale del workspace bajo
ninguna forma. La destilación es un proceso LOCAL: se escribe el caso destilado
en la cúpula N2; el original N4 no se mueve ni se exporta.

## Checklist de destilación (antes de `fronema.py register`)

1. **Tensión**: principios válidos en conflicto (ej. `seguridad ↔ velocidad`).
2. **Prototipo** (≥1): señales de alerta (RPD), sin datos de proyecto.
3. **Deliberación** (≥1): preguntas que haría un senior.
4. **Decisión**: qué se decidió (genérica, sin nombres/cliente/proyecto).
5. **Razón**: qué principio ganó y por qué.
6. **Consecuencia**: `verificacion` (pending | T+30/90/180) + `resultado`.
7. **Límites**: cuándo NO aplica.
8. **Fuente**: origen (postmortem, gate, sesión) — SIN identificar persona.
9. **Nivel**: `N1` o `N2`. NUNCA N3/N4/N4b (el CLI lo bloquea).
10. **Dominio**: IDs L23 (el CLI valida).

## Uso

```bash
python3 scripts/fronema.py register --tension "rigor ↔ velocidad" \
  --decision "..." --razon "..." --limites "..." \
  --senal "s1" --pregunta "p1" --dominio SFT --fuente "..." \
  [--verificacion T+90 --resultado "..."]   # con consecuencia verificada -> verified
python3 scripts/fronema.py query --tension "seguridad" --dominio CYB  # gate de precedentes
python3 scripts/fronema.py train --dominio SFT --sesion s1            # loop de formación
```

Los agentes **traen precedentes; no deciden** (anti-goal): `query` es el gate
manual de frónesis.

## Referencias

- Spec: `docs/specs/SE-344-fronesis-como-codigo.spec.md`
- Cúpula: `vaults/Fronesia/` · `scripts/fronema.py` · CRIT-001
