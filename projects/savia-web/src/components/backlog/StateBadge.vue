<script setup lang="ts">
defineProps<{ state: string }>()

const colors: Record<string, string> = {
  New: '#6b7280',
  Active: '#3b82f6',
  'In Review': '#f59e0b',
  Resolved: '#22c55e',
  Closed: '#9ca3af',
  Done: '#22c55e',
  Blocked: '#ef4444',
}
</script>

<template>
  <span class="badge" :style="{ background: colors[state] ?? '#6b7280' }">
    {{ state }}
  </span>
</template>

<style scoped>
.badge {
  font-size: 11px; padding: 2px 8px; border-radius: 10px;
  color: white; white-space: nowrap; font-weight: 500;
}
</style>
