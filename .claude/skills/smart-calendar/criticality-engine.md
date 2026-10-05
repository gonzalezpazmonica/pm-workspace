# Motor local de criticidad: `scripts/criticality.sh`

Lo unico ejecutable de la skill. Solo lee el backlog local
(`projects/*/backlog/**/*.md`); Azure DevOps, Jira, Graph y el calendario
quedan fuera del script y los resuelven los comandos.

```
bash scripts/criticality.sh assess <item-id> [--project nombre]
bash scripts/criticality.sh dashboard [--project nombre]
bash scripts/criticality.sh rebalance [--project nombre] [--dry-run]
```

- **Salida**: 0 ok · 1 item o proyecto sin backlog · 2 uso invalido o id ambiguo
  (lista los candidatos). Subcomando desconocido = 2; `help` = 0.
- **Busqueda del item**: primero por `id:` del frontmatter y despues por nombre
  de fichero (`<id>.md`, `<id>-slug.md`, `<id>_slug.md`), sin distinguir
  mayusculas. `PBI-1` no resuelve a `PBI-12`. Se ignoran `archive/`.
- **Campos**: `impact` y `dependencies` (1-5, se redondean y acotan),
  `story_points` o `estimation_sp` (se redondea hacia arriba; 0 o vacio = sin
  estimar → 3), `deadline` (`YYYY-MM-DD` o `YYYY-MM-DDThh:mm[:ss]`), `state` o
  `status`, `title`, `assigned_to`. Valores entre comillas, CRLF, comentarios
  `#` y caracteres de control se limpian. Un valor no numerico se ignora con
  `WARN` en stderr: nunca se evalua como aritmetica de bash (evita inyeccion de
  comandos desde el frontmatter).
- **Deadline invalido** (`someday`, `2026-02-30`, `01/03/2026`): urgencia base
  (3), como sin deadline, con `WARN` en stderr, `(invalid deadline)` en
  `assess` y `ALERT: invalid deadline` en el dashboard. No se vuelve urgente
  por error, pero tampoco se pierde en silencio.
- **Decimales**: admite `2,5` (locale es_ES) y `2.5`. El score se calcula en
  centesimas enteras y se muestra siempre con punto (`4.15`), sea cual sea el
  locale. Umbrales exactos: P0 >= 4.00, P1 >= 3.00, P2 >= 2.00. La confianza
  se calcula en decimas (5 × decay: 90% = 4,5) sin truncar a entero; frente a
  la version anterior sube scores hasta 0,075 y puede promover items de P1 a P0
  en la frontera.
- **Fechas**: los dias hasta el deadline se cuentan entre medianoches UTC (sin
  efecto de la hora ni del cambio de horario). `CRITICALITY_TODAY=YYYY-MM-DD`
  fija el dia de referencia (deadlines y antiguedad para el decay) para informes
  reproducibles y tests; si no es una fecha valida, exit 2.
- **Dashboard**: solo items activos (excluye `state` Done/Closed/Removed/
  Archived/Cancelled/Resolved y `archive/`), ordenados por score descendente.
  Alertas: P0 sin asignar, mas de 3 P0 y deadline invalido.
- **Rebalance**: solo muestra el dashboard; la propuesta de reasignacion es
  interactiva (`/criticality-rebalance`).

Tests: `tests/test-smart-calendar.bats`. Skill: `SKILL.md` · Modelo: `spec-task-criticality.md`.
