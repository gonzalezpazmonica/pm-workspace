import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { useAuthStore } from '../../stores/auth'
import i18n from '../../locales'

const mockHealthCheck = vi.fn()
vi.mock('../../composables/useBridge', () => ({
  useBridge: () => ({
    healthCheck: mockHealthCheck,
    get: vi.fn(),
    post: vi.fn(),
    baseUrl: vi.fn(() => 'https://localhost:8922'),
    headers: vi.fn(() => ({})),
  }),
}))

const { default: SettingsPage } = await import('../../pages/SettingsPage.vue')

const mountOpts = { global: { plugins: [i18n] } }

describe('SettingsPage', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockHealthCheck.mockReset()
    localStorage.clear()
  })

  it('renders the settings heading', () => {
    const wrapper = mount(SettingsPage, mountOpts)
    expect(wrapper.find('h1').exists()).toBe(true)
  })

  it('renders host input with current auth value', () => {
    const auth = useAuthStore()
    auth.save('myserver', '8922', '', false)
    const wrapper = mount(SettingsPage, mountOpts)
    const hostInput = wrapper.find('input[placeholder="localhost"]')
    expect((hostInput.element as HTMLInputElement).value).toBe('myserver')
  })

  it('renders port input with current auth value', () => {
    const auth = useAuthStore()
    auth.save('localhost', '9000', '', false)
    const wrapper = mount(SettingsPage, mountOpts)
    const portInput = wrapper.find('input[placeholder="8922"]')
    expect((portInput.element as HTMLInputElement).value).toBe('9000')
  })

  it('shows success message when health check passes', async () => {
    mockHealthCheck.mockResolvedValueOnce(true)
    const wrapper = mount(SettingsPage, mountOpts)
    await wrapper.find('button.btn-secondary').trigger('click')
    await vi.waitFor(() => {
      expect(wrapper.find('.result.ok').exists()).toBe(true)
    })
  })

  it('shows failure message when health check fails', async () => {
    mockHealthCheck.mockResolvedValueOnce(false)
    const wrapper = mount(SettingsPage, mountOpts)
    await wrapper.find('button.btn-secondary').trigger('click')
    await vi.waitFor(() => {
      expect(wrapper.find('.result').exists()).toBe(true)
    })
  })

  it('Save & Test button calls auth.save and health check', async () => {
    mockHealthCheck.mockResolvedValueOnce(true)
    const auth = useAuthStore()
    const saveSpy = vi.spyOn(auth, 'save')
    const wrapper = mount(SettingsPage, mountOpts)
    await wrapper.find('button.btn-primary').trigger('click')
    await vi.waitFor(() => {
      expect(saveSpy).toHaveBeenCalled()
      expect(mockHealthCheck).toHaveBeenCalled()
    })
  })

  it('has TLS checkbox bound to useTls', () => {
    const auth = useAuthStore()
    auth.save('localhost', '8922', '', true)
    const wrapper = mount(SettingsPage, mountOpts)
    const checkbox = wrapper.find('input[type="checkbox"]')
    expect((checkbox.element as HTMLInputElement).checked).toBe(true)
  })

  it('renders language selector', () => {
    const wrapper = mount(SettingsPage, mountOpts)
    expect(wrapper.find('.lang-select').exists()).toBe(true)
  })
})
