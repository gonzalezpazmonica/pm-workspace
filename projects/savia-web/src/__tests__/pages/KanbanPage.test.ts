import { describe, it, expect, vi, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import KanbanPage from '../../pages/KanbanPage.vue'

vi.mock('../../composables/useBridge', () => ({
  useBridge: () => ({ get: vi.fn().mockResolvedValue([]) }),
}))

describe('KanbanPage', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('renders without errors', () => {
    const wrapper = shallowMount(KanbanPage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the Kanban Board heading', () => {
    const wrapper = shallowMount(KanbanPage)
    expect(wrapper.find('h1').text()).toBe('Kanban Board')
  })
})
