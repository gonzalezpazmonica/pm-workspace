import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useI18n } from '@/locales/i18n'

export interface ShieldHealth {
  daemon_up: boolean
  ner_available: boolean
  ollama_up: boolean
  ollama_models: string[]
  proxy_up: boolean
  timestamp: string
}

export type LayerStatus = 'active' | 'degraded' | 'down' | 'disabled'

export interface Layer {
  id: number
  name: string
  description: string
  tooltip: string
  status: LayerStatus
}

export type HookProfile = 'minimal' | 'standard' | 'strict' | 'ci'

export const useShieldStore = defineStore('shield', () => {
  const health = ref<ShieldHealth | null>(null)
  const shieldEnabled = ref(true)
  const hookProfile = ref<HookProfile>('standard')
  const loading = ref(false)
  const lastError = ref<string | null>(null)

  const layers = computed<Layer[]>(() => {
    const h = health.value
    const enabled = shieldEnabled.value
    const { t } = useI18n()

    function layer(id: number, status: LayerStatus): Layer {
      return {
        id,
        name: t(`layer.${id}.name`),
        description: t(`layer.${id}.desc`),
        tooltip: t(`layer.${id}.tooltip`),
        status,
      }
    }

    return [
      layer(1, enabled ? 'active' : 'disabled'),
      layer(2, !enabled ? 'disabled' : h?.ner_available ? 'active' : 'down'),
      layer(3, !enabled ? 'disabled' : h?.ollama_up ? 'active' : 'degraded'),
      layer(4, !enabled ? 'disabled' : h?.proxy_up ? 'active' : 'down'),
      layer(5, enabled ? 'active' : 'disabled'),
      layer(6, enabled ? 'active' : 'disabled'),
      layer(7, !enabled ? 'disabled' : h?.daemon_up ? 'active' : 'degraded'),
      layer(8, enabled ? 'active' : 'disabled'),
    ]
  })

  const activeCount = computed(() =>
    layers.value.filter((l) => l.status === 'active').length,
  )

  const degradedCount = computed(() =>
    layers.value.filter((l) => l.status === 'degraded').length,
  )

  const downCount = computed(() =>
    layers.value.filter((l) => l.status === 'down').length,
  )

  function updateHealth(data: ShieldHealth) {
    health.value = data
    lastError.value = null
  }

  function toggleShield() {
    shieldEnabled.value = !shieldEnabled.value
  }

  function setProfile(profile: HookProfile) {
    hookProfile.value = profile
  }

  async function loadHealth() {
    loading.value = true
    try {
      const { invoke } = await import('@tauri-apps/api/core')
      const data = await invoke<ShieldHealth>('get_shield_health')
      updateHealth(data)
    } catch {
      updateHealth({
        daemon_up: true,
        ner_available: true,
        ollama_up: false,
        ollama_models: [],
        proxy_up: true,
        timestamp: new Date().toISOString(),
      })
    } finally {
      loading.value = false
    }
  }

  async function loadConfig() {
    try {
      const { invoke } = await import('@tauri-apps/api/core')
      shieldEnabled.value = await invoke<boolean>('get_shield_enabled')
      hookProfile.value = await invoke<string>('get_hook_profile') as HookProfile
    } catch {
      // Outside Tauri — keep defaults
    }
  }

  async function invokeToggleShield() {
    try {
      const { invoke } = await import('@tauri-apps/api/core')
      const next = !shieldEnabled.value
      await invoke('set_shield_enabled', { enabled: next })
      shieldEnabled.value = next
    } catch {
      shieldEnabled.value = !shieldEnabled.value
    }
  }

  async function invokeSetProfile(profile: HookProfile) {
    try {
      const { invoke } = await import('@tauri-apps/api/core')
      await invoke('set_hook_profile', { profile })
      hookProfile.value = profile
    } catch {
      hookProfile.value = profile
    }
  }

  return {
    health,
    shieldEnabled,
    hookProfile,
    loading,
    lastError,
    layers,
    activeCount,
    degradedCount,
    downCount,
    updateHealth,
    toggleShield,
    setProfile,
    loadHealth,
    loadConfig,
    invokeToggleShield,
    invokeSetProfile,
  }
})
