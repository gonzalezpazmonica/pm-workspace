import { describe, it, expect, vi, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import LoginPage from '../../components/LoginPage.vue'

vi.stubGlobal('fetch', vi.fn())

describe('LoginPage', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.mocked(fetch).mockReset()
  })

  it('renders the login overlay', () => {
    const wrapper = shallowMount(LoginPage)
    expect(wrapper.find('.login-overlay').exists()).toBe(true)
  })

  it('shows the Savia logo and title', () => {
    const wrapper = shallowMount(LoginPage)
    expect(wrapper.find('.login-logo').exists()).toBe(true)
    expect(wrapper.find('h1').text()).toBe('Savia')
  })

  it('renders server URL, username and token inputs', () => {
    const wrapper = shallowMount(LoginPage)
    expect(wrapper.find('input[placeholder*="localhost"]').exists()).toBe(true)
    expect(wrapper.find('input[placeholder="@your-handle"]').exists()).toBe(true)
    expect(wrapper.find('input[type="password"]').exists()).toBe(true)
  })

  it('shows error if username does not start with @', async () => {
    const wrapper = shallowMount(LoginPage)
    await wrapper.find('input[placeholder="@your-handle"]').setValue('alice')
    await wrapper.find('.btn-connect').trigger('click')
    expect(wrapper.find('.error-msg').text()).toContain('must start with @')
  })

  it('shows error when bridge is not reachable', async () => {
    vi.mocked(fetch).mockResolvedValueOnce({ ok: false } as Response)
    const wrapper = shallowMount(LoginPage)
    await wrapper.find('input[placeholder="@your-handle"]').setValue('@alice')
    await wrapper.find('.btn-connect').trigger('click')
    await vi.waitFor(() => {
      expect(wrapper.find('.error-msg').exists()).toBe(true)
    })
  })
})
