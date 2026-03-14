import { describe, it, expect, vi, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import SprintReportPage from '../../../pages/reports/SprintReportPage.vue'

vi.mock('../../../composables/useReportData', () => ({
  useReportData: () => ({
    data: { value: null },
    loading: { value: false },
    load: vi.fn(),
  }),
}))

describe('SprintReportPage', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('renders without errors', () => {
    const wrapper = shallowMount(SprintReportPage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the sprint-report root element', () => {
    const wrapper = shallowMount(SprintReportPage)
    expect(wrapper.find('.sprint-report').exists()).toBe(true)
  })
})
