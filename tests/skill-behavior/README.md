# tests/skill-behavior

Infraestructura de tests de comportamiento de skills — SE-147.

## Propósito

Verifica que cada skill en `.opencode/skills/*/SKILL.md` cumple los requisitos estructurales mínimos **sin ejecutar un LLM**. Detecta problemas antes de que alguien los note manualmente.

## Checks implementados

| Check | Nivel | Regla |
|---|---|---|
| Archivo SKILL.md existe | FAIL | — |
| Líneas ≤ 150 | FAIL | Rule 11 |
| Al menos un `## ` heading | FAIL | estructura mínima |
| Frontmatter tiene `description:` | FAIL | frontmatter contract |
| Description no contiene palabras de proceso | WARN | SE-145 Description Trap |

> Las WARNs son no-bloqueantes. El script sale con código 0 si no hay FAILs.

## Ejecución

```bash
# Validator sobre todos los skills
bash tests/skill-behavior/skill-validator.sh

# Validator sobre un skill concreto
bash tests/skill-behavior/skill-validator.sh --path .opencode/skills/caveman/SKILL.md

# Suite BATS completa
bats tests/skill-behavior/skill-validator.bats
```

## Archivos

```
tests/skill-behavior/
├── README.md                 # Este fichero
├── skill-validator.sh        # Script principal (BATS-compatible via --path)
├── skill-validator.bats      # Suite BATS (5 tests)
└── fixtures/
    ├── valid-skill.md        # Skill correctamente formado (test positivo)
    └── invalid-skill.md      # Skill con Description Trap (test negativo)
```

## Description Trap (SE-145)

La descripción de un skill debe responder "¿CUÁNDO invocarlo?" no "¿QUÉ hace internamente?".

**Palabras de alerta** (WARN): `pipeline`, `workflow`, `executes`, `runs`, `generates`, `produces`.

Estas palabras son WARNs (no FAILs) porque algunos skills del repo las usan en contexto no-trap (p.ej. describiendo lo que el skill *evita* hacer, o en un nombre propio).

## Estado actual del repo

Ejecuta `bash tests/skill-behavior/skill-validator.sh` para ver el estado actual.
Los skills con WARNs de Description Trap son candidatos a revisión en SE-145.

## Referencias

- SE-147: skill-behavior testing infrastructure
- SE-145: Description Trap fix
- Rule 11: 150 líneas máximo por fichero `.opencode/`
