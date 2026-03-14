import { describe, it, expect, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { createRouter, createMemoryHistory } from 'vue-router'

vi.stubGlobal('__APP_VERSION__', '0.1.0-test')

import AppSidebar from '../../components/AppSidebar.vue'

function makeRouter(currentPath = '/') {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', component: { template: '<div/>' } },
      { path: '/chat', component: { template: '<div/>' } },
      { path: '/settings', component: { template: '<div/>' } },
    ],
  })
  router.push(currentPath)
  return router
}

describe('AppSidebar', () => {
  it('renders nav links for all navigation items', async () => {
    const router = makeRouter('/')
    await router.isReady()
    const wrapper = mount(AppSidebar, {
      props: { collapsed: false },
      global: { plugins: [router] },
    })
    const links = wrapper.findAll('.nav-item')
    expect(links.length).toBeGreaterThanOrEqual(10)
  })

  it('shows labels when not collapsed', async () => {
    const router = makeRouter('/')
    await router.isReady()
    const wrapper = mount(AppSidebar, {
      props: { collapsed: false },
      global: { plugins: [router] },
    })
    expect(wrapper.find('.nav-label').exists()).toBe(true)
    expect(wrapper.find('.logo-text').exists()).toBe(true)
  })

  it('hides labels when collapsed', async () => {
    const router = makeRouter('/')
    await router.isReady()
    const wrapper = mount(AppSidebar, {
      props: { collapsed: true },
      global: { plugins: [router] },
    })
    expect(wrapper.find('.nav-label').exists()).toBe(false)
    expect(wrapper.find('.logo-text').exists()).toBe(false)
  })

  it('adds collapsed class to aside when collapsed', async () => {
    const router = makeRouter('/')
    await router.isReady()
    const wrapper = mount(AppSidebar, {
      props: { collapsed: true },
      global: { plugins: [router] },
    })
    expect(wrapper.find('.sidebar').classes()).toContain('collapsed')
  })

  it('marks Home link as active when route is /', async () => {
    const router = makeRouter('/')
    await router.isReady()
    const wrapper = mount(AppSidebar, {
      props: { collapsed: false },
      global: { plugins: [router] },
    })
    const homeLink = wrapper.findAll('.nav-item').find(
      (l) => l.text().includes('Home')
    )
    expect(homeLink?.classes()).toContain('active')
  })

  it('renders the Savia logo image', async () => {
    const router = makeRouter('/')
    await router.isReady()
    const wrapper = mount(AppSidebar, {
      props: { collapsed: false },
      global: { plugins: [router] },
    })
    expect(wrapper.find('.logo-img').exists()).toBe(true)
  })
})
