---
name: visual-regression
description: "Visual regression testing — capturas por breakpoint, comparación contra baselines, informe de diffs"
developer_type: all
agent: task
context_cost: high
model: sonnet
argument-hint: "[--update-baseline] [--component nombre] [--page /ruta] [--breakpoint mobile|tablet|desktop|wide]"
---

# /visual-regression — Testing Visual de Regresión

> 🦉 Savia compara lo que renderiza tu app contra las baselines aprobadas.
> Stack: Playwright screenshots + pixelmatch (local, gratuito, sin vendor lock-in).

---

## Cargar perfil de usuario

Grupo: **QA & Testing** — cargar: `identity.md`, `projects.md`, `preferences.md`

---

## Subcomandos

- `/visual-regression` — captura todas las páginas y compara contra baselines
- `/visual-regression --update-baseline` — actualiza baselines con capturas actuales
- `/visual-regression --component {nombre}` — captura un componente aislado (Storybook)
- `/visual-regression --page {/ruta}` — captura una página específica
- `/visual-regression --breakpoint {bp}` — solo un breakpoint (mobile|tablet|desktop|wide)

---

## Flujo

### Paso 1 — Detectar páginas/componentes

Leer rutas del proyecto:

- React: `src/pages/`, `src/routes/`, router config
- Angular: `app-routing.module.ts` o `app.routes.ts`
- Si `--component`: buscar en Storybook o fichero del componente
- Si `--page`: usar la ruta proporcionada

### Paso 2 — Levantar servidor dev

```bash
# Detectar script de dev
npm run dev   # Vite/React
npm run start # Angular
npx storybook dev -p 6006  # Si --component y hay Storybook
```

Esperar a que el servidor esté ready (health check en localhost).

### Paso 3 — Capturar screenshots por breakpoint

```
Breakpoints:
  mobile:  375 × 812  (iPhone SE)
  tablet:  768 × 1024 (iPad)
  desktop: 1280 × 800 (Standard)
  wide:    1920 × 1080 (Full HD)
```

Para cada página × breakpoint:

1. Navegar con Playwright
2. Esperar a `networkidle`
3. Capturar screenshot full-page
4. Guardar en `screenshots/current/{page}-{breakpoint}.png`

### Paso 4 — Comparar contra baselines

```
Si existe screenshots/baseline/{page}-{breakpoint}.png:
  → Comparar con pixelmatch
  → Threshold: 0.1% de píxeles diferentes
  → Si diff > threshold → REGRESIÓN detectada
  → Generar diff image en screenshots/diff/

Si NO existe baseline:
  → Marcar como NEW (sin baseline para comparar)
  → Sugerir --update-baseline
```

### Paso 5 — Generar informe

```
🦉 Visual Regression — {proyecto}

  Páginas capturadas: 8
  Breakpoints: 4 (mobile, tablet, desktop, wide)
  Total screenshots: 32

  Página          | mobile | tablet | desktop | wide
  ────────────────|────────|────────|─────────|──────
  /login          | ✅     | ✅     | ✅      | ✅
  /dashboard      | ✅     | ❌ 0.3%| ✅      | ✅
  /settings       | ✅     | ✅     | ⚠️ NEW  | ⚠️ NEW
  /profile        | ✅     | ✅     | ✅      | ✅

  ❌ 1 regresión detectada
  ⚠️ 2 páginas sin baseline

  Diffs en: screenshots/diff/
  Informe: output/visual-regression/YYYYMMDD-report.md
```

### Paso 6 — Si `--update-baseline`

Copiar `screenshots/current/` a `screenshots/baseline/`. Confirmar antes de sobrescribir.

---

## Modo agente (role: "Agent")

```yaml
status: ok
action: visual_regression
pages_captured: 8
breakpoints: 4
total_screenshots: 32
regressions: 1
new_pages: 2
passed: 29
report_path: "output/visual-regression/20260306-report.md"
```

---

## Integración

| Comando | Relación |
|---|---|
| `/figma-extract` | Tokens de diseño como referencia visual |
| `/a11y-audit` | Contraste de colores en screenshots |
| `/spec-verify-ui` | Verifica spec + visual en un solo flujo |
| `/qa-dashboard` | Regresiones visuales en métricas QA |

---

## Restricciones

- **NUNCA** actualizar baselines sin confirmación del usuario
- **NUNCA** ignorar regresiones — siempre reportar
- **NUNCA** ejecutar en producción — solo dev/staging
- Screenshots `current/` y `diff/` en gitignore; solo baselines se comitean
