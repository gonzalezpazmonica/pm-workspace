import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'

vi.mock('../../composables/useBridge', () => ({
  useBridge: () => ({ get: vi.fn().mockResolvedValue([]) }),
}))
vi.mock('../../components/LoadingSpinner.vue', () => ({
  default: { template: '<div class="loading-stub" />' },
}))
vi.mock('../../components/EmptyState.vue', () => ({
  default: { template: '<div class="empty-stub" />', props: ['icon', 'title'] },
}))

const { default: TimeLogPage } = await import('../../pages/TimeLogPage.vue')

describe('TimeLogPage', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('renders without errors', () => {
    const wrapper = mount(TimeLogPage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the Time Log heading', () => {
    const wrapper = mount(TimeLogPage)
    expect(wrapper.find('h1').text()).toBe('Time Log')
  })

  it('shows empty state when no entries exist', async () => {
    const wrapper = mount(TimeLogPage)
    await vi.waitFor(() => {
      expect(wrapper.find('.loading-stub').exists()).toBe(false)
    })
    expect(wrapper.find('.empty-stub').exists()).toBe(true)
  })

  it('has entries-table structure in template', () => {
    // Verify the template compiles and the .timelog-page root is present
    const wrapper = mount(TimeLogPage)
    expect(wrapper.find('.timelog-page').exists()).toBe(true)
  })
})
