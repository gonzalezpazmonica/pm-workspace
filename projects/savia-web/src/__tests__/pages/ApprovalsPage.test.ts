import { describe, it, expect, vi, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import ApprovalsPage from '../../pages/ApprovalsPage.vue'

vi.mock('../../composables/useBridge', () => ({
  useBridge: () => ({ get: vi.fn().mockResolvedValue([]) }),
}))

describe('ApprovalsPage', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('renders without errors', () => {
    const wrapper = shallowMount(ApprovalsPage)
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the Approvals heading', () => {
    const wrapper = shallowMount(ApprovalsPage)
    expect(wrapper.find('h1').text()).toBe('Approvals')
  })
})
