import { describe, it, expect } from 'vitest'
import type { ProjectInfo } from '../../types/bridge'

describe('ProjectInfo type', () => {
  it('accepts valid healthy project', () => {
    const p: ProjectInfo = {
      id: 'savia-web',
      name: 'savia-web',
      path: 'projects/savia-web',
      hasClaude: true,
      hasBacklog: true,
      health: 'healthy',
      parentId: null,
      children: [],
      confidentiality: null,
    }
    expect(p.id).toBe('savia-web')
    expect(p.health).toBe('healthy')
  })

  it('accepts all health variants', () => {
    const states: ProjectInfo['health'][] = ['healthy', 'warning', 'critical', 'unknown']
    states.forEach(health => {
      const p: ProjectInfo = {
        id: 'test',
        name: 'Test',
        path: '.',
        hasClaude: false,
        hasBacklog: false,
        health,
        parentId: null,
        children: [],
        confidentiality: null,
      }
      expect(p.health).toBe(health)
    })
  })

  it('accepts workspace entry with _workspace id', () => {
    const workspace: ProjectInfo = {
      id: '_workspace',
      name: 'Savia (workspace)',
      path: '.',
      hasClaude: true,
      hasBacklog: false,
      health: 'unknown',
      parentId: null,
      children: [],
      confidentiality: null,
    }
    expect(workspace.id).toBe('_workspace')
  })

  it('accepts umbrella project with children', () => {
    const umbrella: ProjectInfo = {
      id: 'trazabios_main',
      name: 'TrazaBios',
      path: 'projects/trazabios_main',
      hasClaude: true,
      hasBacklog: false,
      health: 'healthy',
      parentId: null,
      children: ['trazabios', 'trazabios-vass', 'trazabios-pm'],
      confidentiality: null,
    }
    expect(umbrella.children).toHaveLength(3)
    expect(umbrella.parentId).toBeNull()
  })

  it('accepts child project with parentId and confidentiality', () => {
    const child: ProjectInfo = {
      id: 'trazabios-pm',
      name: 'trazabios-pm',
      path: 'projects/trazabios_main/trazabios-pm',
      hasClaude: false,
      hasBacklog: false,
      health: 'healthy',
      parentId: 'trazabios_main',
      children: [],
      confidentiality: 'N4b-PM',
    }
    expect(child.parentId).toBe('trazabios_main')
    expect(child.confidentiality).toBe('N4b-PM')
  })
})
