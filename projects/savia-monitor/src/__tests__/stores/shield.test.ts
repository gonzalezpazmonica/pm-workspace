import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useShieldStore } from '@/stores/shield'
import type { ShieldHealth } from '@/stores/shield'

describe('useShieldStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('starts with null health and default config', () => {
    const store = useShieldStore()
    expect(store.health).toBeNull()
    expect(store.shieldEnabled).toBe(true)
    expect(store.hookProfile).toBe('standard')
  })

  it('computes 8 layers', () => {
    const store = useShieldStore()
    expect(store.layers).toHaveLength(8)
  })

  it('all layers disabled when shield is off', () => {
    const store = useShieldStore()
    store.toggleShield()
    expect(store.shieldEnabled).toBe(false)
    store.layers.forEach((l) => {
      expect(l.status).toBe('disabled')
    })
  })

  it('updates health from event payload', () => {
    const store = useShieldStore()
    const mock: ShieldHealth = {
      daemon_up: true,
      ner_available: true,
      ollama_up: true,
      ollama_models: ['qwen2.5:7b'],
      proxy_up: true,
      timestamp: '2026-04-02T12:00:00Z',
    }
    store.updateHealth(mock)
    expect(store.health).toEqual(mock)
    expect(store.activeCount).toBe(8)
    expect(store.degradedCount).toBe(0)
    expect(store.downCount).toBe(0)
  })

  it('shows degraded when ollama is down', () => {
    const store = useShieldStore()
    store.updateHealth({
      daemon_up: true,
      ner_available: true,
      ollama_up: false,
      ollama_models: [],
      proxy_up: true,
      timestamp: '2026-04-02T12:00:00Z',
    })
    expect(store.degradedCount).toBeGreaterThan(0)
  })

  it('sets profile', () => {
    const store = useShieldStore()
    store.setProfile('strict')
    expect(store.hookProfile).toBe('strict')
  })
})
