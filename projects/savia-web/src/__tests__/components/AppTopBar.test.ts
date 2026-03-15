import { describe, it, expect, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { useAuthStore } from '../../stores/auth'
import AppTopBar from '../../components/AppTopBar.vue'

describe('AppTopBar', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('renders menu toggle button', () => {
    const wrapper = shallowMount(AppTopBar)
    expect(wrapper.find('.menu-btn').exists()).toBe(true)
  })

  it('emits toggle-sidebar on menu click', async () => {
    const wrapper = shallowMount(AppTopBar)
    await wrapper.find('.menu-btn').trigger('click')
    expect(wrapper.emitted('toggle-sidebar')).toBeTruthy()
  })

  it('shows Disconnected when not logged in', () => {
    const wrapper = shallowMount(AppTopBar)
    expect(wrapper.find('.status').text()).toBe('Disconnected')
  })

  it('shows profile name and logout when logged in', () => {
    const auth = useAuthStore()
    auth.login('https://localhost:8922', '@alice', 'tok', { slug: 'alice', name: 'Alice' })
    const wrapper = shallowMount(AppTopBar)
    expect(wrapper.find('.profile-name').text()).toBe('Alice')
    expect(wrapper.find('.btn-logout').exists()).toBe(true)
    expect(wrapper.find('.status.connected').text()).toBe('Connected')
  })
})
