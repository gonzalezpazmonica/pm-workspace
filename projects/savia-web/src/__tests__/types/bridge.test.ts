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
    }
    expect(workspace.id).toBe('_workspace')
  })
})
