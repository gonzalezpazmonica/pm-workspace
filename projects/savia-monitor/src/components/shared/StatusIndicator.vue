<script setup lang="ts">
import type { LayerStatus } from '@/stores/shield'

defineProps<{
  status: LayerStatus
  size?: number
}>()
</script>

<template>
  <span
    class="status-indicator"
    :class="[`status--${status}`, { pulse: status === 'degraded' || status === 'down' }]"
    :style="{ width: `${size ?? 10}px`, height: `${size ?? 10}px` }"
    :title="status"
  />
</template>

<style scoped>
.status-indicator {
  display: inline-block;
  border-radius: 50%;
  flex-shrink: 0;
}

.status--active {
  background: var(--savia-success);
  box-shadow: 0 0 6px var(--savia-success);
}

.status--degraded {
  background: var(--savia-warning);
  box-shadow: 0 0 6px var(--savia-warning);
}

.status--down {
  background: var(--savia-error);
  box-shadow: 0 0 6px var(--savia-error);
}

.status--disabled {
  background: var(--savia-outline);
  opacity: 0.5;
}
</style>
