<script setup lang="ts">
import { computed } from 'vue'
import { useProjectStore } from '../stores/project'

const store = useProjectStore()

const healthColor: Record<string, string> = {
  healthy: '#22c55e',
  warning: '#f59e0b',
  critical: '#ef4444',
  unknown: '#9ca3af',
}

/** Top-level projects that have children (umbrellas). */
const umbrellas = computed(() =>
  store.topLevel.filter(p => p.children.length > 0)
)

/** Top-level projects that have no children (standalone). */
const standalone = computed(() =>
  store.topLevel.filter(p => p.children.length === 0)
)

function onChange(e: Event) {
  const id = (e.target as HTMLSelectElement).value
  store.select(id)
}

function confLabel(conf: string | null): string {
  return conf ? ` (${conf})` : ''
}
</script>

<template>
  <div class="selector-wrapper">
    <select
      class="project-select"
      :value="store.selectedId"
      @change="onChange"
    >
      <!-- Standalone projects (no subprojects) -->
      <option
        v-for="p in standalone"
        :key="p.id"
        :value="p.id"
      >
        {{ p.name }}
      </option>

      <!-- Umbrella projects with subproject groups -->
      <optgroup
        v-for="u in umbrellas"
        :key="u.id"
        :label="u.name"
      >
        <option
          v-for="child in store.childrenOf(u.id)"
          :key="child.id"
          :value="child.id"
        >
          {{ child.name }}{{ confLabel(child.confidentiality) }}
        </option>
      </optgroup>
    </select>
    <span
      v-if="store.selected"
      class="health-dot"
      :style="{ background: healthColor[store.selected.health] ?? healthColor.unknown }"
    />
  </div>
</template>

<style scoped>
.selector-wrapper {
  position: relative;
  display: flex;
  align-items: center;
  gap: 6px;
}

.project-select {
  padding: 5px 10px;
  border: 1px solid var(--savia-outline);
  border-radius: var(--savia-radius);
  background: var(--savia-surface);
  color: var(--savia-on-surface);
  font-size: 13px;
  min-width: 180px;
  max-width: 280px;
  cursor: pointer;
}

.project-select:focus {
  outline: 2px solid var(--savia-primary);
  outline-offset: 1px;
}

.health-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
  display: inline-block;
}
</style>
