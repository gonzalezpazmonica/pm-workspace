import { describe, it, expect, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import { setActivePinia, createPinia } from 'pinia'
import { useProjectStore } from '../../stores/project'
import ProjectSelector from '../../components/ProjectSelector.vue'
import type { ProjectInfo } from '../../types/bridge'

const sampleProjects: ProjectInfo[] = [
  {
    id: '_workspace',
    name: 'Savia (workspace)',
    path: '.',
    hasClaude: true,
    hasBacklog: false,
    health: 'healthy',
  },
  {
    id: 'savia-web',
    name: 'savia-web',
    path: 'projects/savia-web',
    hasClaude: true,
    hasBacklog: true,
    health: 'healthy',
  },
  {
    id: 'proyecto-alpha',
    name: 'proyecto-alpha',
    path: 'projects/proyecto-alpha',
    hasClaude: true,
    hasBacklog: true,
    health: 'warning',
  },
]

describe('ProjectSelector', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
  })

  it('renders all projects as options', () => {
    const store = useProjectStore()
    store.projects = [...sampleProjects]
    const wrapper = mount(ProjectSelector)
    const options = wrapper.findAll('option')
    expect(options.length).toBe(3)
  })

  it('renders workspace as first option', () => {
    const store = useProjectStore()
    store.projects = [...sampleProjects]
    const wrapper = mount(ProjectSelector)
    const options = wrapper.findAll('option')
    expect(options[0].attributes('value')).toBe('_workspace')
  })

  it('shows health dot when a project is selected', () => {
    const store = useProjectStore()
    store.projects = [...sampleProjects]
    const wrapper = mount(ProjectSelector)
    expect(wrapper.find('.health-dot').exists()).toBe(true)
  })

  it('calls store.select when selection changes', async () => {
    const store = useProjectStore()
    store.projects = [...sampleProjects]
    const wrapper = mount(ProjectSelector)
    const select = wrapper.find('select')
    await select.setValue('savia-web')
    expect(store.selectedId).toBe('savia-web')
  })

  it('reflects selectedId from store as current value', () => {
    const store = useProjectStore()
    store.projects = [...sampleProjects]
    store.select('proyecto-alpha')
    const wrapper = mount(ProjectSelector)
    const select = wrapper.find('select')
    expect((select.element as HTMLSelectElement).value).toBe('proyecto-alpha')
  })

  it('renders empty select when no projects loaded', () => {
    const wrapper = mount(ProjectSelector)
    expect(wrapper.findAll('option')).toHaveLength(0)
  })
})
