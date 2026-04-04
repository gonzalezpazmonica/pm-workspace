# Workspace Consolidation

> Version: v4.9 | Era: 178 | Desde: 2026-04-04

## Que es

Auditoria de integridad que verifica que los contadores documentados en README, CHANGELOG y ROADMAP coinciden con el contenido real del repositorio. Detecta drift entre documentacion y codigo: comandos, agentes, skills, hooks, tests, modelos LLM.

## Requisitos

Preinstalado. Solo necesita acceso al repositorio.

## Uso basico

La consolidacion se ejecuta como parte del flujo de auditoria:

```bash
# El informe se genera en output/
ls output/20260404-workspace-consolidation.md
```

El informe cubre:
- Conteo real vs documentado de commands, agents, skills, hooks
- Inventario de test suites con puntuaciones
- Hooks huerfanos (registrados pero sin fichero, o viceversa)
- Modelos LLM instalados y su estado

## Que verifica

| Dimension | Fuente real | Fuente documentada |
|-----------|-------------|-------------------|
| Commands | `ls .claude/commands/*.md` | README "508 comandos" |
| Agents | `ls .claude/agents/*.md` | README "48 agentes" |
| Skills | `ls .claude/skills/*/SKILL.md` | README "89 skills" |
| Hooks | settings.json hook entries | README "48 hooks" |
| Tests | `ls tests/*.bats` | README "93 test suites" |

## Contadores actuales (v4.10)

- 508 commands
- 48 agents
- 89 skills (100% con DOMAIN.md)
- 48 hooks
- 93 test suites
- 16 language packs

## Cuando ejecutar

- Antes de cada release (verificar que README refleja la realidad)
- Despues de anadir o eliminar commands, skills, agents o hooks
- Como parte de la auditoria periodica del workspace
- Cuando se detectan inconsistencias entre documentacion y codigo

## Integracion

- **validate-ci-local.sh**: incluye verificacion basica de contadores
- **/hub-audit**: complementa con analisis semantico de conexiones entre reglas
- **CHANGELOG**: la entrada de cada version debe reflejar contadores correctos
- **README updates**: tras consolidar, actualizar los 9 READMEs si hay cambios

## Troubleshooting

**Contadores no coinciden**: ejecutar los conteos manualmente para identificar la fuente del drift:
```bash
ls .claude/commands/*.md | wc -l
ls .claude/agents/*.md | wc -l
ls -d .claude/skills/*/SKILL.md | wc -l
```

**Hooks huerfanos**: un hook puede estar registrado en settings.json pero su fichero `.sh` no existir (o viceversa). Revisar `.claude/settings.json` y `.claude/hooks/`

**Test suites nuevas sin registrar**: verificar que cada `.bats` nuevo esta referenciado en `tests/run-all.sh`
