# Savia Monitor — Desktop System Tray App

## Stack
- **Backend**: Rust (Tauri v2) — system tray, HTTP polling, file watching, session detection
- **Frontend**: Vue 3 + TypeScript + Vite — Pinia stores, ECharts, lucide icons
- **Design**: Reutiliza `variables.css` de savia-web (glassmorphism, dark mode)
- **Icons**: lucide-vue-next (mismo que savia-web)
- **i18n**: ES/EN con deteccion automatica del idioma del sistema

## Estructura
- `src-tauri/src/` — Modulos Rust: main, sessions, shield, config, logs, git, workflow
- `src/` — Vue SFCs, Pinia stores, composables, styles, locales
- `src/styles/variables.css` — Copiado de savia-web, NO modificar independientemente
- `e2e/` — Tests Playwright E2E

## Comandos
```bash
npm install                              # Instalar deps frontend
npm run tauri dev                        # Desarrollo (hot reload)
npm run tauri build                      # Build instalador (nativo OS)
npm run test                             # Unit tests (Vitest)
npx playwright test                      # E2E tests

# Linux build (.deb + .rpm + .AppImage)
bash scripts/build-linux.sh              # Build completo
bash scripts/build-linux.sh --check      # Verificar entorno
bash scripts/build-linux.sh --deb-only   # Solo .deb
```

## Targets soportados
- **Windows**: msi, nsis
- **macOS**: dmg
- **Linux**: deb, rpm, appimage (ver `scripts/build-linux.sh`)

## Convenciones
- Tauri commands en Rust: `#[tauri::command]` → registrar en main.rs invoke_handler
- Stores: Pinia composition API (`defineStore('name', () => {...})`)
- Componentes: `<script setup lang="ts">` con imports de lucide
- CSS: solo variables de `variables.css`, nunca colores hardcoded
- i18n: toda string visible usa `t('key')` de `@/locales/i18n`
- Cross-platform: `$HOME` / `USERPROFILE`, paths con forward slashes
- CARGO_TARGET_DIR fuera de OneDrive: `~/.savia/cargo-target/savia-monitor`
- Sin mocks: todos los datos vienen del backend Rust real

## Data Sources
- `~/.claude/sessions/*.json` — Sesiones Claude Code activas (PID, nombre, cwd)
- `~/.savia/live.log` — Actividad de herramientas en tiempo real
- `output/agent-lifecycle/lifecycle.jsonl` — Eventos de agentes
- `output/data-sovereignty-audit.jsonl` — Eventos de auditoria Shield
- `127.0.0.1:8444/health` — Shield daemon
- `127.0.0.1:11434/api/tags` — Ollama
- `~/.savia/hook-profile` — Perfil de hooks activo
- `git branch` — Estado de ramas por proyecto

## Tabs
1. **Sesiones** — Torre de control: sesiones activas, agentes, salud, rama con estado
2. **Shield** — 8 capas con estado real, tooltips, audit feed, toggle, perfil
3. **Git** — Ramas locales/remotas agrupadas, nidos, selector proyecto
4. **Actividad** — Feed en tiempo real con filtros (herramientas/agentes/shield)
