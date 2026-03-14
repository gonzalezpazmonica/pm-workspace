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

const { default: QualityPage } = await import('../../../pages/reports/QualityPage.vue')

describe('QualityPage', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('renders without errors', () => {
    const wrapper = shallowMount(QualityPage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the quality-page root element', () => {
    const wrapper = shallowMount(QualityPage)
    expect(wrapper.find('.quality-page').exists()).toBe(true)
  })

  it('does not show loading when useReportData returns loading: false', () => {
    const wrapper = shallowMount(QualityPage)
    expect(wrapper.find('.loading-stub').exists()).toBe(false)
  })

  it('does not render chart rows when data is null', () => {
    const wrapper = shallowMount(QualityPage)
    expect(wrapper.find('.charts-row').exists()).toBe(false)
  })
})
