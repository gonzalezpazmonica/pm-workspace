# Spec: Savia Web — Internationalization (i18n)

## Metadatos
- project: savia-web
- phase: 2 — Savia Web Core
- feature: i18n
- status: pending
- developer_type: human
- depends: savia-web-mvp
- parent_pbi: ""

## Objective

Implement full internationalization support in savia-web. Launch with Spanish (es) and English (en). Architecture must support adding new languages by adding a single JSON file — zero code changes per language.

## Architecture

### Library: vue-i18n

```
npm install vue-i18n@9
```

vue-i18n is the standard i18n library for Vue 3. MIT license. Supports:
- Composition API (`useI18n()`)
- Lazy loading of locale files
- Pluralization, date/number formatting
- Fallback locale chain

### Locale files structure

```
src/locales/
├── es.json          ← Spanish (default)
├── en.json          ← English
└── index.ts         ← i18n setup + lazy loader
```

Each JSON file uses namespaced keys: `common.*` (save, cancel, delete, loading...), `nav.*` (sidebar items), `settings.*`, `backlog.*`, `pipelines.*`, `integrations.*`, `project.*`, `files.*`, `time.*`. See `src/locales/es.json` for the full key catalog (created during implementation).

### i18n setup (`src/locales/index.ts`)

```typescript
import { createI18n } from 'vue-i18n'
import es from './es.json'

const i18n = createI18n({
  legacy: false,              // Composition API mode
  locale: localStorage.getItem('savia:locale') || 'es',
  fallbackLocale: 'es',
  messages: { es }
})

// Lazy load other locales on demand
export async function loadLocale(locale: string) {
  if (i18n.global.availableLocales.includes(locale)) return
  const messages = await import(`./${locale}.json`)
  i18n.global.setLocaleMessage(locale, messages.default)
}

export default i18n
```

### Adding a new language

To add French:
1. Create `src/locales/fr.json` (copy `es.json`, translate values)
2. Add `{ code: 'fr', name: 'Français', flag: '🇫🇷' }` to `SUPPORTED_LOCALES` in `index.ts`
3. Done — zero code changes elsewhere

## Implementation

### 1. Install and configure

```bash
npm install vue-i18n@9
```

In `main.ts`:
```typescript
import i18n from './locales'
app.use(i18n)
```

### 2. Replace all hardcoded strings

Every `.vue` file that has hardcoded Spanish or English text:

**Before:**
```html
<h1>Ajustes</h1>
<button>Guardar</button>
```

**After:**
```html
<h1>{{ $t('settings.title') }}</h1>
<button>{{ $t('common.save') }}</button>
```

In `<script setup>`:
```typescript
const { t } = useI18n()
const label = t('settings.title')
```

### 3. Language selector in Settings

New section in `SettingsPage.vue` after Bridge Connection:

```html
<section class="card">
  <h2>{{ $t('settings.language') }}</h2>
  <p class="hint">{{ $t('settings.languageHint') }}</p>
  <select v-model="locale" @change="changeLocale">
    <option v-for="l in locales" :key="l.code" :value="l.code">
      {{ l.name }}
    </option>
  </select>
</section>
```

Supported locales:
```typescript
const SUPPORTED_LOCALES = [
  { code: 'es', name: 'Español' },
  { code: 'en', name: 'English' }
]
```

On change:
1. `localStorage.setItem('savia:locale', code)`
2. Load locale file if not loaded (`loadLocale(code)`)
3. Set `i18n.global.locale.value = code`
4. All `$t()` calls reactively update — no page reload needed

### 4. Date and number formatting

Use vue-i18n's built-in formatters:

```typescript
// Numbers
$n(1234.5, 'decimal')    // es: "1.234,5" | en: "1,234.5"
$n(0.85, 'percent')      // es: "85 %" | en: "85%"

// Dates
$d(new Date(), 'short')  // es: "14/03/2026" | en: "03/14/2026"
$d(new Date(), 'long')   // es: "14 de marzo de 2026" | en: "March 14, 2026"
```

### 5. Pages requiring translation

| Page | Hardcoded strings to replace |
|------|------------------------------|
| `HomePage.vue` | Greeting, section titles, empty states |
| `ChatPage.vue` | Placeholder, send button, permission labels |
| `CommandsPage.vue` | Header, search placeholder, family names |
| `KanbanPage.vue` / `BacklogPage.vue` | Column headers, card labels |
| `ApprovalsPage.vue` | Status labels, action buttons |
| `TimeLogPage.vue` | Headers, form labels |
| `FileBrowserPage.vue` | Navigation labels, viewer controls |
| `ProfilePage.vue` | Section titles, stat labels |
| `SettingsPage.vue` | All form labels, buttons, results |
| `AppSidebar.vue` | Navigation item names |
| `AppTopBar.vue` | Connection status, logout |
| `LoginPage.vue` | Form labels, buttons, hints |
| `ConnectionWizard.vue` | Steps, labels, error messages |
| Reports pages (7) | Chart titles, axis labels, legends |
| `EmptyState.vue` | Default messages |
| `LoadingSpinner.vue` | Loading text |

## Acceptance Criteria

- [ ] AC-1: Language selector in Settings with Spanish and English
- [ ] AC-2: Selecting English switches all UI text to English instantly (no reload)
- [ ] AC-3: Selected language persists in localStorage across sessions
- [ ] AC-4: Default language is Spanish
- [ ] AC-5: All sidebar navigation labels use `$t('nav.*')`
- [ ] AC-6: All form labels, buttons, and messages use `$t()`
- [ ] AC-7: Dates format according to locale (DD/MM vs MM/DD)
- [ ] AC-8: Numbers format according to locale (1.234,5 vs 1,234.5)
- [ ] AC-9: Adding French requires only creating `fr.json` + 1 line in `SUPPORTED_LOCALES`
- [ ] AC-10: Fallback: if a key is missing in `en.json`, shows Spanish text (not key name)
- [ ] AC-11: Chat messages from Claude are NOT translated (they're dynamic content)
- [ ] AC-12: Zero new runtime dependencies beyond vue-i18n (MIT license)
