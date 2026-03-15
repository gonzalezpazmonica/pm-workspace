import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { usePipelineStore } from '../../stores/pipeline'

describe('usePipelineStore', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('starts with empty runs', () => {
    const store = usePipelineStore()
    expect(store.runs).toEqual([])
    expect(store.selectedRunId).toBeNull()
  })

  it('loads mock data', async () => {
    const store = usePipelineStore()
    await store.load()
    expect(store.runs.length).toBeGreaterThan(0)
  })

  it('selects a run', async () => {
    const store = usePipelineStore()
    await store.load()
    store.selectRun('run-1')
    expect(store.selectedRun?.id).toBe('run-1')
    expect(store.selectedRun?.stages.length).toBeGreaterThan(0)
  })

  it('returns null for unknown run', () => {
    const store = usePipelineStore()
    store.selectRun('nonexistent')
    expect(store.selectedRun).toBeNull()
  })
})
