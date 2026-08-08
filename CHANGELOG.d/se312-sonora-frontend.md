---
version_bump: patch
section: Changed
---

### Changed

- **Savia Sonora frontend**: rebrand completo VoiceFlow → Savia Sonora (index.html, Sidebar, Dashboard, Onboarding, Settings, Popup, meetings). Estética alineada con Savia Web: paleta púrpura `#6B4C9A`, glassmorphism, radios 10/16/24px, sombras en capas, tipografía Inter única y `theme-color` dinámico.
- **i18n**: nuevo diccionario es/en (`src/lib/i18n.ts`) aplicado a las vistas principales; idioma por defecto español.
- **Dedup**: HomePage y HistoryPage ahora comparten el hook `useHistoryEntries` y el componente `AudioPlayerDialog` (~500 líneas de duplicado eliminadas).
- **Tests**: se añade vitest + jsdom + testing-library (27 tests frontend) y el script `test:frontend`.
- **a11y**: focus-visible global, aria-live en carga/error, aria-label en icon-buttons y retry sin recargar la página.
