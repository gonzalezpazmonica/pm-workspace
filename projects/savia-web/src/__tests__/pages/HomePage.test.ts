import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { useDashboardStore } from '../../stores/dashboard'
import type { DashboardData } from '../../types/bridge'

// Stub child components to keep tests simple
vi.mock('../../components/LoadingSpinner.vue', () => ({
  default: { template: '<div class="loading-stub"><slot /></div>' },
}))
vi.mock('../../components/EmptyState.vue', () => ({
  default: { template: '<div class="empty-stub" :data-title="title"><slot /></div>', props: ['title', 'icon', 'description'] },
}))

const { default: HomePage } = await import('../../pages/HomePage.vue')

const sampleData: DashboardData = {
  greeting: 'Good morning',
  projects: [],
  selectedProjectId: null,
  sprint: { name: 'Sprint 1', progress: 50, completedPoints: 10, totalPoints: 20, blockedItems: 0, daysRemaining: 5, velocity: 18 },
  myTasks: [
    { id: 't1', title: 'Fix login bug', state: 'Active', type: 'Bug', assignedTo: 'alice', priority: 1 },
  ],
  recentActivity: ['Deployed to staging'],
  blockedItems: 2,
  hoursToday: 3.5,
}

describe('HomePage', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('shows loading spinner while loading', () => {
    const store = useDashboardStore()
    store.loading = true
    const wrapper = mount(HomePage)
    expect(wrapper.find('.loading-stub').exists()).toBe(true)
  })

  it('shows error state when error is set', () => {
    const store = useDashboardStore()
    store.error = 'Failed to connect'
    const wrapper = mount(HomePage)
    expect(wrapper.find('.empty-stub').exists()).toBe(true)
  })

  it('renders greeting when data is loaded', () => {
    const store = useDashboardStore()
    store.data = { ...sampleData }
    const wrapper = mount(HomePage)
    expect(wrapper.find('.greeting').text()).toBe('Good morning')
  })

  it('displays sprint points in stat cards', () => {
    const store = useDashboardStore()
    store.data = { ...sampleData }
    const wrapper = mount(HomePage)
    const statValues = wrapper.findAll('.stat-value').map((e) => e.text())
    expect(statValues).toContain('10')
    expect(statValues).toContain('20')
  })

  it('displays blocked items count', () => {
    const store = useDashboardStore()
    store.data = { ...sampleData }
    const wrapper = mount(HomePage)
    const statValues = wrapper.findAll('.stat-value').map((e) => e.text())
    expect(statValues).toContain('2')
  })

  it('renders task list items', () => {
    const store = useDashboardStore()
    store.data = { ...sampleData }
    const wrapper = mount(HomePage)
    expect(wrapper.find('.task-title').text()).toBe('Fix login bug')
  })

  it('renders recent activity', () => {
    const store = useDashboardStore()
    store.data = { ...sampleData }
    const wrapper = mount(HomePage)
    expect(wrapper.find('.activity-list').text()).toContain('Deployed to staging')
  })

  it('calls store.load on mount when data is null', async () => {
    const store = useDashboardStore()
    const loadSpy = vi.spyOn(store, 'load').mockResolvedValue()
    mount(HomePage)
    expect(loadSpy).toHaveBeenCalled()
  })

  it('does not call store.load when data is already set', () => {
    const store = useDashboardStore()
    store.data = { ...sampleData }
    const loadSpy = vi.spyOn(store, 'load').mockResolvedValue()
    mount(HomePage)
    expect(loadSpy).not.toHaveBeenCalled()
  })
})
