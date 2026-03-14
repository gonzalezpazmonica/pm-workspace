import { describe, it, expect, beforeEach } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { useAuthStore } from '../../stores/auth'
import MainLayout from '../../layouts/MainLayout.vue'

const stubs = {
  AppSidebar: { template: '<aside class="sidebar-stub" />', props: ['collapsed'] },
  AppTopBar: { template: '<header class="topbar-stub" />', emits: ['toggle-sidebar'] },
  LoginPage: { template: '<div class="login-stub" />' },
  RouterView: { template: '<div class="rv-stub" />' },
}

describe('MainLayout', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    document.cookie = 'savia_session=; path=/; max-age=0'
  })

  it('shows login page when not logged in', () => {
    const wrapper = shallowMount(MainLayout, { global: { stubs } })
    expect(wrapper.find('.login-stub').exists()).toBe(true)
  })

  it('shows layout when logged in', () => {
    const auth = useAuthStore()
    auth.login('http://localhost:8922', '@alice', 'tok', { slug: 'alice', name: 'Alice' })
    const wrapper = shallowMount(MainLayout, { global: { stubs } })
    expect(wrapper.find('.layout').exists()).toBe(true)
    expect(wrapper.find('.login-stub').exists()).toBe(false)
  })
})
