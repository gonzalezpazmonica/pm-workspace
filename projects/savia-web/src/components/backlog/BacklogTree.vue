<script setup lang="ts">
import { ChevronRight, ChevronDown, BookOpen, Bug, Wrench, Lightbulb, ListTodo, FileText } from 'lucide-vue-next'
import { useBacklogStore } from '../../stores/backlog'
import StateBadge from './StateBadge.vue'

const store = useBacklogStore()

const typeIcon: Record<string, typeof BookOpen> = {
  'User Story': BookOpen, Bug, 'Tech Debt': Wrench, Spike: Lightbulb,
}
</script>

<template>
  <div class="tree">
    <div v-for="spec in store.filteredSpecs" :key="spec.id" class="tree-group">
      <!-- Spec row (level 1) -->
      <div class="tree-row spec-row" :class="{ selected: store.selectedItemId === spec.id }" @click="store.selectSpec(spec.id)">
        <button class="expand-btn" @click.stop="store.toggleExpand(spec.id)">
          <component :is="store.expandedItems.has(spec.id) ? ChevronDown : ChevronRight" :size="14" />
        </button>
        <FileText :size="14" class="type-icon spec-icon" />
        <span class="item-id">{{ spec.id }}</span>
        <span class="item-title">{{ spec.title }}</span>
        <StateBadge :state="spec.state" />
        <span class="item-count">{{ spec.pbis.length }} PBIs</span>
      </div>

      <template v-if="store.expandedItems.has(spec.id)">
        <div v-for="pbi in spec.pbis" :key="pbi.id">
          <!-- PBI row (level 2) -->
          <div class="tree-row pbi-row" :class="{ selected: store.selectedItemId === pbi.id }" @click="store.selectPbi(pbi.id)">
            <button v-if="pbi.tasks.length" class="expand-btn indent-1" @click.stop="store.toggleExpand(pbi.id)">
              <component :is="store.expandedItems.has(pbi.id) ? ChevronDown : ChevronRight" :size="14" />
            </button>
            <span v-else class="expand-spacer indent-1" />
            <component :is="typeIcon[pbi.type] ?? BookOpen" :size="14" class="type-icon pbi-icon" />
            <span class="item-id">{{ pbi.id }}</span>
            <span class="item-title">{{ pbi.title }}</span>
            <StateBadge :state="pbi.state" />
            <span class="item-assignee">{{ pbi.assigned_to }}</span>
            <span class="item-hours">{{ pbi.estimated_hours }}h</span>
          </div>

          <!-- Task rows (level 3) -->
          <template v-if="store.expandedItems.has(pbi.id)">
            <div v-for="task in pbi.tasks" :key="task.id" class="tree-row task-row">
              <span class="expand-spacer indent-2" />
              <ListTodo :size="13" class="type-icon task-icon" />
              <span class="item-id task-id">{{ task.id }}</span>
              <span class="item-title">{{ task.title }}</span>
              <StateBadge :state="task.state" />
              <span class="item-assignee">{{ task.assigned_to }}</span>
              <span class="item-hours">{{ task.remaining_hours }}/{{ task.estimated_hours }}h</span>
            </div>
          </template>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.tree { font-size: 13px; }
.tree-row { display: flex; align-items: center; gap: 8px; padding: 6px 10px; cursor: pointer; border-radius: var(--savia-radius); }
.tree-row:hover { background: var(--savia-surface-variant); }
.tree-row.selected { background: var(--savia-primary-container); }
.expand-btn { background: none; border: none; padding: 2px; cursor: pointer; display: flex; color: var(--savia-on-surface); }
.expand-spacer { width: 18px; flex-shrink: 0; }
.indent-1 { margin-left: 20px; }
.indent-2 { margin-left: 40px; }
.type-icon { flex-shrink: 0; }
.spec-icon { color: var(--savia-tertiary, #7c6f9f); }
.pbi-icon { color: var(--savia-primary); }
.task-icon { color: var(--savia-outline); }
.item-id { font-family: monospace; color: var(--savia-outline); min-width: 80px; }
.task-id { font-size: 11px; min-width: 100px; }
.item-title { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.item-assignee { color: var(--savia-outline); min-width: 60px; }
.item-hours { color: var(--savia-outline); min-width: 40px; text-align: right; }
.item-count { font-size: 11px; color: var(--savia-outline); background: var(--savia-surface-variant); padding: 1px 6px; border-radius: 8px; }
.spec-row { font-weight: 500; }
</style>
