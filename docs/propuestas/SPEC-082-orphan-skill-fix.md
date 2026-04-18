---
spec_id: SPEC-082
title: Correccion del skill huerfano (DOMAIN.md sin SKILL.md)
status: Implemented
applied_at: "2026-04-18"
origin: Auditoria 2026-04-07 (M-002)
severity: Media
effort: 10 min
---

# SPEC-082: Correccion del skill huerfano

## Problema

Existen skills con DOMAIN.md pero sin su correspondiente SKILL.md (o viceversa).
Esto rompe la Clara Philosophy de documentacion dual obligatoria.

## Solucion

1. Listar todos los directorios en `.claude/skills/` con solo DOMAIN.md
2. Si falta SKILL.md: crear SKILL.md minimo con frontmatter
3. Si el directorio es invalido: eliminar DOMAIN.md huerfano
4. Validar con `/plugin-validate`

## Criterios de aceptacion

- [ ] Conteo SKILL.md == conteo DOMAIN.md
- [ ] `/plugin-validate` pasa sin warnings de orfandad
- [ ] Cada skill tiene ambos ficheros (SKILL.md + DOMAIN.md)
