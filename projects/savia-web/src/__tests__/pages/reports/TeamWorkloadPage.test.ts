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

const { default: TeamWorkloadPage } = await import('../../../pages/reports/TeamWorkloadPage.vue')

describe('TeamWorkloadPage', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('renders without errors', () => {
    const wrapper = shallowMount(TeamWorkloadPage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the workload-page root element', () => {
    const wrapper = shallowMount(TeamWorkloadPage)
    expect(wrapper.find('.workload-page').exists()).toBe(true)
  })

  it('does not show loading when useReportData returns loading: false', () => {
    const wrapper = shallowMount(TeamWorkloadPage)
    expect(wrapper.find('.loading-stub').exists()).toBe(false)
  })

  it('does not render chart cards when data is null', () => {
    const wrapper = shallowMount(TeamWorkloadPage)
    expect(wrapper.findAll('.chart-card').length).toBe(0)
  })
})
