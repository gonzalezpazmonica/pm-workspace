<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useShieldStore } from '@/stores/shield'
import { useShieldPolling } from '@/composables/useShieldPolling'
import { useI18n } from '@/locales/i18n'
import LayerCard from './shared/LayerCard.vue'
import ShieldToggle from './shared/ShieldToggle.vue'
import ProfileSelector from './shared/ProfileSelector.vue'

interface AuditEntry { ts: string; layer: number; file: string; verdict: string; detail: string }
interface TestResult { layer: number; name: string; passed: boolean; detail: string; duration_ms: number }

const store = useShieldStore()
const { t } = useI18n()
const auditEntries = ref<AuditEntry[]>([])
const testResults = ref<TestResult[]>([])
const testing = ref(false)
const testProgress = ref(0)
useShieldPolling()
store.loadConfig()

onMounted(async () => {
  try {
    const { invoke } = await import('@tauri-apps/api/core')
    auditEntries.value = await invoke<AuditEntry[]>('get_recent_audit', { limit: 15 })
  } catch { /* outside Tauri */ }
})

async function runTest() {
  testing.value = true; testProgress.value = 5; testResults.value = []
  try {
    const { invoke } = await import('@tauri-apps/api/core')
    const iv = setInterval(() => { if (testProgress.value < 90) testProgress.value += 3 }, 500)
    testResults.value = await invoke<TestResult[]>('run_shield_test')
    clearInterval(iv); testProgress.value = 100
  } catch { testResults.value = [] }
  finally { setTimeout(() => { testing.value = false }, 1500) }
}

function verdictColor(v: string): string {
  if (v === 'BLOCKED' || v === 'LEAK_DETECTED') return 'var(--savia-error)'
  if (v === 'ALLOWED' || v === 'WHITELISTED') return 'var(--savia-success)'
  return 'var(--savia-on-surface-variant)'
}

function shortPath(p: string): string {
  const parts = p.replace(/\\/g, '/').split('/')
  return parts.slice(-2).join('/')
}
</script>

<template>
  <div class="shield-dashboard">
    <div class="shield-dashboard__controls">
      <ShieldToggle :model-value="store.shieldEnabled" @update:model-value="store.invokeToggleShield()" />
      <ProfileSelector :model-value="store.hookProfile" @update:model-value="store.invokeSetProfile($event)" />
    </div>

    <div class="shield-dashboard__summary">
      <div class="summary-chip summary-chip--active">
        <span class="summary-chip__count">{{ store.activeCount }}</span>
        <span class="summary-chip__label">{{ t('shield.active') }}</span>
      </div>
      <div class="summary-chip summary-chip--degraded">
        <span class="summary-chip__count">{{ store.degradedCount }}</span>
        <span class="summary-chip__label">{{ t('shield.degraded') }}</span>
      </div>
      <div class="summary-chip summary-chip--down">
        <span class="summary-chip__count">{{ store.downCount }}</span>
        <span class="summary-chip__label">{{ t('shield.down') }}</span>
      </div>
      <button class="shield-dashboard__test-btn" :disabled="testing" @click="runTest">
        {{ testing ? t('shield.testing') : t('shield.runTest') }}
      </button>
    </div>
    <div v-if="testing" class="shield-dashboard__progress">
      <div class="shield-dashboard__progress-bar" :style="{ width: testProgress + '%' }" />
    </div>
    <div v-if="testResults.length" class="shield-dashboard__test-results">
      <div v-for="r in testResults" :key="r.layer" class="shield-dashboard__test-item">
        <span class="shield-dashboard__test-dot" :class="r.passed ? 'shield-dashboard__test-dot--pass' : 'shield-dashboard__test-dot--fail'" />
        <span class="shield-dashboard__test-layer">{{ r.layer }}. {{ r.name }}</span>
        <span class="shield-dashboard__test-detail">{{ r.detail }}</span>
      </div>
    </div>
    <div class="shield-dashboard__grid">
      <LayerCard v-for="layer in store.layers" :key="layer.id" :layer="layer" />
    </div>

    <!-- Real audit feed -->
    <div v-if="auditEntries.length" class="glass-card shield-dashboard__audit">
      <span class="shield-dashboard__audit-label">{{ t('shield.auditFeed') }}</span>
      <div class="shield-dashboard__audit-list">
        <div v-for="(e, i) in auditEntries" :key="i" class="shield-dashboard__audit-item">
          <span class="shield-dashboard__audit-dot" :style="{ background: verdictColor(e.verdict) }" />
          <span class="shield-dashboard__audit-verdict">{{ e.verdict }}</span>
          <span class="shield-dashboard__audit-layer">L{{ e.layer }}</span>
          <span class="shield-dashboard__audit-file">{{ shortPath(e.file) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.shield-dashboard { display: flex; flex-direction: column; gap: var(--space-3); padding: var(--space-4); overflow-y: auto; flex: 1; }
.shield-dashboard__controls { display: flex; align-items: center; justify-content: space-between; }
.shield-dashboard__summary { display: flex; gap: var(--space-3); }
.summary-chip { display: flex; align-items: center; gap: var(--space-1); padding: var(--space-1) var(--space-3); border-radius: var(--savia-radius); font-size: 12px; }
.summary-chip__count { font-weight: 700; font-size: 14px; }
.summary-chip__label { font-weight: 500; color: var(--savia-on-surface-variant); }
.summary-chip--active { background: var(--savia-success-container); color: var(--savia-success); }
.summary-chip--degraded { background: var(--savia-warning-container); color: var(--savia-warning); }
.summary-chip--down { background: var(--savia-error-container); color: var(--savia-error); }
.shield-dashboard__test-btn { padding: 4px 12px; border: 1px solid var(--savia-primary); border-radius: var(--savia-radius); background: transparent; color: var(--savia-primary); font-size: 11px; font-weight: 600; cursor: pointer; font-family: inherit; margin-left: auto; transition: all var(--savia-transition); }
.shield-dashboard__test-btn:hover { background: var(--savia-primary); color: #fff; }
.shield-dashboard__test-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.shield-dashboard__progress { height: 3px; background: var(--savia-surface-variant); border-radius: 2px; overflow: hidden; }
.shield-dashboard__progress-bar { height: 100%; background: var(--savia-primary); transition: width 0.2s; border-radius: 2px; }
.shield-dashboard__test-results { display: flex; flex-direction: column; gap: 2px; }
.shield-dashboard__test-item { display: flex; align-items: center; gap: var(--space-2); padding: 3px var(--space-2); font-size: 11px; }
.shield-dashboard__test-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.shield-dashboard__test-dot--pass { background: var(--savia-success); }
.shield-dashboard__test-dot--fail { background: var(--savia-error); }
.shield-dashboard__test-layer { font-weight: 600; min-width: 110px; }
.shield-dashboard__test-detail { color: var(--savia-on-surface-variant); }
.shield-dashboard__grid { display: flex; flex-direction: column; gap: var(--space-2); }
.shield-dashboard__audit { padding: var(--space-3); }
.shield-dashboard__audit-label { font-size: 10px; font-weight: 700; color: var(--savia-on-surface-variant); display: block; margin-bottom: var(--space-2); }
.shield-dashboard__audit-list { max-height: 180px; overflow-y: auto; }
.shield-dashboard__audit-item { display: flex; align-items: center; gap: var(--space-2); padding: 3px 0; font-size: 11px; border-bottom: 1px solid var(--savia-glass-border); }
.shield-dashboard__audit-dot { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
.shield-dashboard__audit-verdict { font-weight: 700; font-size: 10px; min-width: 60px; }
.shield-dashboard__audit-layer { font-size: 9px; padding: 1px 4px; border-radius: 4px; background: var(--savia-surface-variant); }
.shield-dashboard__audit-file { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-family: monospace; font-size: 10px; color: var(--savia-on-surface-variant); }
</style>
