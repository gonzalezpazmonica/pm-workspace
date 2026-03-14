import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { createRouter, createMemoryHistory } from 'vue-router'
import { setActivePinia, createPinia } from 'pinia'

vi.mock('../../../components/ProjectSelector.vue', () => ({
  default: { template: '<div class="project-selector-stub" />' },
}))

const { default: ReportsLayout } = await import('../../../pages/reports/ReportsLayout.vue')

function makeRouter(path = '/reports/sprint') {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/reports/sprint', component: { template: '<div>sprint</div>' } },
      { path: '/reports/board-flow', component: { template: '<div>board</div>' } },
      { path: '/reports/team-workload', component: { template: '<div>workload</div>' } },
      { path: '/reports/portfolio', component: { template: '<div>portfolio</div>' } },
      { path: '/reports/dora', component: { template: '<div>dora</div>' } },
      { path: '/reports/quality', component: { template: '<div>quality</div>' } },
      { path: '/reports/debt', component: { template: '<div>debt</div>' } },
    ],
  })
  router.push(path)
  return router
}

describe('ReportsLayout', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('renders without errors', async () => {
    const router = makeRouter()
    await router.isReady()
    const wrapper = mount(ReportsLayout, { global: { plugins: [router] } })
    expect(wrapper.exists()).toBe(true)
  })

  it('renders the Reports heading', async () => {
    const router = makeRouter()
    await router.isReady()
    const wrapper = mount(ReportsLayout, { global: { plugins: [router] } })
    expect(wrapper.find('h1').text()).toBe('Reports')
  })

  it('renders all 7 navigation tabs', async () => {
    const router = makeRouter()
    await router.isReady()
    const wrapper = mount(ReportsLayout, { global: { plugins: [router] } })
    const tabs = wrapper.findAll('.tab')
    expect(tabs.length).toBe(7)
  })

  it('renders the reports-content container for router-view', async () => {
    const router = makeRouter()
    await router.isReady()
    const wrapper = mount(ReportsLayout, { global: { plugins: [router] } })
    expect(wrapper.find('.reports-content').exists()).toBe(true)
  })
})
