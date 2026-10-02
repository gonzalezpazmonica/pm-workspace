import { describe, expect, it } from 'vitest'
import { applyEvent, emptyView, type SpaceEvent } from './events'

const sid = 's1'
const ev = (sequence: number, type: string, payload: unknown, runId: string | null = 'r1'): SpaceEvent =>
  ({ protocolVersion: 1, eventId: `e${sequence}`, sequence, sessionId: sid, runId, occurredAt: '', type, payload }) as SpaceEvent

const msg = (status: string, text = '') => ({
  id: 'm1', sessionId: sid, runId: 'r1', role: 'assistant', status, createdSequence: 2, text, citations: [], manifestId: null,
})

describe('applyEvent', () => {
  it('builds runs and streams deltas in order', () => {
    let v = emptyView()
    v = applyEvent(v, ev(1, 'run.created', { runId: 'r1', state: 'QUEUED' }))
    v = applyEvent(v, ev(2, 'message.created', { message: msg('STREAMING') }))
    v = applyEvent(v, ev(3, 'message.delta', { messageId: 'm1', offset: 0, text: 'Hola' }))
    v = applyEvent(v, ev(4, 'message.delta', { messageId: 'm1', offset: 4, text: ' mundo' }))
    v = applyEvent(v, ev(5, 'run.state', { state: 'RUNNING', revision: 2, reason: null }))
    expect(v.messages[0].text).toBe('Hola mundo')
    expect(v.runs[0].state).toBe('RUNNING')
    expect(v.lastSequence).toBe(5)
  })
  it('ignores duplicates and old sequences', () => {
    let v = emptyView()
    v = applyEvent(v, ev(1, 'message.created', { message: msg('STREAMING') }))
    v = applyEvent(v, ev(2, 'message.delta', { messageId: 'm1', offset: 0, text: 'a' }))
    v = applyEvent(v, ev(2, 'message.delta', { messageId: 'm1', offset: 0, text: 'a' }))
    expect(v.messages[0].text).toBe('a')
  })
  it('drops a delta whose offset does not continue the text', () => {
    let v = emptyView()
    v = applyEvent(v, ev(1, 'message.created', { message: msg('STREAMING') }))
    v = applyEvent(v, ev(2, 'message.delta', { messageId: 'm1', offset: 9, text: 'x' }))
    expect(v.messages[0].text).toBe('')
  })
  it('final replaces the streamed message', () => {
    let v = emptyView()
    v = applyEvent(v, ev(1, 'message.created', { message: msg('STREAMING') }))
    v = applyEvent(v, ev(2, 'message.final', { message: { ...msg('FINAL', 'ok'), validation: { status: 'PASS' } } }))
    expect(v.messages[0].status).toBe('FINAL')
    expect(v.messages[0].validation).toEqual({ status: 'PASS' })
  })
  it('unknown types only advance the cursor', () => {
    const v = applyEvent(emptyView(), ev(7, 'future.thing', {}))
    expect(v.lastSequence).toBe(7)
  })
})

import { historyIds } from './events'

describe('historyIds', () => {
  const m = (id: string, runId: string, role: 'user' | 'assistant', status: string, seq: number) =>
    ({ id, runId, role, status, createdSequence: seq, text: '', citations: [] })
  it('keeps only complete final turns, newest pairs up to the limit', () => {
    const msgs = [
      m('u1', 'r1', 'user', 'final', 1), m('a1', 'r1', 'assistant', 'final', 2),
      m('u2', 'r2', 'user', 'final', 3), m('a2', 'r2', 'assistant', 'failed', 4),
      m('u3', 'r3', 'user', 'final', 5), m('a3', 'r3', 'assistant', 'final', 6),
    ]
    expect(historyIds(msgs, 16)).toEqual(['u1', 'a1', 'u3', 'a3'])
    expect(historyIds(msgs, 2)).toEqual(['u3', 'a3'])
  })
})
