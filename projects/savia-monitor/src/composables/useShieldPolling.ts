import { onMounted, onUnmounted } from 'vue'
import { useShieldStore, type ShieldHealth } from '@/stores/shield'

/**
 * Composable that listens to the 'shield-health' Tauri event
 * and updates the shield store on each emission.
 *
 * Falls back to periodic polling when running outside Tauri
 * (e.g. during vite dev without the Tauri shell).
 */
export function useShieldPolling() {
  const store = useShieldStore()
  let unlisten: (() => void) | null = null
  let pollTimer: ReturnType<typeof setInterval> | null = null

  async function startListening() {
    try {
      // Dynamic import so vite dev doesn't crash when @tauri-apps/api
      // is unavailable (pure browser preview).
      const { listen } = await import('@tauri-apps/api/event')

      unlisten = (await listen<ShieldHealth>('shield-health', (event) => {
        store.updateHealth(event.payload); store.loadConfig()
      })) as unknown as () => void

      // Also do an initial load
      await store.loadHealth()
    } catch {
      // Not running inside Tauri — fall back to mock polling
      await store.loadHealth()
      await store.loadConfig()
      pollTimer = setInterval(() => {
        store.loadHealth()
        store.loadConfig()
      }, 5000)
    }
  }

  onMounted(() => {
    startListening()
  })

  onUnmounted(() => {
    if (unlisten) unlisten()
    if (pollTimer) clearInterval(pollTimer)
  })
}
