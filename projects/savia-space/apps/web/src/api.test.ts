import { afterEach, describe, expect, it, vi } from 'vitest'
import { api, ApiError } from './api'

afterEach(() => vi.restoreAllMocks())

describe('api', () => {
  it('marks mutations as same-origin requests', async () => {
    const f = vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('{"ok":true}', { status: 201, headers: { 'content-type': 'application/json' } }))
    await api('POST', '/api/v1/auth/session', { pairingCode: 'x' })
    const init = f.mock.calls[0][1] as RequestInit
    expect((init.headers as Record<string, string>)['X-Space-Request']).toBe('1')
    expect(init.credentials).toBe('same-origin')
  })
  it('GET carries no mutation marker', async () => {
    const f = vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('{}', { headers: { 'content-type': 'application/json' } }))
    await api('GET', '/api/v1/projects')
    expect((f.mock.calls[0][1] as RequestInit).headers).not.toHaveProperty('X-Space-Request')
  })
  it('errors surface the envelope code', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('{"code":"CONTEXT_LIMIT","message":"no cabe"}', { status: 422, headers: { 'content-type': 'application/json' } }))
    await expect(api('POST', '/x', {})).rejects.toMatchObject({ code: 'CONTEXT_LIMIT', status: 422 })
    expect(new ApiError(401, 'UNAUTHENTICATED', '')).toBeInstanceOf(Error)
  })
})
