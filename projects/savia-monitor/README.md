# Savia Monitor

Torre de control de escritorio para orquestar multiples sesiones de Claude Code en paralelo.

## Que hace

- **Sesiones**: detecta todas las instancias de Claude Code activas, muestra proyecto, rama, agentes y estado de Shield
- **Shield**: monitorea las 8 capas de proteccion de datos en tiempo real
- **Git**: visualiza ramas agrupadas por tipo, ficheros pendientes, estado de merge, nidos
- **Actividad**: feed en tiempo real de herramientas, agentes y eventos de seguridad

## Stack

- **Backend**: Rust (Tauri v2) — system tray, HTTP polling, deteccion de sesiones
- **Frontend**: Vue 3 + TypeScript + Pinia — componentes reactivos, i18n ES/EN
- **Design**: glassmorphism con variables CSS compartidas con savia-web

## Requisitos

- Node.js 18+
- Rust toolchain (rustup)
- MSVC Build Tools + Windows SDK (Windows) o gcc (Linux)

## Desarrollo

```bash
npm install
npm run tauri dev    # Arranca con hot reload
npm run test         # Unit tests (Vitest)
npx playwright test  # E2E tests
```

## Estructura

```
src-tauri/src/    Rust: sessions, shield, git, logs, workflow, config
src/stores/       Pinia: sessions, shield, git, activity, workflow
src/components/   Vue: SessionsPanel, ShieldDashboard, GitNidos, ActivityPanel
src/locales/      i18n ES/EN con deteccion automatica del sistema
e2e/              Playwright E2E tests
```

## Arquitectura

Savia Monitor detecta sesiones de Claude Code leyendo `~/.claude/sessions/*.json` y verificando que el PID siga vivo. Los datos de actividad vienen de `~/.savia/live.log` (herramientas), `output/agent-lifecycle/lifecycle.jsonl` (agentes) y `output/data-sovereignty-audit.jsonl` (Shield). El polling HTTP cada 5s verifica el daemon Shield, Ollama y el proxy.
