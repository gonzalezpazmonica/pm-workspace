<script setup lang="ts">
import { ref } from 'vue'
import type { Layer } from '@/stores/shield'
import StatusIndicator from './StatusIndicator.vue'

defineProps<{ layer: Layer }>()

const showTip = ref(false)
const pinned = ref(false)

function onEnter() {
  if (!pinned.value) showTip.value = true
}
function onLeave() {
  if (!pinned.value) showTip.value = false
}
function onClick() {
  pinned.value = !pinned.value
  showTip.value = pinned.value
}

function borderColor(status: string): string {
  switch (status) {
    case 'active': return 'var(--savia-success)'
    case 'degraded': return 'var(--savia-warning)'
    case 'down': return 'var(--savia-error)'
    default: return 'var(--savia-outline)'
  }
}
</script>

<template>
  <div
    class="layer-card glass-card"
    :style="{ borderLeftColor: borderColor(layer.status) }"
    @mouseenter="onEnter"
    @mouseleave="onLeave"
    @click="onClick"
  >
    <span class="layer-card__badge">{{ layer.id }}</span>
    <span class="layer-card__name">{{ layer.name }}</span>
    <span class="layer-card__desc">{{ layer.description }}</span>
    <StatusIndicator :status="layer.status" />
    <div v-show="showTip" class="layer-card__tip">
      {{ layer.tooltip }}
    </div>
  </div>
</template>

<style scoped>
.layer-card {
  display: flex; align-items: center; gap: var(--space-2);
  padding: var(--space-2) var(--space-3); border-left: 3px solid;
  transition: box-shadow var(--savia-transition); cursor: pointer;
  position: relative;
}
.layer-card:hover { box-shadow: var(--savia-shadow-md); }
.layer-card__badge {
  display: inline-flex; align-items: center; justify-content: center;
  width: 20px; height: 20px; border-radius: 50%;
  background: var(--savia-primary); color: #fff;
  font-size: 10px; font-weight: 700; flex-shrink: 0;
}
.layer-card__name { font-size: 12px; font-weight: 600; color: var(--savia-on-surface); white-space: nowrap; }
.layer-card__desc { font-size: 11px; color: var(--savia-on-surface-variant); flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

.layer-card__tip {
  position: absolute; left: 0; right: 0; bottom: 100%; z-index: 50;
  margin-bottom: 4px; padding: var(--space-3);
  background: var(--savia-surface); border: 1px solid var(--savia-glass-border);
  border-radius: var(--savia-radius); box-shadow: var(--savia-shadow-lg);
  font-size: 11px; line-height: 1.5; color: var(--savia-on-surface);
  pointer-events: none; white-space: normal;
}
</style>
