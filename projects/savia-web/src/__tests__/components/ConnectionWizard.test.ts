import { describe, it, expect, vi, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import ConnectionWizard from '../../components/ConnectionWizard.vue'

const mockHealthCheck = vi.fn()

vi.mock('../../composables/useBridge', () => ({
  useBridge: () => ({ healthCheck: mockHealthCheck }),
}))

describe('ConnectionWizard', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockHealthCheck.mockReset()
  })

  it('renders the overlay', () => {
    mockHealthCheck.mockResolvedValue(false)
    const wrapper = shallowMount(ConnectionWizard)
    expect(wrapper.find('.wizard-overlay').exists()).toBe(true)
  })

  it('shows the Savia logo and title', () => {
    mockHealthCheck.mockResolvedValue(false)
    const wrapper = shallowMount(ConnectionWizard)
    expect(wrapper.find('.wizard-logo').text()).toBe('🦉')
    expect(wrapper.find('h1').text()).toBe('Welcome to Savia')
  })

  it('starts in detecting step', () => {
    mockHealthCheck.mockReturnValue(new Promise(() => {}))
    const wrapper = shallowMount(ConnectionWizard)
    expect(wrapper.text()).toContain('Looking for Savia Bridge')
  })

  it('shows form when auto-detect fails', async () => {
    mockHealthCheck.mockResolvedValue(false)
    const wrapper = shallowMount(ConnectionWizard)
    await vi.waitFor(() => {
      expect(wrapper.find('.subtitle').exists()).toBe(true)
    })
    expect(wrapper.find('input[placeholder="localhost"]').exists()).toBe(true)
    expect(wrapper.find('input[placeholder="8922"]').exists()).toBe(true)
    expect(wrapper.find('.btn-connect').exists()).toBe(true)
  })

  it('shows success when auto-detect succeeds', async () => {
    mockHealthCheck.mockResolvedValue(true)
    const wrapper = shallowMount(ConnectionWizard)
    await vi.waitFor(() => {
      expect(wrapper.find('.success-msg').exists()).toBe(true)
    })
    expect(wrapper.text()).toContain('Connected to Savia Bridge')
  })

  it('shows error message on failed manual connect', async () => {
    mockHealthCheck.mockResolvedValue(false)
    const wrapper = shallowMount(ConnectionWizard)
    await vi.waitFor(() => {
      expect(wrapper.find('.btn-connect').exists()).toBe(true)
    })
    await wrapper.find('.btn-connect').trigger('click')
    await vi.waitFor(() => {
      expect(wrapper.find('.error-msg').exists()).toBe(true)
    })
  })
})
