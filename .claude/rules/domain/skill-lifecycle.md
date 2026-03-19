# Regla: Ciclo de Vida de Skills

> Inspirado en Everything Claude Code: continuous learning loop con 100+ skills.

## Fases

### 1. Propuesta

- Usuario describe workflow repetitivo (3+ ocurrencias)
- `/skill-propose {nombre}` genera scaffold automaticamente
- SKILL.md + DOMAIN.md con frontmatter, estructura y seccion de ejemplo

### 2. Validacion

- Consensus panel (reflection-validator + code-reviewer + business-analyst)
- Score >= 0.75: aprobado para adopcion
- Score < 0.75: sugerir refinamiento, no rechazar

### 3. Adopcion

- Skill entra al catalogo activo
- Registrado en `skill-evaluation` registry
- Maturity: `experimental`

### 4. Maduracion

Basada en uso + ratings (doc-quality-feedback):

- **experimental**: recien creado, < 10 usos
- **beta**: 10+ usos, rating > 50% clear
- **stable**: 50+ usos, rating > 70% clear, 0 critical issues

### 5. Archivado

Candidato a archival si:
- Sin uso durante 90+ dias
- Rating < 30% clear (mayoria negativa)
- Reemplazado por otro skill mas completo

Proceso:
1. `/hub-audit` detecta skill candidato
2. Savia sugiere archival al PM
3. Si PM confirma: mover a `.claude/skills/_archived/{nombre}/`
4. Si PM rechaza: mantener con nota "reviewed, kept"

## Metricas

- Skills creados por sprint
- Tasa de adopcion (propuestos vs adoptados)
- Rating promedio por maturity level
- Skills archivados vs activos

## Integracion

- **skill-auto-activation**: prioriza skills `stable` sobre `experimental`
- **skill-optimize**: prioriza skills `beta` con ratings bajos
- **hub-audit**: detecta skills candidatos a archival
- **/help**: muestra maturity badge junto a cada skill
