---
globs: [".claude/commands/**", ".claude/agents/**", ".claude/skills/**", "docs/rules/**"]
---

# Regla: Limite de 150 lineas — Solo configuracion del workspace

Aplica UNICAMENTE a ficheros .md de configuracion de pm-workspace. NO aplica a codigo fuente de aplicaciones.

## Alcance (donde SI aplica)

- `.claude/commands/*.md` — comandos slash
- `docs/rules/**/*.md` — reglas de dominio y lenguaje
- `.claude/skills/**/SKILL.md` — skills
- `.claude/agents/*.md` — agentes
- `CLAUDE.md` — raiz y por proyecto

## Donde NO aplica

Codigo fuente de aplicaciones: `*.rs`, `*.ts`, `*.vue`, `*.py`, `*.go`, `*.java`, `*.sh`, `*.json`, `*.toml`, `*.yaml`, `*.css`. Ni tests, ni configs de build, ni scripts. El codigo fuente sigue metricas de su language pack (complejidad ciclomatica, longitud de metodo), no el limite de 150 lineas.

## Causa raiz de este cambio

La regla original decia "aplicable a cada fichero". Esto causaba que Claude recortara codigo fuente de aplicaciones (Rust, Vue, TypeScript) a 150 lineas, eliminando funcionalidad implementada (botones, tests, modulos enteros). El alcance correcto siempre fue ficheros de configuracion del workspace, no codigo de aplicaciones.

## Verificacion

`agent-hook-premerge.sh` ya filtra correctamente por `.claude/commands|rules|agents|skills`. `compliance-gate.sh` solo verifica en git commit. Ambos hooks son coherentes con esta regla.
