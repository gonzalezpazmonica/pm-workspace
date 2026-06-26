# DOMAIN — write-a-skill

## Por que existe esta skill

Una skill creada sin estructura correcta (sin DOMAIN.md, sin frontmatter, excediendo 150 lineas)
falla el auditor y degrada el catalogo de skills. Esta skill fuerza el proceso correcto para
mantener el catalogo limpio y auditable.

## Conceptos de dominio

- **Skill**: unidad de instruccion reutilizable con SKILL.md y DOMAIN.md.
- **Frontmatter**: bloque YAML al inicio de SKILL.md con campos `name` y `description` obligatorios.
- **Auditor**: script en `scripts/skill-catalog-auditor.sh` que verifica 7 criterios de calidad.
- **Authoritative Paths**: seccion obligatoria en SKILL.md que lista ficheros a leer antes de actuar.
- **Patron reutilizable**: tarea que aparece 2 veces o mas, o que tarda mas de 15 minutos.

## Limites y no-objetivos

- No gestiona el ciclo de vida de skills existentes.
- No genera el contenido funcional de la skill — solo guia la estructura.
- No reemplaza la decision humana sobre si la skill debe existir.

## Confidencialidad

- Nivel: N1 (publico, versionado en el repositorio).
- Output: ficheros en `.claude/skills/` versionados normalmente.

## Referencias

- Spec origen: SE-085.
- Regla de template: `docs/rules/domain/skill-template-protocol.md`.
- Auditor: `scripts/skill-catalog-auditor.sh`.
