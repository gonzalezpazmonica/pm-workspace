<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '../stores/auth'
import type { TeamMember, TeamResponse } from '../types/bridge'
import RegisterWizard from './RegisterWizard.vue'

const auth = useAuthStore()
const serverUrl = ref(auth.serverUrl || 'http://localhost:8922')
const username = ref(auth.username || '')
const token = ref(auth.token || '')
const error = ref('')
const loading = ref(false)
const showRegister = ref(false)
const slug = ref('')

function timedFetch(url: string, opts: RequestInit = {}, ms = 8000): Promise<Response> {
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), ms)
  return fetch(url, { ...opts, signal: ctrl.signal }).finally(() => clearTimeout(timer))
}

async function connect() {
  error.value = ''
  if (!username.value.startsWith('@')) { error.value = 'Username must start with @'; return }
  loading.value = true
  slug.value = username.value.replace(/^@/, '')

  try {
    const healthRes = await timedFetch(`${serverUrl.value}/health`)
    if (!healthRes.ok) { error.value = 'Bridge not reachable at this URL'; loading.value = false; return }

    const teamRes = await timedFetch(`${serverUrl.value}/team`, {
      headers: { 'Authorization': `Bearer ${token.value}` },
    })
    if (!teamRes.ok) { error.value = 'Invalid token or unauthorized'; loading.value = false; return }

    const team: TeamResponse = await teamRes.json()
    const member = team.members.find((m: TeamMember) => m.slug === slug.value) || null

    if (member) {
      auth.login(serverUrl.value, username.value, token.value, member)
    } else {
      auth.save(new URL(serverUrl.value).hostname, new URL(serverUrl.value).port || '8922', token.value, serverUrl.value.startsWith('https'))
      auth.token = token.value
      auth.serverUrl = serverUrl.value
      showRegister.value = true
    }
  } catch (e: unknown) {
    const msg = e instanceof DOMException && e.name === 'AbortError'
      ? 'Connection timed out. Is the Bridge running?'
      : 'Could not connect. Check the server URL and try again.'
    error.value = msg
  }
  loading.value = false
}

function onRegistered(member: TeamMember) {
  showRegister.value = false
  auth.login(serverUrl.value, username.value, token.value, member)
}
</script>

<template>
  <div class="login-overlay">
    <RegisterWizard v-if="showRegister" :slug="slug" :server-url="serverUrl"
      :token="token" @registered="onRegistered" @cancel="showRegister = false" />
    <div v-else class="login-card glass-card">
      <img src="/savia-logo.png" alt="Savia" class="login-logo" />
      <h1>Savia</h1>
      <p class="login-subtitle">Connect to your PM-Workspace</p>
      <div class="form-row">
        <label>Server URL</label>
        <input v-model="serverUrl" placeholder="http://localhost:8922" />
      </div>
      <div class="form-row">
        <label>Username</label>
        <input v-model="username" placeholder="@your-handle" />
      </div>
      <div class="form-row">
        <label>Access Token</label>
        <input v-model="token" type="password" placeholder="Bearer token from ~/.savia/bridge/auth_token" />
      </div>
      <p v-if="error" class="error-msg">{{ error }}</p>
      <button class="btn-connect" @click="connect" :disabled="loading">
        {{ loading ? 'Connecting...' : 'Connect' }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.login-overlay {
  position: fixed; inset: 0; z-index: 1000;
  background: var(--savia-background);
  display: flex; align-items: center; justify-content: center;
}
.login-card { padding: 40px; width: 420px; text-align: center; }
.login-logo { width: 80px; height: 80px; margin-bottom: 8px; }
h1 { font-size: 26px; color: var(--savia-primary); margin-bottom: 4px; }
.login-subtitle { font-size: 13px; color: var(--savia-on-surface-variant); margin-bottom: 24px; }
.form-row { margin-bottom: 12px; text-align: left; }
.form-row label { display: block; font-size: 12px; color: var(--savia-on-surface-variant); margin-bottom: 3px; }
.form-row input {
  width: 100%; padding: 10px 12px; border: 1px solid var(--savia-outline);
  border-radius: var(--savia-radius); font-size: 14px;
  background: var(--savia-background); color: var(--savia-on-surface);
  transition: border-color var(--savia-transition);
}
.form-row input:focus { border-color: var(--savia-primary); outline: none; }
.btn-connect {
  width: 100%; padding: 12px; background: var(--savia-primary); color: white;
  border-radius: var(--savia-radius); font-weight: 600; font-size: 15px; margin-top: 16px;
  transition: background var(--savia-transition), box-shadow var(--savia-transition);
  box-shadow: 0 2px 8px rgba(107, 76, 154, 0.3);
}
.btn-connect:hover:not(:disabled) { background: var(--savia-primary-dark); }
.btn-connect:disabled { opacity: 0.6; cursor: not-allowed; }
.error-msg { color: var(--savia-error); font-size: 12px; margin: 8px 0; }
</style>
