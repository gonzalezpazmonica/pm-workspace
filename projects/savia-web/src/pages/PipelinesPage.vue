<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { CheckCircle, XCircle, Clock, Loader } from 'lucide-vue-next'
import { usePipelineStore } from '../stores/pipeline'
import type { PipelineStage } from '../stores/pipeline'
import LoadingSpinner from '../components/LoadingSpinner.vue'

const store = usePipelineStore()
const expandedStage = ref<string | null>(null)
onMounted(() => store.load())

const statusIcon: Record<string, typeof CheckCircle> = {
  success: CheckCircle, failed: XCircle, running: Loader, pending: Clock,
}
const statusColor: Record<string, string> = {
  success: '#22c55e', failed: '#ef4444', running: '#3b82f6',
  pending: '#9ca3af', skipped: '#6b7280',
}

function toggleStage(name: string) {
  expandedStage.value = expandedStage.value === name ? null : name
}
</script>

<template>
  <div class="pipelines-page">
    <h1 class="page-title">Pipelines</h1>
    <LoadingSpinner v-if="store.loading" />
    <div v-else class="pipelines-body" :class="{ 'has-detail': store.selectedRun }">
      <div class="runs-list">
        <div
          v-for="run in store.runs" :key="run.id"
          class="run-card" :class="{ selected: store.selectedRunId === run.id }"
          @click="store.selectRun(run.id)"
        >
          <component :is="statusIcon[run.status] ?? Clock" :size="16" :style="{ color: statusColor[run.status] }" />
          <div class="run-info">
            <div class="run-name">{{ run.name }}</div>
            <div class="run-meta">{{ run.trigger }} &middot; {{ run.startedAt }} &middot; {{ run.duration }}</div>
          </div>
        </div>
      </div>
      <div v-if="store.selectedRun" class="run-detail">
        <h2>{{ store.selectedRun.name }}</h2>
        <div class="stages-flow">
          <div v-for="(stage, i) in store.selectedRun.stages" :key="stage.name" class="stage-item">
            <div class="stage-box" :style="{ borderColor: statusColor[stage.status] }" @click="toggleStage(stage.name)">
              <span class="stage-name">{{ stage.name }}</span>
              <span class="stage-dur">{{ stage.duration }}</span>
            </div>
            <div v-if="i < store.selectedRun!.stages.length - 1" class="stage-arrow">&rarr;</div>
          </div>
        </div>
        <div v-if="expandedStage" class="log-viewer">
          <pre>{{ store.selectedRun.stages.find((s: PipelineStage) => s.name === expandedStage)?.log ?? 'No logs' }}</pre>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.pipelines-page { display: flex; flex-direction: column; height: 100%; }
.page-title { font-size: 18px; font-weight: 600; margin-bottom: 12px; }
.pipelines-body.has-detail { display: grid; grid-template-columns: 300px 1fr; gap: 12px; }
.runs-list { display: flex; flex-direction: column; gap: 6px; overflow-y: auto; }
.run-card {
  display: flex; align-items: center; gap: 10px; padding: 10px 12px;
  background: var(--savia-surface); border-radius: var(--savia-radius);
  cursor: pointer; box-shadow: var(--savia-shadow);
}
.run-card.selected { outline: 2px solid var(--savia-primary); }
.run-card:hover { background: var(--savia-surface-variant); }
.run-info { flex: 1; }
.run-name { font-weight: 500; font-size: 13px; }
.run-meta { font-size: 11px; color: var(--savia-outline); }
.run-detail { background: var(--savia-surface); border-radius: var(--savia-radius-lg); padding: 16px; box-shadow: var(--savia-shadow); }
.run-detail h2 { font-size: 16px; margin-bottom: 12px; }
.stages-flow { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin-bottom: 12px; }
.stage-item { display: flex; align-items: center; gap: 8px; }
.stage-box {
  padding: 8px 14px; border: 2px solid; border-radius: var(--savia-radius);
  cursor: pointer; font-size: 13px; text-align: center;
}
.stage-name { font-weight: 500; }
.stage-dur { font-size: 11px; color: var(--savia-outline); display: block; }
.stage-arrow { color: var(--savia-outline); font-size: 18px; }
.log-viewer { background: var(--savia-background); border-radius: var(--savia-radius); padding: 12px; }
.log-viewer pre { font-size: 12px; font-family: monospace; white-space: pre-wrap; margin: 0; }
</style>
