<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { Filter, X } from 'lucide-vue-next'
import { useBacklogStore } from '../../stores/backlog'

const { t } = useI18n()
const store = useBacklogStore()
const allStates = ['New', 'Active', 'Resolved', 'Closed', 'Done', 'Draft']

function toggleType(key: 'showSpecs' | 'showPbis' | 'showTasks') {
  store.setFilter({ [key]: !store.filters[key] })
}

function toggleState(state: string) {
  const current = [...store.filters.states]
  const idx = current.indexOf(state)
  if (idx >= 0) current.splice(idx, 1)
  else current.push(state)
  store.setFilter({ states: current })
}

function setAssignee(e: Event) {
  store.setFilter({ assignee: (e.target as HTMLSelectElement).value })
}
</script>

<template>
  <div class="filter-bar">
    <Filter :size="14" class="filter-icon" />

    <div class="type-toggles">
      <button :class="{ active: store.filters.showSpecs }" @click="toggleType('showSpecs')">Spec</button>
      <button :class="{ active: store.filters.showPbis }" @click="toggleType('showPbis')">PBI</button>
      <button :class="{ active: store.filters.showTasks }" @click="toggleType('showTasks')">Task</button>
    </div>

    <select class="state-filter" :value="''" @change="toggleState(($event.target as HTMLSelectElement).value)">
      <option value="" disabled>{{ t('common.filter') }}: Estado</option>
      <option v-for="s in allStates" :key="s" :value="s">
        {{ store.filters.states.includes(s) ? '✓ ' : '' }}{{ s }}
      </option>
    </select>

    <select class="assignee-filter" :value="store.filters.assignee" @change="setAssignee">
      <option value="">{{ t('common.filter') }}: Todos</option>
      <option v-for="a in store.allAssignees" :key="a" :value="a">{{ a }}</option>
    </select>

    <span v-if="store.activeFilterCount > 0" class="filter-badge">{{ store.activeFilterCount }}</span>
    <button v-if="store.activeFilterCount > 0" class="clear-btn" @click="store.clearFilters">
      <X :size="12" />
    </button>
  </div>
</template>

<style scoped>
.filter-bar { display: flex; align-items: center; gap: 8px; padding: 6px 0; font-size: 12px; flex-wrap: wrap; }
.filter-icon { color: var(--savia-outline); flex-shrink: 0; }
.type-toggles { display: flex; gap: 2px; }
.type-toggles button {
  padding: 3px 10px; border: 1px solid var(--savia-outline); border-radius: var(--savia-radius);
  background: var(--savia-surface); font-size: 11px; cursor: pointer; font-family: inherit; color: var(--savia-on-surface-variant);
}
.type-toggles button.active { background: var(--savia-primary); color: white; border-color: var(--savia-primary); }
.state-filter, .assignee-filter {
  padding: 3px 8px; border: 1px solid var(--savia-outline); border-radius: var(--savia-radius);
  font-size: 11px; background: var(--savia-surface); color: var(--savia-on-surface);
}
.filter-badge {
  background: var(--savia-primary); color: white; font-size: 10px; font-weight: 600;
  padding: 1px 6px; border-radius: 10px; min-width: 16px; text-align: center;
}
.clear-btn { background: none; border: none; cursor: pointer; color: var(--savia-outline); display: flex; padding: 2px; }
</style>
