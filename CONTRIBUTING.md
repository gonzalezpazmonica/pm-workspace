# Contribuir a PM-Workspace

Soy Savia, y me encanta que quieras contribuir. Crezco con el uso real: las mejores contribuciones vienen de gente que encontro algo que le faltaba mientras gestionaba un proyecto de verdad.

Antes de empezar, lee este documento y el [Codigo de Conducta](CODE_OF_CONDUCT.md).

---

## Que busco

Las contribuciones de mayor impacto son:

**Nuevos comandos** (`.claude/commands/`) — si tuviste una conversacion conmigo que resolvio un problema PM que aun no cubro, empaquetalo como comando reutilizable. Mira el [ROADMAP.md](docs/ROADMAP.md) para ver que falta.

**Nuevos skills** (`.claude/skills/`) — skills que me extiendan a nuevo territorio: integracion Jira, metodologias SAFe/Kanban, o nuevos formatos de reporting.

**Tests** — nuevas suites en `tests/`, escenarios de mock, ejemplos de specs.

**Bug fixes** — correcciones en scripts, hooks, o agentes.

**Documentacion** — clarificaciones, ejemplos, traducciones. Ahora mismo hablo 9 idiomas.

---

## Quick start

```bash
git clone https://github.com/YOUR-USERNAME/pm-workspace.git
cd pm-workspace
git checkout -b feature/tu-feature
# Haz tus cambios
bash tests/run-all.sh                # Toda la suite debe pasar
bash scripts/validate-ci-local.sh    # CI local
# Abre Pull Request contra main
```

---

## Ramas

| Prefijo | Uso |
|---------|-----|
| `feature/` | Nuevo comando, skill, integracion |
| `fix/` | Correccion de bug |
| `docs/` | Solo documentacion |
| `test/` | Suite de tests o mock data |
| `refactor/` | Reestructuracion sin cambio de comportamiento |

---

## Estandares para comandos y skills

### Comandos (`.claude/commands/*.md`)

Cada comando nuevo necesita: descripcion, pasos numerados, manejo del error mas comun, al menos un ejemplo, y referencia a skills que usa.

### Skills (`.claude/skills/*/SKILL.md`)

Cada skill necesita: SKILL.md + DOMAIN.md (Clara Philosophy). Descripcion, cuando usarlo, parametros, limitaciones.

---

## Testing

```bash
bash tests/run-all.sh              # Suite completa
bats tests/structure/test-X.bats   # Suite individual
```

Mi CI ejecuta estos mismos comandos en cada PR. No mergeo si la suite regresa.

---

## Pull Requests

Usa la plantilla de `.github/pull_request_template.md`. Rellena todas las secciones.

**Proceso:** un maintainer revisa en 7 dias. Espera feedback e iteracion — es normal, no es rechazo. Una vez aprobado, se mergea en la siguiente release.

---

## Issues

Usa las plantillas de GitHub (Bug report o Feature request). Incluye: version de Claude Code, comando o skill involucrado, que esperabas y que paso.

---

## Lo que no acepto

- Credenciales, PATs, URLs de organizacion, o datos reales de proyecto
- Cambios que rompen la suite de tests sin razon documentada
- Comandos que duplican funcionalidad existente sin mejorarla
- Contribuciones generadas por IA sin testing manual real

---

## Reconocimiento

Cada contributor aparece en [CONTRIBUTORS.md](CONTRIBUTORS.md). Los first-timers se destacan en las release notes.
