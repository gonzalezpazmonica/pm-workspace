import { describe, it, expect, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { useDashboardStore } from '../../stores/dashboard'
import ProjectSelector from '../../components/ProjectSelector.vue'
import type { DashboardData } from '../../types/bridge'

const baseDashboard: DashboardData = {
  greeting: 'Hello',
  projects: [
    { id: 'p1', name: 'Alpha', team: 'A', currentSprint: 'S1', health: 'green' },
    { id: 'p2', name: 'Beta', team: 'B', currentSprint: 'S2', health: 'yellow' },
  ],
  selectedProjectId: 'p1',
  sprint: null,
  myTasks: [],
  recentActivity: [],
  blockedItems: 0,
  hoursToday: 0,
}

describe('ProjectSelector', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('renders options for each project', () => {
    const store = useDashboardStore()
    store.data = { ...baseDashboard }
    const wrapper = mount(ProjectSelector)
    const options = wrapper.findAll('option')
    expect(options).toHaveLength(2)
    expect(options[0].text()).toBe('Alpha')
    expect(options[1].text()).toBe('Beta')
  })

  it('renders empty select when no projects', () => {
    const store = useDashboardStore()
    store.data = { ...baseDashboard, projects: [] }
    const wrapper = mount(ProjectSelector)
    expect(wrapper.findAll('option')).toHaveLength(0)
  })

  it('calls selectProject when selection changes', async () => {
    const store = useDashboardStore()
    store.data = { ...baseDashboard }
    const wrapper = mount(ProjectSelector)
    const select = wrapper.find('select')
    await select.setValue('p2')
    expect(store.data?.selectedProjectId).toBe('p2')
  })

  it('reflects current selectedProjectId as select value', () => {
    const store = useDashboardStore()
    store.data = { ...baseDashboard, selectedProjectId: 'p2' }
    const wrapper = mount(ProjectSelector)
    const select = wrapper.find('select')
    expect((select.element as HTMLSelectElement).value).toBe('p2')
  })

  it('renders empty when store.data is null', () => {
    const store = useDashboardStore()
    store.data = null
    const wrapper = mount(ProjectSelector)
    expect(wrapper.findAll('option')).toHaveLength(0)
  })
})
