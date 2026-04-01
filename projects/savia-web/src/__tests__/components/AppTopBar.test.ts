import { describe, it, expect, beforeEach, vi } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { useAuthStore } from '../../stores/auth'
import { useProjectStore } from '../../stores/project'
import AppTopBar from '../../components/AppTopBar.vue'
import type { ProjectInfo } from '../../types/bridge'

const umbrellaProjects: ProjectInfo[] = [
  {
    id: '_workspace', name: 'Savia (workspace)', path: '.', hasClaude: true,
    hasBacklog: false, health: 'healthy', parentId: null, children: [], confidentiality: null,
  },
  {
    id: 'trazabios_main', name: 'TrazaBios', path: 'projects/trazabios_main', hasClaude: true,
    hasBacklog: false, health: 'healthy', parentId: null, children: ['trazabios', 'trazabios-pm'], confidentiality: null,
  },
  {
    id: 'trazabios', name: 'trazabios', path: 'projects/trazabios_main/trazabios', hasClaude: false,
    hasBacklog: true, health: 'healthy', parentId: 'trazabios_main', children: [], confidentiality: 'N4-SHARED',
  },
  {
    id: 'trazabios-pm', name: 'trazabios-pm', path: 'projects/trazabios_main/trazabios-pm', hasClaude: false,
    hasBacklog: false, health: 'healthy', parentId: 'trazabios_main', children: [], confidentiality: 'N4b-PM',
  },
  {
    id: 'savia-web', name: 'savia-web', path: 'projects/savia-web', hasClaude: true,
    hasBacklog: true, health: 'healthy', parentId: null, children: [], confidentiality: null,
  },
]

describe('AppTopBar', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
  })

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

  describe('breadcrumb', () => {
    it('does not show breadcrumb when standalone project is selected', () => {
      const store = useProjectStore()
      store.projects = [...umbrellaProjects]
      store.select('savia-web')
      const wrapper = shallowMount(AppTopBar)
      expect(wrapper.find('.breadcrumb').exists()).toBe(false)
    })

    it('does not show breadcrumb when workspace is selected', () => {
      const store = useProjectStore()
      store.projects = [...umbrellaProjects]
      store.select('_workspace')
      const wrapper = shallowMount(AppTopBar)
      expect(wrapper.find('.breadcrumb').exists()).toBe(false)
    })

    it('shows breadcrumb when subproject is selected', () => {
      const store = useProjectStore()
      store.projects = [...umbrellaProjects]
      store.select('trazabios')
      const wrapper = shallowMount(AppTopBar)
      expect(wrapper.find('.breadcrumb').exists()).toBe(true)
      expect(wrapper.find('.breadcrumb-parent').text()).toBe('TrazaBios')
      expect(wrapper.find('.breadcrumb-child').text()).toBe('trazabios')
    })

    it('shows confidentiality label in breadcrumb', () => {
      const store = useProjectStore()
      store.projects = [...umbrellaProjects]
      store.select('trazabios-pm')
      const wrapper = shallowMount(AppTopBar)
      expect(wrapper.find('.breadcrumb-conf').exists()).toBe(true)
      expect(wrapper.find('.breadcrumb-conf').text()).toBe('N4b-PM')
    })

    it('hides confidentiality badge when confidentiality is null', () => {
      const projects = [...umbrellaProjects]
      // Override: child without confidentiality
      const child = projects.find(p => p.id === 'trazabios')!
      child.confidentiality = null
      const store = useProjectStore()
      store.projects = projects
      store.select('trazabios')
      const wrapper = shallowMount(AppTopBar)
      expect(wrapper.find('.breadcrumb').exists()).toBe(true)
      expect(wrapper.find('.breadcrumb-conf').exists()).toBe(false)
    })

    it('updates breadcrumb when switching between subprojects', async () => {
      const store = useProjectStore()
      store.projects = [...umbrellaProjects]
      store.select('trazabios')
      const wrapper = shallowMount(AppTopBar)
      expect(wrapper.find('.breadcrumb-child').text()).toBe('trazabios')

      store.select('trazabios-pm')
      await wrapper.vm.$nextTick()
      expect(wrapper.find('.breadcrumb-child').text()).toBe('trazabios-pm')
    })

    it('removes breadcrumb when switching from subproject to standalone', async () => {
      const store = useProjectStore()
      store.projects = [...umbrellaProjects]
      store.select('trazabios')
      const wrapper = shallowMount(AppTopBar)
      expect(wrapper.find('.breadcrumb').exists()).toBe(true)

      store.select('savia-web')
      await wrapper.vm.$nextTick()
      expect(wrapper.find('.breadcrumb').exists()).toBe(false)
    })
  })
})
