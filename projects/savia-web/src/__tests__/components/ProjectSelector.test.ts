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
    parentId: null,
    children: [],
    confidentiality: null,
  },
  {
    id: 'savia-web',
    name: 'savia-web',
    path: 'projects/savia-web',
    hasClaude: true,
    hasBacklog: true,
    health: 'healthy',
    parentId: null,
    children: [],
    confidentiality: null,
  },
  {
    id: 'proyecto-alpha',
    name: 'proyecto-alpha',
    path: 'projects/proyecto-alpha',
    hasClaude: true,
    hasBacklog: true,
    health: 'warning',
    parentId: null,
    children: [],
    confidentiality: null,
  },
]

const projectsWithUmbrella: ProjectInfo[] = [
  ...sampleProjects,
  {
    id: 'trazabios_main',
    name: 'TrazaBios',
    path: 'projects/trazabios_main',
    hasClaude: true,
    hasBacklog: false,
    health: 'healthy',
    parentId: null,
    children: ['trazabios', 'trazabios-pm'],
    confidentiality: null,
  },
  {
    id: 'trazabios',
    name: 'trazabios',
    path: 'projects/trazabios_main/trazabios',
    hasClaude: false,
    hasBacklog: true,
    health: 'healthy',
    parentId: 'trazabios_main',
    children: [],
    confidentiality: 'N4-SHARED',
  },
  {
    id: 'trazabios-pm',
    name: 'trazabios-pm',
    path: 'projects/trazabios_main/trazabios-pm',
    hasClaude: false,
    hasBacklog: false,
    health: 'healthy',
    parentId: 'trazabios_main',
    children: [],
    confidentiality: 'N4b-PM',
  },
]

describe('ProjectSelector', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
  })

  it('renders standalone projects as options', () => {
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

  it('renders optgroup for umbrella projects', () => {
    const store = useProjectStore()
    store.projects = [...projectsWithUmbrella]
    const wrapper = mount(ProjectSelector)
    const groups = wrapper.findAll('optgroup')
    expect(groups.length).toBe(1)
    expect(groups[0].attributes('label')).toBe('TrazaBios')
  })

  it('renders children inside optgroup with confidentiality labels', () => {
    const store = useProjectStore()
    store.projects = [...projectsWithUmbrella]
    const wrapper = mount(ProjectSelector)
    const group = wrapper.find('optgroup')
    const children = group.findAll('option')
    expect(children.length).toBe(2)
    expect(children[0].text()).toContain('trazabios')
    expect(children[0].text()).toContain('N4-SHARED')
    expect(children[1].text()).toContain('trazabios-pm')
    expect(children[1].text()).toContain('N4b-PM')
  })

  it('standalone projects remain outside optgroups', () => {
    const store = useProjectStore()
    store.projects = [...projectsWithUmbrella]
    const wrapper = mount(ProjectSelector)
    const allOptions = wrapper.findAll('option')
    const groupedOptions = wrapper.findAll('optgroup option')
    // Total options minus grouped = standalone options
    const standaloneCount = allOptions.length - groupedOptions.length
    expect(standaloneCount).toBe(3) // _workspace, savia-web, proyecto-alpha
  })
})
