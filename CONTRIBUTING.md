# Contribuir a PM-Workspace

Soy Savia, y me encanta que quieras contribuir. Crezco con el uso real: las mejores contribuciones vienen de gente que encontró algo que le faltaba mientras gestionaba un proyecto de verdad.

Antes de empezar, lee este documento y el [Código de Conducta](CODE_OF_CONDUCT.md).

---

## Qué busco

Las contribuciones de mayor impacto son:

**Nuevos comandos** (`.opencode/commands/`) — si tuviste una conversación conmigo que resolvió un problema PM que aún no cubro, empaquétalo como comando reutilizable. Mira el [ROADMAP.md](docs/ROADMAP.md) para ver qué falta.

**Nuevos skills** (`.opencode/skills/`) — skills que me extiendan a nuevo territorio: integración Jira, metodologías SAFe/Kanban, o nuevos formatos de reporting.

**Tests** — nuevas suites en `tests/`, escenarios de mock, ejemplos de specs.

**Bug fixes** — correcciones en scripts, hooks, o agentes.

**Documentación** — clarificaciones, ejemplos, traducciones. Ahora mismo hablo 9 idiomas.

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
| `feature/` | Nuevo comando, skill, integración |
| `fix/` | Corrección de bug |
| `docs/` | Solo documentación |
| `test/` | Suite de tests o mock data |
| `refactor/` | Reestructuración sin cambio de comportamiento |

---

## Estándares para comandos y skills

### Comandos (`.opencode/commands/*.md`)

Cada comando nuevo necesita: descripción, pasos numerados, manejo del error más común, al menos un ejemplo, y referencia a skills que usa.

### Skills (`.opencode/skills/*/SKILL.md`)

Cada skill necesita: SKILL.md + DOMAIN.md (Clara Philosophy). Descripción, cuándo usarlo, parámetros, limitaciones.

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

**Proceso:** un maintainer revisa en 7 días. Espera feedback e iteración — es normal, no es rechazo. Una vez aprobado, se mergea en la siguiente release.

---

## Issues

Usa las plantillas de GitHub (Bug report o Feature request). Incluye: versión de Claude Code, comando o skill involucrado, qué esperabas y qué pasó.

---

## Lo que no acepto

- Credenciales, PATs, URLs de organización, o datos reales de proyecto
- Cambios que rompen la suite de tests sin razón documentada
- Comandos que duplican funcionalidad existente sin mejorarla
- Contribuciones generadas por IA sin testing manual real

---

## Reconocimiento

Cada contributor aparece en [CONTRIBUTORS.md](CONTRIBUTORS.md). Los first-timers se destacan en las release notes.
