<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue'
import { Monitor, ShieldCheck, Bot, GitBranch, ArrowUp, GitPullRequest, GitMerge, FileWarning } from 'lucide-vue-next'
import { useSessionsStore } from '@/stores/sessions'
import { useWorkflowStore } from '@/stores/workflow'
import { useI18n } from '@/locales/i18n'
import StatusIndicator from './shared/StatusIndicator.vue'

const sessions = useSessionsStore()
const workflow = useWorkflowStore()
const { t } = useI18n()

let pollTimer: ReturnType<typeof setInterval> | null = null

onMounted(async () => {
  await Promise.all([sessions.loadSessions(), workflow.loadAll()])
  // Refresh sessions every 10s to catch new agents, branch changes, etc.
  pollTimer = setInterval(() => {
    sessions.loadSessions()
    workflow.loadAll()
  }, 10000)
  try {
    const { listen } = await import('@tauri-apps/api/event')
    listen('shield-health', (e: any) => workflow.updateFromHealth(e.payload))
  } catch { /* outside Tauri */ }
})

onUnmounted(() => {
  if (pollTimer) clearInterval(pollTimer)
})
</script>

<template>
  <div class="sessions">
    <div class="sessions__summary">
      <div class="glass-card sessions__stat">
        <Monitor :size="14" />
        <span class="sessions__stat-num">{{ sessions.sessionCount }}</span>
        <span class="sessions__stat-label">{{ t('sessions.active') }}</span>
      </div>
      <div class="glass-card sessions__stat">
        <ShieldCheck :size="14" />
        <span class="sessions__stat-num">{{ sessions.protectedCount }}/{{ sessions.sessionCount }}</span>
        <span class="sessions__stat-label">{{ t('sessions.protected') }}</span>
      </div>
      <div class="glass-card sessions__stat">
        <Bot :size="14" />
        <span class="sessions__stat-num">{{ sessions.totalAgents }}</span>
        <span class="sessions__stat-label">{{ t('sessions.agents') }}</span>
      </div>
      <div class="glass-card sessions__stat" :title="workflow.health?.breakdown?.join('\n') || t('sessions.healthTooltip')">
        <span class="sessions__score" :class="{ 'sessions__score--good': workflow.healthScore >= 70, 'sessions__score--warn': workflow.healthScore >= 40 && workflow.healthScore < 70, 'sessions__score--bad': workflow.healthScore < 40 }">
          {{ workflow.healthScore }}%
        </span>
        <span class="sessions__stat-label">{{ t('sessions.health') }}</span>
      </div>
    </div>

    <div class="sessions__list">
      <div v-for="s in sessions.sessions" :key="s.pid" class="glass-card sessions__card">
        <div class="sessions__card-header">
          <span class="sessions__name">{{ s.name || t('sessions.unnamed') }}</span>
          <StatusIndicator :status="s.shield_active ? 'active' : 'down'" />
        </div>

        <div class="sessions__branch-row">
          <GitBranch :size="11" />
          <span class="sessions__branch">{{ s.branch || 'detached' }}</span>
          <span v-if="s.branch_status.dirty_files > 0" class="sessions__tag sessions__tag--warn" :title="t('sessions.modified')">
            <FileWarning :size="9" /> {{ s.branch_status.dirty_files }}
          </span>
          <span v-if="s.branch_status.unpushed_commits > 0" class="sessions__tag sessions__tag--info" :title="t('sessions.unpushed')">
            <ArrowUp :size="9" /> {{ s.branch_status.unpushed_commits }}
          </span>
          <span v-if="s.branch_status.has_pr" class="sessions__tag sessions__tag--pr" :title="t('sessions.hasPR')">
            <GitPullRequest :size="9" /> PR
          </span>
          <span v-if="s.branch_status.merged" class="sessions__tag sessions__tag--merged" :title="t('sessions.merged')">
            <GitMerge :size="9" />
          </span>
          <span v-if="s.is_nido" class="sessions__tag sessions__tag--nido">{{ s.nido_name }}</span>
        </div>

        <div v-if="s.agent_count > 0" class="sessions__agents-row">
          <Bot :size="11" /> {{ s.agent_count }} {{ t('sessions.agentsRunning') }}
        </div>

        <div v-if="s.recent_actions.length" class="sessions__actions">
          <div v-for="(a, i) in s.recent_actions" :key="i" class="sessions__action-line">
            {{ a }}
          </div>
        </div>
      </div>

      <div v-if="!sessions.sessions.length" class="sessions__empty">
        {{ t('sessions.none') }}
      </div>
    </div>
  </div>
</template>

<style scoped>
.sessions { display: flex; flex-direction: column; gap: var(--space-3); padding: var(--space-4); overflow-y: auto; flex: 1; }
.sessions__summary { display: flex; gap: var(--space-2); }
.sessions__stat { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 2px; padding: var(--space-2); font-size: 10px; cursor: default; }
.sessions__stat-num { font-size: 16px; font-weight: 800; color: var(--savia-on-surface); }
.sessions__stat-label { color: var(--savia-on-surface-variant); font-weight: 600; }
.sessions__score { font-size: 16px; font-weight: 800; }
.sessions__score--good { color: var(--savia-success); }
.sessions__score--warn { color: var(--savia-warning); }
.sessions__score--bad { color: var(--savia-error); }
.sessions__list { display: flex; flex-direction: column; gap: var(--space-2); }
.sessions__card { padding: var(--space-3); }
.sessions__card-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--space-2); }
.sessions__name { font-size: 13px; font-weight: 700; color: var(--savia-primary); }
.sessions__branch-row { display: flex; align-items: center; gap: var(--space-2); flex-wrap: wrap; }
.sessions__branch { font-family: monospace; font-size: 11px; color: var(--savia-on-surface); }
.sessions__tag { display: inline-flex; align-items: center; gap: 2px; font-size: 9px; padding: 1px 5px; border-radius: 6px; font-weight: 600; white-space: nowrap; }
.sessions__tag--warn { background: var(--savia-warning-container); color: var(--savia-warning); }
.sessions__tag--info { background: var(--savia-primary-container, #e8def8); color: var(--savia-primary); }
.sessions__tag--pr { background: var(--savia-success-container); color: var(--savia-success); }
.sessions__tag--merged { background: var(--savia-surface-variant); color: var(--savia-on-surface-variant); }
.sessions__tag--nido { background: var(--savia-primary); color: #fff; }
.sessions__agents-row { display: flex; align-items: center; gap: 4px; font-size: 11px; color: var(--savia-primary); margin-top: var(--space-1); }
.sessions__actions { margin-top: var(--space-2); padding-top: var(--space-2); border-top: 1px solid var(--savia-glass-border); }
.sessions__action-line { font-size: 10px; color: var(--savia-on-surface-variant); padding: 1px 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.sessions__empty { text-align: center; color: var(--savia-on-surface-variant); font-size: 12px; padding: var(--space-6); }
</style>
