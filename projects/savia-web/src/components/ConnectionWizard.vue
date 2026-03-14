<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useBridge } from '../composables/useBridge'
import { Eye, EyeOff } from 'lucide-vue-next'

const auth = useAuthStore()
const { healthCheck } = useBridge()

const step = ref<'detecting' | 'form' | 'success'>('detecting')
const host = ref(auth.host || 'localhost')
const port = ref(auth.port || '8922')
const password = ref('')
const useTls = ref(auth.useTls)
const error = ref('')
const testing = ref(false)
const showPassword = ref(false)


async function autoDetect() {
  step.value = 'detecting'
  auth.save(host.value, port.value, auth.token, useTls.value)
  const ok = await healthCheck()
  if (ok) {
    auth.setConnected(true)
    step.value = 'success'
  } else {
    step.value = 'form'
  }
}

async function tryConnect() {
  testing.value = true
  error.value = ''
  auth.save(host.value, port.value, '', useTls.value)

  if (password.value) {
    try {
      const proto = useTls.value ? 'https' : 'http'
      const res = await fetch(`${proto}://${host.value}:${port.value}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password: password.value }),
      })
      if (res.ok) {
        const data = await res.json()
        if (data.token) auth.save(host.value, port.value, data.token, useTls.value)
      }
    } catch { /* will fail on healthCheck below */ }
  }

  const ok = await healthCheck()
  if (ok) {
    auth.setConnected(true)
    step.value = 'success'
  } else {
    error.value = 'Could not connect. Verify the Bridge is running and the settings are correct.'
  }
  testing.value = false
}

onMounted(autoDetect)
</script>

<template>
  <div class="wizard-overlay">
    <div class="wizard-card">
      <div class="wizard-logo">🦉</div>
      <h1>Welcome to Savia</h1>

      <div v-if="step === 'detecting'" class="wizard-step">
        <p>Looking for Savia Bridge...</p>
        <div class="spinner" />
      </div>

      <div v-else-if="step === 'form'" class="wizard-step">
        <p class="subtitle">Bridge not found at {{ host }}:{{ port }}. Let's configure the connection.</p>
        <div class="form-row">
          <label>Host</label>
          <input v-model="host" placeholder="localhost" />
        </div>
        <div class="form-row">
          <label>Port</label>
          <input v-model="port" placeholder="8922" />
        </div>
        <div class="form-row">
          <label>Password</label>
          <div class="input-with-toggle">
            <input v-model="password" :type="showPassword ? 'text' : 'password'" placeholder="Bridge password" />
            <button type="button" class="btn-eye" @click="showPassword = !showPassword"
              :aria-label="showPassword ? 'Hide password' : 'Show password'">
              <EyeOff v-if="showPassword" :size="18" />
              <Eye v-else :size="18" />
            </button>
          </div>
        </div>
        <label class="checkbox-row">
          <input type="checkbox" v-model="useTls" /> Use TLS (HTTPS)
        </label>
        <p v-if="error" class="error-msg">{{ error }}</p>
        <button class="btn-connect" @click="tryConnect" :disabled="testing">
          {{ testing ? 'Connecting...' : 'Connect' }}
        </button>
      </div>

      <div v-else class="wizard-step">
        <p class="success-msg">Connected to Savia Bridge</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.wizard-overlay { position: fixed; inset: 0; z-index: 1000; background: rgba(28, 26, 30, 0.6); backdrop-filter: blur(4px); display: flex; align-items: center; justify-content: center; }
.wizard-card { background: var(--savia-surface); border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow-lg); padding: 40px; width: 400px; text-align: center; }
.wizard-logo { font-size: 48px; margin-bottom: 8px; }
h1 { font-size: 22px; color: var(--savia-primary); margin-bottom: 20px; }
.subtitle { font-size: 13px; color: var(--savia-on-surface-variant); margin-bottom: 16px; }
.form-row { margin-bottom: 10px; text-align: left; }
.form-row label { display: block; font-size: 12px; color: var(--savia-on-surface-variant); margin-bottom: 3px; }
.form-row input { width: 100%; padding: 8px 12px; border: 1px solid var(--savia-outline); border-radius: var(--savia-radius); font-size: 14px; background: var(--savia-background); color: var(--savia-on-surface); }
.checkbox-row { display: flex; align-items: center; gap: 8px; font-size: 13px; margin: 8px 0 12px; cursor: pointer; }
.btn-connect { width: 100%; padding: 10px; background: var(--savia-primary); color: white; border-radius: var(--savia-radius); font-weight: 600; font-size: 14px; margin-top: 8px; }
.btn-connect:disabled { opacity: 0.6; }
.input-with-toggle { position: relative; }
.input-with-toggle input { width: 100%; padding-right: 40px; box-sizing: border-box; }
.btn-eye { position: absolute; right: 0; top: 0; height: 100%; width: 40px; display: flex; align-items: center; justify-content: center; background: none; border: none; cursor: pointer; color: var(--savia-on-surface-variant); }
.btn-eye:hover { color: var(--savia-primary); }
.error-msg { color: var(--savia-error); font-size: 12px; margin: 8px 0; }
.success-msg { color: #155724; font-size: 15px; font-weight: 600; }
.spinner { width: 32px; height: 32px; border: 3px solid var(--savia-surface-variant); border-top-color: var(--savia-primary); border-radius: 50%; animation: spin 0.8s linear infinite; margin: 16px auto; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
