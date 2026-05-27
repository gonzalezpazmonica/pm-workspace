# Spec: SE-147 — Skill Behavior Testing Infrastructure

**Task ID:**        SE-147
**Sprint:**         2026-21
**Fecha creación:** 2026-05-26
**Creado por:**     Savia (agente de implementación)

**Developer Type:** agent-single
**Asignado a:**     claude-agent
**Estimación:**     2h
**Estado:**         APPROVED

---

## Problema

Savia no tiene ningún test que verifique que los skills están bien formados. Si un skill
viola Rule 11 (>150 líneas), pierde su frontmatter, o cae en el Description Trap (SE-145),
nadie lo detecta hasta que alguien lo nota manualmente. La brecha viene de obra/superpowers
que tiene `tests/skill-triggering/` para verificar disparos desde prompts naturales.

## Solución

Infraestructura de tests de comportamiento de skills en `tests/skill-behavior/` que valida
estructura y contenido sin ejecutar LLM.

## Acceptance Criteria

- AC-1: `bash tests/skill-behavior/skill-validator.sh` ejecuta sin errores y valida todos los skills en `.opencode/skills/*/SKILL.md`
- AC-2: El validator comprueba: existencia del archivo, líneas ≤ 150 (Rule 11), al menos un `##` heading, `description:` en frontmatter, ausencia de Description Trap words
- AC-3: Description Trap produce WARN (no FAIL) — evita falsos positivos en repo actual
- AC-4: `bats tests/skill-behavior/skill-validator.bats` ejecuta 5 tests y todos pasan
- AC-5: Fixtures `valid-skill.md` e `invalid-skill.md` demuestran casos positivo y negativo
- AC-6: Todos los skills actuales del repo pasan (exit 0) — WARNs documentados

## Estructura generada

```
tests/skill-behavior/
├── README.md
├── skill-validator.sh        # Script principal, BATS-compatible via --path
├── skill-validator.bats      # 5 tests BATS
└── fixtures/
    ├── valid-skill.md
    └── invalid-skill.md
```

## Notas de implementación

- Las palabras de alerta (Description Trap): `pipeline|workflow|executes|runs|generates|produces`
- 7 skills del repo tienen WARNs de Description Trap — son candidatos a revisión en SE-145
- 98 skills validados, 0 FAILs, exit 0
- BATS disponible en `/home/monica/.local/bin/bats`

## Referencias

- SE-145: Description Trap fix
- Rule 11: 150 líneas máximo
- obra/superpowers: `tests/skill-triggering/` (inspiración)
