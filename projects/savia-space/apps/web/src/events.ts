export interface Citation {
  id: string
  sourceIndex: number
  quote: string
  verified: boolean
  match: string
  ref: { domeId: string; resourceId: string }
}

export interface Message {
  id: string
  runId: string | null
  role: 'user' | 'assistant'
  status: string
  createdSequence: number
  text: string
  citations: Citation[]
  validation?: { status: string; [k: string]: unknown } | null
}

export interface Run {
  id: string
  state: string
  revision: number
  terminalReason: string | null
}

export interface SpaceEvent {
  sequence: number
  sessionId: string
  runId: string | null
  type: string
  payload: any
}

export interface View {
  lastSequence: number
  runs: Run[]
  messages: Message[]
}

export const TERMINAL = ['COMPLETED', 'FAILED', 'CANCELLED', 'INTERRUPTED']

export function emptyView(): View {
  return { lastSequence: 0, runs: [], messages: [] }
}

function upsertMessage(list: Message[], m: Message): Message[] {
  const i = list.findIndex((x) => x.id === m.id)
  if (i < 0) return [...list, m].sort((a, b) => a.createdSequence - b.createdSequence)
  const out = list.slice()
  out[i] = m
  return out
}

/** Pure reducer: events at or below the cursor are duplicates (backlog/live overlap) and are ignored. */
export function applyEvent(v: View, e: SpaceEvent): View {
  if (e.sequence <= v.lastSequence) return v
  const next: View = { ...v, lastSequence: e.sequence }
  const p = e.payload ?? {}
  switch (e.type) {
    case 'run.created':
      if (!next.runs.some((r) => r.id === p.runId))
        next.runs = [{ id: p.runId, state: p.state, revision: 1, terminalReason: null }, ...next.runs]
      break
    case 'run.state':
      next.runs = next.runs.map((r) =>
        r.id === e.runId ? { ...r, state: p.state, revision: p.revision, terminalReason: p.reason ?? null } : r,
      )
      break
    case 'message.created':
    case 'message.final':
      next.messages = upsertMessage(next.messages, p.message)
      break
    case 'message.delta': {
      next.messages = next.messages.map((m) =>
        m.id === p.messageId && [...m.text].length === p.offset ? { ...m, text: m.text + p.text } : m,
      )
      break
    }
  }
  return next
}

/** Complete turns only (user + assistant of the same run, both final), newest pairs first kept, in order. */
export function historyIds(messages: Message[], maxMessages: number): string[] {
  const byRun = new Map<string, Message[]>()
  for (const m of messages) if (m.runId) byRun.set(m.runId, [...(byRun.get(m.runId) ?? []), m])
  const pairs: string[][] = []
  for (const list of byRun.values()) {
    const u = list.find((x) => x.role === 'user')
    const a = list.find((x) => x.role === 'assistant')
    if (u && a && u.status === 'final' && a.status === 'final') pairs.push([u.id, a.id, String(u.createdSequence)])
  }
  pairs.sort((x, y) => Number(x[2]) - Number(y[2]))
  return pairs.slice(-Math.floor(maxMessages / 2)).flatMap(([u, a]) => [u, a])
}
