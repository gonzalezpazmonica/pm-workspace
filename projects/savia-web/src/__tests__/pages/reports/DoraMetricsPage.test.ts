import { describe, it, expect, vi, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'

vi.mock('../../../composables/useReportData', () => ({
  useReportData: () => ({
    data: { value: null },
    loading: { value: false },
    load: vi.fn(),
  }),
}))
vi.mock('../../../components/LoadingSpinner.vue', () => ({
  default: { template: '<div class="loading-stub" />' },
}))

const { default: DoraMetricsPage } = await import('../../../pages/reports/DoraMetricsPage.vue')

describe('DoraMetricsPage', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('renders without errors', () => {
    const wrapper = shallowMount(DoraMetricsPage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the dora-page root element', () => {
    const wrapper = shallowMount(DoraMetricsPage)
    expect(wrapper.find('.dora-page').exists()).toBe(true)
  })

  it('does not show loading when useReportData returns loading: false', () => {
    const wrapper = shallowMount(DoraMetricsPage)
    expect(wrapper.find('.loading-stub').exists()).toBe(false)
  })

  it('does not render chart cards when data is null', () => {
    const wrapper = shallowMount(DoraMetricsPage)
    expect(wrapper.findAll('.chart-card').length).toBe(0)
  })
})
