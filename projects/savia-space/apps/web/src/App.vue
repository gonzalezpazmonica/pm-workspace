<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { api, ApiError, newKey } from './api'
import { applyEvent, emptyView, historyIds, TERMINAL, type SpaceEvent, type View } from './events'
import { bodyMatches } from './hash'
import { t } from './i18n'

const EVENT_TYPES = ['run.created', 'run.state', 'step.state', 'message.created', 'message.delta', 'message.final', 'context.dispatched']

const paired = ref<boolean | null>(null)
const error = ref('')
const pairingCode = ref('')
const projects = ref<any[]>([])
const projectId = ref('')
const catalog = ref<any>(null)
const sessions = ref<any[]>([])
const session = ref<any>(null)
const view = ref<View>(emptyView())
const selection = ref<any>(null)
const newTitle = ref('')

const query = ref('')
const candidates = ref<any[]>([])
const captures = ref<any[]>([])
const chosen = ref<string[]>([])

const presetId = ref('resume')
const profileId = ref('')
const prompt = ref('Hazlo con las fuentes seleccionadas.')
const useHistory = ref(true)
const preview = ref<any>(null)
const lastRequest = ref<any>(null)
const hashState = ref<'pending' | 'ok' | 'bad'>('pending')
const busy = ref(false)

let source: EventSource | null = null

const activeRun = computed(() => view.value.runs.find((r) => !TERMINAL.includes(r.state)))

function report(e: unknown) {
  if (e instanceof ApiError && e.code === 'UNAUTHENTICATED') paired.value = false
  error.value = e instanceof ApiError ? `${e.code}: ${e.message}` : String(e)
}

async function guarded(fn: () => Promise<void>) {
  error.value = ''
  busy.value = true
  try {
    await fn()
  } catch (e) {
    report(e)
  } finally {
    busy.value = false
  }
}

async function loadProjects() {
  try {
    projects.value = (await api('GET', '/api/v1/projects')).items
    paired.value = true
    if (!projectId.value && projects.value.length) projectId.value = projects.value[0].id
  } catch (e) {
    if (e instanceof ApiError && e.code === 'UNAUTHENTICATED') paired.value = false
    else report(e)
  }
}

const pair = () =>
  guarded(async () => {
    await api('POST', '/api/v1/auth/session', { pairingCode: pairingCode.value.trim() })
    pairingCode.value = ''
    await loadProjects()
  })

const logout = () =>
  guarded(async () => {
    closeStream()
    await api('DELETE', '/api/v1/auth/session')
    paired.value = false
    session.value = null
  })

watch(projectId, (id) =>
  guarded(async () => {
    if (!id) return
    catalog.value = await api('GET', `/api/v1/projects/${id}/catalog`)
    profileId.value = catalog.value.defaultProfile ?? catalog.value.profiles[0]?.id ?? ''
    sessions.value = (await api('GET', `/api/v1/projects/${id}/sessions`)).items
    captures.value = []
    candidates.value = []
  }),
)

const createSession = () =>
  guarded(async () => {
    const title = newTitle.value.trim() || 'Sesión'
    const r = await api('POST', `/api/v1/projects/${projectId.value}/sessions`, { title, idempotencyKey: newKey('s') })
    newTitle.value = ''
    sessions.value = [r.session, ...sessions.value]
    await openSession(r.session.id)
  })

function closeStream() {
  source?.close()
  source = null
}

async function loadSnapshot(id: string) {
  const snap = await api('GET', `/api/v1/sessions/${id}/snapshot`)
  session.value = snap.session
  selection.value = snap.selection
  view.value = { lastSequence: snap.watermark, runs: snap.runs, messages: snap.messages }
  return snap.watermark as number
}

/** Snapshot, then subscribe after its watermark; the reducer drops overlap by sequence. */
async function openSession(id: string) {
  closeStream()
  preview.value = null
  // A capture belongs to the session where it is selected; never carry them across sessions.
  captures.value = []
  chosen.value = []
  candidates.value = []
  const watermark = await loadSnapshot(id)
  const es = new EventSource(`/api/v1/sessions/${id}/events?after=${watermark}`)
  const onEvent = (msg: MessageEvent) => {
    const ev = JSON.parse(msg.data) as SpaceEvent
    if (ev.sessionId !== id) return
    view.value = applyEvent(view.value, ev)
    if (ev.type === 'run.state' && TERMINAL.includes(ev.payload.state)) void refreshSession(id)
  }
  for (const type of EVENT_TYPES) es.addEventListener(type, onEvent as EventListener)
  es.onerror = () => {
    // The browser reconnects with Last-Event-ID; a closed stream means the server refused: resync.
    if (es.readyState === EventSource.CLOSED && source === es) setTimeout(() => void guarded(() => openSession(id)), 2000)
  }
  source = es
}

async function refreshSession(id: string) {
  const snap = await api('GET', `/api/v1/sessions/${id}/snapshot`)
  session.value = snap.session
}

const select = (id: string) => guarded(() => openSession(id))

const search = () =>
  guarded(async () => {
    if (!query.value.trim()) return
    const r = await api('POST', `/api/v1/projects/${projectId.value}/sources/search`, { queries: [query.value.trim()] })
    candidates.value = r.candidates
  })

const capture = (c: any) =>
  guarded(async () => {
    const r = await api('POST', `/api/v1/projects/${projectId.value}/sources/capture`, { candidateId: c.id })
    captures.value = [...captures.value, r]
    chosen.value = [...chosen.value, r.captureId]
  })

const saveSelection = () =>
  guarded(async () => {
    const r = await api('PUT', `/api/v1/sessions/${session.value.id}/selection`, {
      captureIds: chosen.value,
      expectedRevision: selection.value?.revision ?? 0,
      idempotencyKey: newKey('sel'),
    })
    selection.value = r
    await refreshSession(session.value.id)
  })

const prepare = () =>
  guarded(async () => {
    const pv = catalog.value.presets.find((p: any) => p.id === presetId.value)
    const req = {
      presetId: presetId.value,
      presetVersion: pv.version,
      prompt: prompt.value,
      selectionId: selection.value.id,
      selectionRevision: selection.value.revision,
      agentRef: catalog.value.agents[0].ref,
      skillRefs: [],
      historyMessageIds: useHistory.value ? historyIds(view.value.messages, 16) : [],
      providerProfileId: profileId.value,
      expectedSessionRevision: session.value.revision,
      idempotencyKey: newKey('turn'),
    }
    hashState.value = 'pending'
    preview.value = await api('POST', `/api/v1/sessions/${session.value.id}/prepare`, req)
    lastRequest.value = req
    hashState.value = (await bodyMatches(preview.value.bodyText, preview.value.payloadHash)) ? 'ok' : 'bad'
  })

const send = () =>
  guarded(async () => {
    if (hashState.value !== 'ok') return
    const p = preview.value
    await api('POST', `/api/v1/sessions/${session.value.id}/runs`, {
      ...lastRequest.value,
      approvedPreviewId: p.id,
      approvedManifestHash: p.manifestHash,
      approvedPayloadHash: p.payloadHash,
    })
    preview.value = null
  })

const stop = () => guarded(async () => void (activeRun.value && (await api('POST', `/api/v1/runs/${activeRun.value.id}/cancel`, {}))))

const canPrepare = computed(
  () => !!session.value && !!selection.value?.sources?.length && !!catalog.value && !activeRun.value && !busy.value,
)

const minSources = computed(() => catalog.value?.presets.find((p: any) => p.id === presetId.value)?.minimumSources ?? 1)

const prettyBody = computed(() => {
  if (!preview.value) return ''
  try {
    return JSON.stringify(JSON.parse(preview.value.bodyText), null, 2)
  } catch {
    return preview.value.bodyText
  }
})

onMounted(loadProjects)
onUnmounted(closeStream)
</script>

<template>
  <header class="top">
    <h1>{{ t.title }}</h1>
    <button v-if="paired" class="link" @click="logout">{{ t.logout }}</button>
  </header>

  <p v-if="error" class="error" role="alert">{{ t.error }}: {{ error }}</p>

  <main v-if="paired === false" class="pair">
    <h2>{{ t.pairTitle }}</h2>
    <p>{{ t.pairHelp }}</p>
    <form @submit.prevent="pair">
      <label>{{ t.pairCode }} <input v-model="pairingCode" autocomplete="one-time-code" required /></label>
      <button :disabled="busy">{{ t.pair }}</button>
    </form>
  </main>

  <main v-else-if="paired" class="layout">
    <aside class="side">
      <label>{{ t.project }}
        <select v-model="projectId">
          <option v-for="p in projects" :key="p.id" :value="p.id" :disabled="p.state !== 'READY'">{{ p.title }}</option>
        </select>
      </label>
      <h2>{{ t.sessions }}</h2>
      <form class="row" @submit.prevent="createSession">
        <input v-model="newTitle" :placeholder="t.newSessionTitle" maxlength="120" />
        <button :disabled="busy || !projectId">{{ t.create }}</button>
      </form>
      <ul class="list">
        <li v-for="s in sessions" :key="s.id">
          <button class="link" :class="{ current: session?.id === s.id }" @click="select(s.id)">{{ s.title }}</button>
        </li>
      </ul>
    </aside>

    <section v-if="!session" class="empty">{{ t.empty }}</section>

    <template v-else>
      <section class="panel sources">
        <h2>{{ t.sources }}</h2>
        <form class="row" @submit.prevent="search">
          <input v-model="query" :placeholder="t.searchPlaceholder" maxlength="512" />
          <button :disabled="busy">{{ t.search }}</button>
        </form>
        <ul class="list">
          <li v-for="c in candidates" :key="c.id">
            <strong>{{ c.heading }}</strong> <small>{{ c.domeId }}/{{ c.resourceId }}</small>
            <small v-if="c.indexState === 'DEGRADED'" class="warn"> · {{ t.degraded }}</small>
            <p class="snippet">{{ c.snippet }}</p>
            <button :disabled="busy || captures.some((x) => x.ref.resourceId === c.resourceId)" @click="capture(c)">{{ t.capture }}</button>
          </li>
        </ul>
        <template v-if="captures.length">
          <h3>{{ t.captured }}</h3>
          <ul class="list">
            <li v-for="c in captures" :key="c.captureId">
              <label><input v-model="chosen" type="checkbox" :value="c.captureId" /> {{ c.title }} <small>({{ c.coverage }})</small></label>
            </li>
          </ul>
          <button :disabled="busy || !chosen.length || chosen.length > 8" @click="saveSelection">{{ t.saveSelection }}</button>
        </template>
        <h3>{{ t.selection }}</h3>
        <ol v-if="selection?.sources?.length" start="0">
          <li v-for="s in selection.sources" :key="s.captureId">{{ s.title }} <small>{{ s.ref.domeId }}/{{ s.ref.resourceId }}</small></li>
        </ol>
        <p v-else class="muted">{{ t.noSelection }}</p>
      </section>

      <section class="panel chat">
        <h2>{{ session.title }}</h2>
        <div class="messages">
          <article v-for="m in view.messages" :key="m.id" :class="['msg', m.role]">
            <header>
              <span>{{ m.role === 'user' ? 'Tú' : 'Savia' }}</span>
              <small>{{ m.status }}</small>
              <small v-if="m.validation" :class="m.validation.status === 'PASS' ? 'ok' : 'warn'">{{ t.validation }}: {{ m.validation.status }}</small>
            </header>
            <p class="text">{{ m.text }}</p>
            <details v-if="m.citations?.length">
              <summary>{{ t.citations }} ({{ m.citations.length }})</summary>
              <ul class="list">
                <li v-for="c in m.citations" :key="c.id">
                  [{{ c.sourceIndex }}] «{{ c.quote }}»
                  <small :class="c.verified ? 'ok' : 'warn'">{{ c.verified ? t.verified : t.unverified }} · {{ c.match }}</small>
                </li>
              </ul>
            </details>
            <details v-if="m.validation && m.validation.status !== 'PASS'">
              <summary>{{ t.validation }}</summary>
              <pre>{{ JSON.stringify(m.validation, null, 2) }}</pre>
            </details>
          </article>
        </div>
        <ul class="runs">
          <li v-for="r in view.runs" :key="r.id">
            {{ t.states[r.state] ?? r.state }}<span v-if="r.terminalReason"> · {{ r.terminalReason }}</span>
            <a v-if="r.state === 'COMPLETED'" :href="`/api/v1/runs/${r.id}/export?format=markdown`" target="_blank" rel="noopener">{{ t.export }}</a>
          </li>
        </ul>
        <button v-if="activeRun" class="danger" @click="stop">{{ t.stop }}</button>

        <form v-if="!preview" class="composer" @submit.prevent="prepare">
          <div class="row">
            <label>{{ t.preset }}
              <select v-model="presetId">
                <option v-for="p in catalog?.presets ?? []" :key="p.id" :value="p.id">{{ t.presets[p.id] ?? p.id }}</option>
              </select>
            </label>
            <label>{{ t.profile }}
              <select v-model="profileId">
                <option v-for="p in catalog?.profiles ?? []" :key="p.id" :value="p.id">{{ p.id }} ({{ p.model }})</option>
              </select>
            </label>
            <label><input v-model="useHistory" type="checkbox" /> {{ t.includeHistory }}</label>
          </div>
          <label>{{ t.prompt }} <textarea v-model="prompt" rows="3" maxlength="16384" /></label>
          <button :disabled="!canPrepare || (selection?.sources?.length ?? 0) < minSources">{{ t.prepare }}</button>
        </form>

        <section v-else class="inspector" aria-live="polite">
          <h3>{{ t.inspector }}</h3>
          <p :class="hashState === 'ok' ? 'ok' : hashState === 'bad' ? 'error' : 'muted'">
            {{ hashState === 'ok' ? t.hashOk : hashState === 'bad' ? t.hashBad : t.hashPending }}
          </p>
          <p class="muted">
            {{ preview.manifest.tokenCount }} {{ t.tokens }} · {{ preview.manifest.byteCount }} {{ t.bytes }} · {{ t.expires }} {{ preview.expiresAt }}
          </p>
          <ul class="list">
            <li v-for="(e, i) in preview.manifest.entries" :key="i">
              {{ e.role }} · {{ t.trust[e.trust] ?? e.trust }} · {{ e.byteCount }} {{ t.bytes }}
              <small v-if="e.ref">{{ e.ref.domeId }}/{{ e.ref.resourceId }}</small>
            </li>
          </ul>
          <details>
            <summary>payloadHash {{ preview.payloadHash }}</summary>
            <pre class="body">{{ prettyBody }}</pre>
          </details>
          <div class="row">
            <button :disabled="hashState !== 'ok' || busy" @click="send">{{ t.send }}</button>
            <button class="link" @click="preview = null">{{ t.discard }}</button>
          </div>
        </section>
      </section>
    </template>
  </main>
</template>
