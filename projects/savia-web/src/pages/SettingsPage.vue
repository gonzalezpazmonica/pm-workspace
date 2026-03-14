<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useBridge } from '../composables/useBridge'

const auth = useAuthStore()
const { healthCheck } = useBridge()
const host = ref(auth.host)
const port = ref(auth.port)
const token = ref(auth.token)
const useTls = ref(auth.useTls)
const testing = ref(false)
const testResult = ref<string | null>(null)

async function save() {
  auth.save(host.value, port.value, token.value, useTls.value)
  await test()
}

async function test() {
  testing.value = true; testResult.value = null
  const ok = await healthCheck()
  auth.setConnected(ok)
  testResult.value = ok ? 'Connected successfully!' : 'Connection failed. Check host/port/token.'
  testing.value = false
}
</script>

<template>
  <div class="settings">
    <h1>Settings</h1>
    <section class="card">
      <h2>Bridge Connection</h2>
      <div class="form-row">
        <label>Host</label>
        <input v-model="host" placeholder="localhost" />
      </div>
      <div class="form-row">
        <label>Port</label>
        <input v-model="port" placeholder="8922" />
      </div>
      <div class="form-row">
        <label>Auth Token</label>
        <input v-model="token" type="password" placeholder="Bearer token" />
      </div>
      <div class="form-row">
        <label class="checkbox-label">
          <input type="checkbox" v-model="useTls" /> Use TLS (HTTPS)
        </label>
      </div>
      <div class="actions">
        <button class="btn-primary" @click="save" :disabled="testing">Save & Test</button>
        <button class="btn-secondary" @click="test" :disabled="testing">Test Connection</button>
      </div>
      <p v-if="testResult" class="result" :class="{ ok: auth.connected }">{{ testResult }}</p>
    </section>
  </div>
</template>

<style scoped>
.settings { max-width: 600px; }
h1 { font-size: 20px; margin-bottom: 20px; }
.card { background: var(--savia-surface); padding: 24px; border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); }
h2 { font-size: 16px; margin-bottom: 16px; }
.form-row { margin-bottom: 12px; }
.form-row label { display: block; font-size: 13px; color: var(--savia-on-surface-variant); margin-bottom: 4px; }
.form-row input[type="text"], .form-row input[type="password"], .form-row input:not([type]) {
  width: 100%; padding: 8px 12px; border: 1px solid var(--savia-outline); border-radius: var(--savia-radius);
  font-size: 14px; background: var(--savia-background); color: var(--savia-on-surface);
}
.checkbox-label { display: flex; align-items: center; gap: 8px; font-size: 14px; cursor: pointer; }
.actions { display: flex; gap: 8px; margin-top: 16px; }
.btn-primary { padding: 8px 20px; background: var(--savia-primary); color: white; border-radius: var(--savia-radius); font-weight: 600; }
.btn-secondary { padding: 8px 20px; background: var(--savia-surface-variant); color: var(--savia-on-surface); border-radius: var(--savia-radius); }
.result { margin-top: 12px; font-size: 13px; color: var(--savia-error); }
.result.ok { color: #155724; }
</style>
