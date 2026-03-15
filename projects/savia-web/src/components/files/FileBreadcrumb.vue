<script setup lang="ts">
import { ChevronRight } from 'lucide-vue-next'

const props = defineProps<{
  path: string[]
}>()

const emit = defineEmits<{
  navigate: [path: string[]]
}>()

function navigateTo(index: number) {
  emit('navigate', props.path.slice(0, index + 1))
}
</script>

<template>
  <nav class="breadcrumb" aria-label="File path">
    <span
      v-for="(segment, index) in path"
      :key="index"
      class="breadcrumb-item"
    >
      <ChevronRight v-if="index > 0" :size="14" class="breadcrumb-sep" />
      <button
        class="breadcrumb-segment"
        :class="{ 'is-last': index === path.length - 1 }"
        @click="navigateTo(index)"
      >
        {{ segment }}
      </button>
    </span>
  </nav>
</template>

<style scoped>
.breadcrumb {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 2px;
  font-size: 13px;
  padding: 6px 0;
}
.breadcrumb-item {
  display: flex;
  align-items: center;
  gap: 2px;
}
.breadcrumb-sep {
  color: var(--savia-outline);
  flex-shrink: 0;
}
.breadcrumb-segment {
  background: none;
  border: none;
  padding: 2px 6px;
  border-radius: var(--savia-radius);
  color: var(--savia-primary);
  cursor: pointer;
  font-size: 13px;
  font-family: inherit;
  transition: background 0.15s;
}
.breadcrumb-segment:hover {
  background: var(--savia-surface-variant);
}
.breadcrumb-segment.is-last {
  color: var(--savia-on-surface);
  font-weight: 500;
  cursor: default;
}
.breadcrumb-segment.is-last:hover {
  background: none;
}
</style>
