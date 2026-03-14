import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useReportsStore } from '../../stores/reports'

describe('useReportsStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('initializes activeTab to sprint', () => {
    const store = useReportsStore()
    expect(store.activeTab).toBe('sprint')
  })

  it('initializes selectedProject to null', () => {
    const store = useReportsStore()
    expect(store.selectedProject).toBeNull()
  })

  describe('setTab', () => {
    it('updates activeTab', () => {
      const store = useReportsStore()
      store.setTab('dora')
      expect(store.activeTab).toBe('dora')
    })

    it('allows switching between tabs', () => {
      const store = useReportsStore()
      store.setTab('quality')
      store.setTab('debt')
      expect(store.activeTab).toBe('debt')
    })
  })

  describe('setProject', () => {
    it('updates selectedProject', () => {
      const store = useReportsStore()
      store.setProject('project-alpha')
      expect(store.selectedProject).toBe('project-alpha')
    })

    it('can change selected project', () => {
      const store = useReportsStore()
      store.setProject('p1')
      store.setProject('p2')
      expect(store.selectedProject).toBe('p2')
    })
  })
})
