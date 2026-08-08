# Spec: SE-312 — Savia Sonora Frontend Overhaul: rebrand Savia, UX/UI y alineación con Savia Web

**Task ID:**        SE-312
**PBI padre:**      SE-310 — Savia conversacional: interfaz de voz bidireccional (extensión de SE-308)
**Sprint:**         2026-08
**Fecha creación:** 2026-08-08
**Creado por:**     Savia

**Developer Type:** agent-team
**Asignado a:**     frontend-developer (React)
**Estado:**         PROPOSED

**Effort Estimation (Dual Model):**

| Dimension | Value |
|-----------|-------|
| Agent effort | 540 min (estimación inicial) |
| Human effort | 8 h (revisión visual manual de la app de escritorio) |
| Review effort | 90 min |
| Context risk | medium |
| Agent-capable | yes (la parte visual requiere humano para validar en Windows/Linux) |
| Fallback | Si agente falla: humano necesita 12h desde cero |

---

## 1. Contexto y Objetivo

**Contexto del PBI:** La app `projects/savia-sonora/app` (fork de VoiceFlow,
SE-308) es la interfaz de escritorio de Savia: dictado local, grabación de
reuniones y transcripción con Whisper. El rebrand a Savia quedó **incompleto
en el frontend**: la UI todavía se llama "VoiceFlow", apunta a
`infiniV/VoiceFlow` (GitHub) y usa la estética verde esmeralda del upstream.
El workspace tiene una identidad consolidada en `projects/savia-web` (UI
púrpura/violeta con glassmorphism, Material-3-inspired, logo búho Savia).

**Objetivo de esta task:** Analizar el frontend completo de Savia Sonora,
identificar gaps funcionales y de UX, y llevar su apariencia a la estética de
Savia Web (púrpura `#6B4C9A`, glassmorphism, radios grandes 10/16/24px,
sombras en capas, tipografía Inter), completando el rebrand a Savia. Incluye
i18n a español de las vistas principales y mejoras funcionales P1
(desduplicación, accesibilidad, estados).

**Criterios de Aceptación del PBI (extracto relevante):**
```
- [ ] El frontend de Savia Sonora usa la identidad visual de Savia Web (tokens, glass, radios, sombras)
- [ ] No queda branding residual "VoiceFlow"/"infiniV" visible al usuario
- [ ] Las vistas principales están en español (idioma del perfil activo)
- [ ] Home y History comparten la lógica duplicada de historial/audio
- [ ] Build (tsc + vite) y lint pasan
```

---

## 2. Análisis del estado actual (hallazgos SE-312)

### 2.1 Inventario de vistas y funcionalidad

| Vista | Ruta | Funcionalidad |
|---|---|---|
| Dashboard (layout) | `/dashboard/*` | Sidebar fija + header móvil + banner hotkey + main router (6 subrutas) |
| Home | `/dashboard` | Log de dictado: stats del día, búsqueda, lista agrupada por fecha, copy/delete/play audio, botón Record |
| History | `/dashboard/history` | Historial paginado (100), búsqueda debounce server-side, copy/delete/play |
| Meetings list | `/dashboard/meetings` | Biblioteca de reuniones, import, "live" indicator, "New meeting" |
| Meeting recorder | `/dashboard/meetings/record` | Grabación con VAD, timer, states, pause |
| Meeting detail | `/dashboard/meetings/:id` | Resumen IA, transcripción, audio, retranscripción |
| Settings | `/dashboard/settings` | 7 secciones: transcription, behavior, meetings, ai_summary, appearance, data, reset |
| Onboarding | `/onboarding` | 6 pasos: welcome, audio, hardware, model, download, theme, final |
| Popup | `/popup` | Indicador flotante de grabación (overlay, dark fijo, animaciones framer-motion) |

### 2.2 Gaps funcionales detectados

| # | Gap | Severidad | Evidencia |
|---|---|---|---|
| F1 | Branding residual: "VoiceFlow" en title, meta, onboarding, settings, logos, `infiniV/VoiceFlow` en GitHub | P0 | `index.html`, `Sidebar.tsx:87-95`, `Onboarding.tsx` STEPS_CONFIG, `SettingsTab.tsx:393,449` |
| F2 | Duplicación HomePage/HistoryPage: `loadHistory`, `handleCopy`, `handleDelete`, `handlePlayAudio`, `AudioPlayerDialog`, `RowAction`, `LogRow`, `LogSkeleton`, `LogEmpty` | P0 | `HomePage.tsx:34-104`, `HistoryPage.tsx:16-90` |
| F3 | Sin i18n: todo el copy en inglés (usuario de Savia es español) | P1 | `HomePage.tsx` header, `Sidebar.tsx` labels |
| F4 | `getRecordingState` polling a 1s fijo en HomePage; sin pausa cuando la ventana no es visible | P1 | `HomePage.tsx:50-70` |
| F5 | a11y: faltan `aria-label` en algunos icon-buttons (SearchBar clear sí tiene), sin `:focus-visible` global coherente, sin skip-nav | P1 | `HomePage.tsx`, `HistoryPage.tsx` |
| F6 | Sin hotkey screen-reader/texto "ayuda" centralizado; pro-tip duplicado en Sidebar y LogEmpty | P1 | `Sidebar.tsx:113`, `HomePage.tsx` LogEmpty |
| F7 | Error de carga de history no ofrece retry real (recarga página entera) | P2 | `HomePage.tsx:288` |
| F8 | `theme-color`/meta de index.html fijos a #09090b aunque el tema sea claro | P2 | `index.html` |
| F9 | Logo/iconos `light-logo.png`/`dark-logo.png` son los de VoiceFlow (no el búho Savia) | P0 | `public/light-logo.png` |
| F10 | Settings "Launch at login" / "Files VoiceFlow keeps on disk" → branding + claridad | P1 | `SettingsTab.tsx:393,449` |

### 2.3 Gaps de UX/UI y tendencias 2026 aplicadas

| Tendencia/estándar | Estado actual | Acción SE-312 |
|---|---|---|
| Glassmorphism (surfaces translúcidas + blur) | Ausente (flat, sin blur) | Adoptar token de superficie glass de savia-web (`--savia-glass-blur: 12px`) |
| Material-3 / radios grandes (10/16/24) | Radios 6/8/12/16 | Alinear a escala savia-web (10/16/24) |
| Sombras en capas (elevación) | Sin sombras | `--savia-shadow{-md,-lg}` |
| Palette púrpura de marca | Verde esmeralda #22c55e | `#6B4C9A` ramp (primary-light/dark, secondary #A78BCA) |
| Tipografía Inter + display de marca | Inter + Clash Display + Instrument Serif | Inter como tipografía única (alineación savia-web) |
| Dark/light + system | Sí (`.dark`, settings.theme) | Mantener; actualizar `theme-color` dinámicamente |
| Micro-interacciones + reduced-motion | Parcial (`rec-pulse`, `waveform`) | Mantener; transiciones suaves en cards/rows |
| Focus-visible accesible | `:focus` parcial | Anillo de foco 2px primary + offset |
| Empty states con CTA | Sí (LogEmpty) | Mantener y alinear estilo |
| Data density / tabular nums | `tabular-figs` en meetings | Reutilizar en stats |
| Desktop app escuchando al sistema | `reduced-effects` en Linux | Mantener (glass con fallback sin blur en Linux) |

### 2.4 Deuda técnica visible

- `index.css` retiene ~150 líneas de shims legacy (`.glass`, `.orb`, `.bg-grid`, `.headline-serif`, `.landing-page`) que ya no se usan o se anulan. SE-312 las limpia.
- `HomePage.tsx` (681 líneas) y `HistoryPage.tsx` (519) comparten >200 líneas idénticas.
- `App.css` (1 línea) innecesario.
- Fuentes premium (Clash Display, Instrument Serif) vía Fontshare/Google: coste y no alinean con savia-web. SE-312 reduce a Inter.

---

## 3. Contrato Técnico

### 3.1 Arquitectura de theming (un solo source of truth)

`src/index.css` pasa a exponer **los tokens de savia-web** como variables CSS
(`--savia-*`) y los mapea a los tokens shadcn (`--background`, `--primary`,
`--card`, `--border`, `--ring`, etc.) igual que hoy, pero con los valores de
savia-web:

```css
/* Light */
--background: #F5F3F8;                 /* --savia-background */
--surface: rgba(255,255,255,0.85);     /* glass --savia-surface */
--surface-solid: #FFFFFF;
--foreground: #1C1A1E;
--muted-foreground: #625B71;
--primary: #6B4C9A;                    /* --savia-primary */
--primary-400: #8E6FBF;                /* --savia-primary-light */
--primary-700: #4A2D7A;                /* --savia-primary-dark */
--secondary: #A78BCA;                  /* --savia-secondary */
--accent: #CDB4DB;                     /* --savia-accent */
--glass-blur: 12px;
--glass-border: rgba(255,255,255,0.3);
--radius-sm: 10px; --radius: 16px; --radius-lg: 24px;
--shadow: layered savia-web (light y dark);
```

- En `dark`: `--background:#13111A`, `--surface:rgba(33,31,38,0.85)`,
  `--surface-solid:#211F26`, `--glass-border:rgba(255,255,255,0.08)`,
  `--muted-foreground:#CAC4D0`.
- Se conservan los nombres de clase existentes (`bg-card`, `bg-sidebar`,
  `text-cream`, `border-border`, `glass-card`, `badge-glow`, `panel`) como
  **shims que resuelven a los tokens nuevos** — los componentes no necesitan
  reescribirse para el cambio de color, solo ajustes de clase puntuales.
- `bg-dots` se elimina o se convierte en fondo lavanda liso (savia-web no usa dots).
- Se añade utilidad `glass-panel` (blur + borde translúcido + sombra en capas)
  y se usa en Sidebar, StatsHeader, cards de meetings, dialogs.

### 3.2 Rebrand Savia

- `index.html`: `lang="es"`, `<title>Savia Sonora</title>`, meta description
  en español, `theme-color` dinámico por tema, favicons → `savia-logo.svg`/
  `favicon-96x96.png` (copiados de `projects/savia-web/public/`).
- `Sidebar.tsx`: logo `savia-logo.png`/`savia-logo.svg`, nombre "Savia Sonora",
  subtítulo "Interfaz hablada de Savia", nav en español (Inicio, Historial,
  Reuniones, Ajustes), enlaces a `github.com/gonzalezpazmonica/pm-workspace`
  (no infiniV), pro-tip en español.
- `Onboarding.tsx` y steps: títulos/subtítulos en español ("Bienvenida a Savia
  Sonora", "Configura el audio", "Hardware", "Modelo", "Descarga", "Tema").
- `SettingsTab.tsx`: "Start VoiceFlow when you sign in" → "Iniciar Savia
  Sonora al encender", "Files VoiceFlow keeps on disk" → "Archivos que Savia
  Sonora guarda en disco".
- `Popup.tsx`: estados y textos en español (p.ej. "Grabando", "Procesando").
- Meetings (list/detail/recorder/settings): headers y empty states en español.
- `StatsHeader`, `HistoryPage`, `HomePage`: copy de header, secciones y estados
  en español (términos técnicos en inglés cuando sea natural: model, streak).

### 3.3 i18n ES (ligero, sin librería nueva)

- Nuevo módulo `src/lib/i18n.ts`: diccionario `type Dict = Record<string,string>`,
  `const ES: Dict`, `const EN: Dict` (defecto `es`), y `t(key, vars?)` con
  interpolación `{var}`. Aplicado en las vistas principales sin tocar la
  lógica de negocio.
- Se evita react-i18next (dependencia nueva en app de escritorio); el
  diccionario es suficiente para Savia (perfil español).

### 3.4 Mejoras funcionales P1

- **Dedup**: `src/hooks/useHistoryEntries.ts` encapsula `loadHistory/search/
  copy/delete/playAudio + audio state`; `HomePage` y `HistoryPage` lo usan.
  `src/components/AudioPlayerDialog.tsx` extraído (única implementación).
- **Polling inteligente**: `useRecordingState(intervalMs)` con pausa vía
  `document.visibilityState === "visible"`.
- **a11y**: `:focus-visible` global (outline 2px `--ring` + offset), `aria-live`
  en estados de carga/error, `aria-label` en todos los icon-buttons.
- **Retry real**: LogError pasa `onRetry` que re-ejecuta la carga (sin
  `window.location.reload`).
- **theme-color dinámico**: en `applyTheme` se actualiza el meta
  `theme-color` según tema (light `#F5F3F8`, dark `#13111A`).

### 3.5 Fuera de alcance (para SE-310 frontend, no aquí)

- Vista de conversación (hotkey conversacional, bubbles, barge-in UI).
- Integración SaviaVaults (VaultBridge UI), audio briefs, proactividad, visión.
- Migración a react-i18next o i18n full de 100% de cadenas.
- Rediseño estructural del layout (nueva navegación).

---

## 4. Inputs/Outputs

**Inputs:**
- Tokens de savia-web: `projects/savia-web/src/styles/variables.css`
- Marca: `projects/savia-web/public/savia-logo.{png,svg}`, `favicon.svg`
- Strings en español: `projects/savia-web/src/locales/es.json` (referencia de
  vocabulario, no se importa)

**Outputs:**
- UI de Savia Sonora con estética savia-web (púrpura/glass), rebrand Savia,
  copy en español, dedup de Home/History, a11y mejorada.
- Ficheros modificados: `src/index.css`, `index.html`, `Sidebar.tsx`,
  `HomePage.tsx`, `HistoryPage.tsx`, `StatsHeader.tsx`, `SettingsTab.tsx`,
  `Onboarding.tsx` + steps, `Popup.tsx`, meetings/*, `App.tsx` (applyTheme),
  `src/lib/i18n.ts` (nuevo), `src/hooks/useHistoryEntries.ts` (nuevo),
  `src/components/AudioPlayerDialog.tsx` (nuevo), `public/*` (logos).
- No se cambia la API backend ni los contratos IPC (SE-310 intactos).

---

## 5. Test Scenarios

1. `pnpm run lint` (eslint src) pasa sin errores nuevos.
2. `pnpm run typecheck` (`tsc -b`) pasa.
3. `pnpm run build` (`tsc -b && vite build`) produce `dist-front` sin errores.
4. `pnpm run version:check` pasa (no romper versión).
5. Manual (humano): la app abre en Windows y Linux; tema claro/oscuro; popup
   sigue oscuro y con acento púrpura; hotkey y grabación intactos.
6. No hay strings "VoiceFlow" ni "infiniV" en los ficheros frontend de src
   (grep) salvo comentarios técnicos de atribución MIT permitidos.
7. BATS: los tests existentes de estructura (workspace) siguen pasando;
   si se añade BATS de frontend, debe pasar.

---

## 6. Ficheros a Crear/Modificar

| Fichero | Acción | Contenido |
|---|---|---|
| `projects/savia-sonora/app/src/index.css` | MOD | Tokens savia-web, glass, radios, sombras, limpieza shims |
| `projects/savia-sonora/app/index.html` | MOD | lang=es, title Savia Sonora, meta, fuentes Inter, favicon savia |
| `projects/savia-sonora/app/src/App.tsx` | MOD | applyTheme actualiza theme-color dinámico |
| `projects/savia-sonora/app/src/lib/i18n.ts` | NEW | Diccionario es/en + `t()` |
| `projects/savia-sonora/app/src/hooks/useHistoryEntries.ts` | NEW | Lógica dedup historial/audio |
| `projects/savia-sonora/app/src/components/AudioPlayerDialog.tsx` | NEW | Dialog de audio único |
| `projects/savia-sonora/app/src/components/Sidebar.tsx` | MOD | Rebrand, glass, nav es |
| `projects/savia-sonora/app/src/components/HomePage.tsx` | MOD | Usa hooks, copy es, retry real, a11y |
| `projects/savia-sonora/app/src/components/HistoryPage.tsx` | MOD | Usa hooks, copy es |
| `projects/savia-sonora/app/src/components/StatsHeader.tsx` | MOD | Tokens nuevos, copy es |
| `projects/savia-sonora/app/src/components/SettingsTab.tsx` | MOD | Rebrand strings, tokens |
| `projects/savia-sonora/app/src/pages/Onboarding.tsx` + steps | MOD | Títulos es, tokens |
| `projects/savia-sonora/app/src/pages/Popup.tsx` | MOD | Acento púrpura, copy es |
| `projects/savia-sonora/app/src/components/meetings/*` | MOD | Headers/empty states es + tokens |
| `projects/savia-sonora/app/public/*` | MOD | savia-logo, favicon savia |
| `projects/savia-sonora/specs/SE-312-savia-sonora-frontend.spec.md` | NEW | Esta spec |

---

## 7. Criterios de Aceptación

- [ ] AC-1: `index.css` usa los tokens de savia-web (púrpura, glass, radios 10/16/24, sombras en capas, light y dark).
- [ ] AC-2: No queda "VoiceFlow"/"infiniV" visible al usuario en el frontend (grep en `src/**` sin matches en strings de UI).
- [ ] AC-3: `index.html` dice "Savia Sonora" y `lang="es"`; favicon/logo son el búho de Savia.
- [ ] AC-4: Sidebar y Dashboard muestran marca Savia, nav en español y glass-panel.
- [ ] AC-5: Home y History usan `useHistoryEntries`/`AudioPlayerDialog` (sin duplicación de >200 líneas).
- [ ] AC-6: Vistas principales en español (Home, History, Meetings, Settings, Onboarding, Popup).
- [ ] AC-7: `:focus-visible` global, `aria-label` en icon-buttons, `aria-live` en carga/error, retry sin reload.
- [ ] AC-8: `pnpm run lint`, `pnpm run typecheck`, `pnpm run build`, `pnpm run version:check` pasan.
- [ ] AC-9: `theme-color` dinámico según tema (light/dark).
- [ ] AC-10: En Linux `reduced-effects` sigue activo (glass sin blur costoso) — el popup conserva fondo oscuro.
- [ ] AC-11: Las AC del PBI (SE-310) que dependen del frontend no se rompen (contratos IPC intactos).

---

## 8. Roadmap de Implementación (dentro de SE-312)

| Slice | Contenido | Deps |
|---|---|---|
| S1 | Tokens `index.css` + `index.html` + logos + `theme-color` | — |
| S2 | `i18n.ts` + `useHistoryEntries` + `AudioPlayerDialog` | S1 |
| S3 | Sidebar + Dashboard + Home + History (dedup + es) | S1, S2 |
| S4 | StatsHeader + Settings + Onboarding + Popup + meetings (es + tokens) | S1, S2 |
| S5 | Limpieza shims legacy, a11y global, verificación (lint/tsc/build) | S1-S4 |

---

## 9. Estado de Implementación

- [x] S1 done (tokens savia-web, index.html lang es/title, logos búho, theme-color dinámico)
- [x] S2 done (i18n.ts, useHistoryEntries, AudioPlayerDialog + vitest infra)
- [x] S3 done (Sidebar/Dashboard/Home/History rebrand + dedup + es)
- [x] S4 done (StatsHeader/Settings/Onboarding/Popup/meetings es + tokens)
- [x] S5 done (limpieza, lint 0 err, typecheck OK, vite build OK, 26 tests)
- [ ] Revisión humana de la app en Windows/Linux

---

## 10. OpenCode Implementation Plan

**Classification:** FEATURE_EXTERNAL

**Prerequisitos:** Ninguno (rama `agent/se312-sonora-frontend-overhaul` sobre main).

**Plan de ejecución por slice:**
1. **S1**: Reescribir `src/index.css` tokens (púrpura/glass/radios/sombras, mantener
   shims de clases legacy), `index.html` (lang es, title, meta, fuentes Inter,
   favicon savia), copiar `savia-logo.*`+`favicon.svg` desde savia-web a `public/`,
   `App.tsx` theme-color dinámico.
2. **S2**: Crear `src/lib/i18n.ts`, `src/hooks/useHistoryEntries.ts`,
   `src/components/AudioPlayerDialog.tsx`.
3. **S3**: Reescribir `Sidebar.tsx` (marca+nav es+glass), `HomePage.tsx` y
   `HistoryPage.tsx` (usar hooks, copy es, retry real, a11y).
4. **S4**: `StatsHeader.tsx`, `SettingsTab.tsx` (strings), `Onboarding.tsx`+steps,
   `Popup.tsx` (acento púrpura + copy es), meetings pages (headers/empty es).
5. **S5**: Limpiar shims sin uso, verificar `pnpm run check`, arreglar lint/tsc.

**Verificación:** `pnpm run lint && pnpm run typecheck && pnpm run build && pnpm run version:check` en `projects/savia-sonora/app`. BATS de estructura del workspace (si aplica). Firma confidencialidad + PR Draft con métricas antes/después.

**Riesgos:** build de la app de escritorio depende de Python/Pyloid (`pnpm run dev`
necesita backend); la validación visual final es humana. El cambio de paleta es
mecánico vía tokens, riesgo bajo de romper lógica.
