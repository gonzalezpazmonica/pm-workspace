import { describe, it, expect, vi, beforeEach } from 'vitest'

// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {}
  return {
    getItem: vi.fn((key: string) => store[key] ?? null),
    setItem: vi.fn((key: string, value: string) => { store[key] = value }),
    clear: vi.fn(() => { store = {} })
  }
})()
Object.defineProperty(globalThis, 'localStorage', { value: localStorageMock })

describe('locales/index', () => {
  beforeEach(() => { localStorageMock.clear() })

  it('SUPPORTED_LOCALES contains es and en', async () => {
    const { SUPPORTED_LOCALES } = await import('../../locales/index')
    const codes = SUPPORTED_LOCALES.map((l) => l.code)
    expect(codes).toContain('es')
    expect(codes).toContain('en')
  })

  it('SUPPORTED_LOCALES has name for each locale', async () => {
    const { SUPPORTED_LOCALES } = await import('../../locales/index')
    for (const locale of SUPPORTED_LOCALES) {
      expect(locale.name.length).toBeGreaterThan(0)
    }
  })

  it('default export is an i18n instance', async () => {
    const { default: i18n } = await import('../../locales/index')
    expect(i18n).toBeDefined()
    expect(i18n.global).toBeDefined()
  })

  it('loadLocale is exported as a function', async () => {
    const { loadLocale } = await import('../../locales/index')
    expect(typeof loadLocale).toBe('function')
  })
})
