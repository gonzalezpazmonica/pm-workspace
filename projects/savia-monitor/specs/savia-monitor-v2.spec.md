# Savia Monitor v2 — Spec de Mejoras

## Estado actual

App de escritorio Tauri v2 + Vue 3 con 4 tabs: Sesiones, Shield, Git, Actividad.
Backend Rust (7 modulos). Frontend (6 stores, i18n ES/EN). 21 tests.

## Mejoras para PR

### Hechas
- Fix unwrap(), dead code, stores no usados, validacion git
- README.md/en, CLAUDE.md actualizado, .gitignore limpio
- Polling cada 10s en Sesiones y Actividad
- Health score real (Shield + Git + Agentes + Perfil)
- Nombre de sesion de Claude Code (de ~/.claude/sessions/)
- Estado de rama (dirty, unpushed, PR, merged)
- 3 ultimas acciones por sesion

### Pendientes para PR
- CHANGELOG.md
- Verificar ficheros <150 lineas

## Mejoras futuras (spec v2.1)

### Token tracking
- Leer datos de consumo de ~/.claude/ si disponibles
- Mostrar tokens por sesion y agregado semanal
- Seccion "Cuenta" con plan activo y modelo

### Observabilidad
- File watcher (notify crate) para JSONL en tiempo real
- OS notifications en eventos BLOCKED
- Tray icon color dinamico segun estado global

### Visualizacion
- ECharts pie (block/allow) en Shield
- ECharts gauge de salud en Sesiones
- Export de actividad a JSONL/CSV

### Documentacion
- Guia arquitectonica para formacion
- Traducciones en todos los idiomas de pm-workspace
