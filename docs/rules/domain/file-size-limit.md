---
globs: [".opencode/commands/**", ".opencode/agents/**", ".opencode/skills/**", "docs/rules/**"]
---

# Regla: Limite de 150 lineas — Solo configuracion del workspace

Aplica UNICAMENTE a ficheros .md de configuracion de pm-workspace. NO aplica a codigo fuente de aplicaciones.

## Alcance (donde SI aplica)

- `.opencode/commands/*.md` — comandos slash
- `docs/rules/**/*.md` — reglas de dominio y lenguaje
- `.opencode/skills/**/SKILL.md` — skills
- `.opencode/agents/*.md` — agentes
- `CLAUDE.md` — raiz y por proyecto

## Donde NO aplica

Codigo fuente de aplicaciones: `*.rs`, `*.ts`, `*.vue`, `*.py`, `*.go`, `*.java`, `*.sh`, `*.json`, `*.toml`, `*.yaml`, `*.css`. Ni tests, ni configs de build, ni scripts. El codigo fuente sigue metricas de su language pack (complejidad ciclomatica, longitud de metodo), no el limite de 150 lineas.

## Causa raiz de este cambio

La regla original decia "aplicable a cada fichero". Esto causaba que Claude recortara codigo fuente de aplicaciones (Rust, Vue, TypeScript) a 150 lineas, eliminando funcionalidad implementada (botones, tests, modulos enteros). El alcance correcto siempre fue ficheros de configuracion del workspace, no codigo de aplicaciones.

## Verificacion

`agent-hook-premerge.sh` ya filtra correctamente por `.claude/commands|rules|agents|skills`. `compliance-gate.sh` solo verifica en git commit. Ambos hooks son coherentes con esta regla.

## Excepciones documentadas

Documentos canonicos cuya naturaleza requiere unidad indivisible:

- `docs/rules/domain/savia-ethical-principles.md` (SE-104): manifiesto canonico con los 13 principios humanistas + 5 lineas rojas inmutables. Particionarlo rompe su funcion de unico punto de referencia citable desde reglas, agentes y dilemas. Excepcion validada en `tests/structure/test-workspace-structure.bats` test 9.

Toda nueva excepcion requiere: (1) justificacion documentada aqui, (2) entrada explicita en el test BATS, (3) aprobacion en review.
