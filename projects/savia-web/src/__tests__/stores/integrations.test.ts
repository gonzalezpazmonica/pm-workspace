import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useIntegrationsStore } from '../../stores/integrations'

describe('useIntegrationsStore', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('starts with empty state', () => {
    const store = useIntegrationsStore()
    expect(store.workflows).toEqual([])
    expect(store.connection.connected).toBe(false)
  })

  it('loads mock data', async () => {
    const store = useIntegrationsStore()
    await store.load()
    expect(store.workflows.length).toBeGreaterThan(0)
    expect(store.executions.length).toBeGreaterThan(0)
  })

  it('saves connection', () => {
    const store = useIntegrationsStore()
    store.saveConnection('http://localhost:5678', 'key-123')
    expect(store.connection.connected).toBe(true)
    expect(store.connection.url).toBe('http://localhost:5678')
  })

  it('disconnected when empty URL', () => {
    const store = useIntegrationsStore()
    store.saveConnection('', 'key')
    expect(store.connection.connected).toBe(false)
  })
})
