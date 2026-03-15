import { createI18n } from 'vue-i18n'
import es from './es.json'
import en from './en.json'

export interface SupportedLocale {
  code: string
  name: string
}

export const SUPPORTED_LOCALES: SupportedLocale[] = [
  { code: 'es', name: 'Espa\u00f1ol' },
  { code: 'en', name: 'English' },
]

const STORAGE_KEY = 'savia:locale'

function getStoredLocale(): string {
  try {
    return localStorage.getItem(STORAGE_KEY) ?? 'es'
  } catch {
    return 'es'
  }
}

const i18n = createI18n({
  legacy: false,
  locale: getStoredLocale(),
  fallbackLocale: 'es',
  messages: { es, en },
})

export async function loadLocale(code: string) {
  i18n.global.locale.value = code as 'es' | 'en'
  try {
    localStorage.setItem(STORAGE_KEY, code)
  } catch { /* ignore */ }
}

export default i18n
