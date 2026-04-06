<script setup lang="ts">
import { ref, onMounted, markRaw, type Component } from 'vue'
import {
  ShieldCheck,
  Activity,
  GitBranch,
  Bell,
  Minus,
  X,
  Sun,
  Moon,
} from 'lucide-vue-next'
import SessionsPanel from './components/SessionsPanel.vue'
import ShieldDashboard from './components/ShieldDashboard.vue'
import GitNidos from './components/GitNidos.vue'
import ActivityPanel from './components/ActivityPanel.vue'
import { useI18n } from './locales/i18n'

const { t } = useI18n()
const activeTab = ref(0)

interface Tab {
  icon: Component
  key: string
}

const tabs: Tab[] = [
  { icon: markRaw(Activity), key: 'tab.sessions' },
  { icon: markRaw(ShieldCheck), key: 'tab.shield' },
  { icon: markRaw(GitBranch), key: 'tab.git' },
  { icon: markRaw(Bell), key: 'tab.alerts' },
]

const isDark = ref(window.matchMedia('(prefers-color-scheme: dark)').matches)

function toggleTheme() {
  isDark.value = !isDark.value
  document.documentElement.setAttribute('data-theme', isDark.value ? 'dark' : 'light')
}

let appWindow: any = null

async function initWindow() {
  try {
    const { getCurrentWindow } = await import('@tauri-apps/api/window')
    appWindow = getCurrentWindow()
  } catch {
    // Running outside Tauri — window controls are no-ops
  }
}

function minimize() {
  appWindow?.minimize()
}

function close() {
  appWindow?.hide()
}

onMounted(() => {
  // Detect OS dark mode preference
  if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
    document.documentElement.setAttribute('data-theme', 'dark')
  }

  // Listen for theme changes
  window
    .matchMedia('(prefers-color-scheme: dark)')
    .addEventListener('change', (e) => {
      document.documentElement.setAttribute(
        'data-theme',
        e.matches ? 'dark' : 'light',
      )
    })

  initWindow()
})
</script>

<template>
  <div class="app-shell">
    <!-- Title bar -->
    <header class="titlebar" data-tauri-drag-region>
      <div class="titlebar__brand" data-tauri-drag-region>
        <img class="titlebar__owl" src="./assets/savia-logo.png" alt="Savia" />
        <span class="titlebar__title" data-tauri-drag-region>Savia Monitor</span>
      </div>
      <div class="titlebar__controls">
        <button class="titlebar__btn" :title="isDark ? t('theme.light') : t('theme.dark')" @click="toggleTheme">
          <Sun v-if="isDark" :size="14" />
          <Moon v-else :size="14" />
        </button>
        <button class="titlebar__btn" title="Minimize" @click="minimize">
          <Minus :size="14" />
        </button>
        <button
          class="titlebar__btn titlebar__btn--close"
          title="Close to tray"
          @click="close"
        >
          <X :size="14" />
        </button>
      </div>
    </header>

    <!-- Tab bar -->
    <nav class="tabbar">
      <button
        v-for="(tab, i) in tabs"
        :key="tab.key"
        class="tabbar__tab"
        :class="{ 'tabbar__tab--active': activeTab === i }"
        @click="activeTab = i"
      >
        <component :is="tab.icon" :size="16" />
        <span class="tabbar__label">{{ t(tab.key) }}</span>
      </button>
    </nav>

    <!-- Content -->
    <main class="content">
      <SessionsPanel v-if="activeTab === 0" />
      <ShieldDashboard v-else-if="activeTab === 1" />
      <GitNidos v-else-if="activeTab === 2" />
      <ActivityPanel v-else />
    </main>
  </div>
</template>

<style scoped>
.app-shell {
  display: flex;
  flex-direction: column;
  height: 100vh;
  background: var(--savia-background);
}

/* ---- Title bar ---- */
.titlebar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 44px;
  padding: 0 var(--space-3);
  background: var(--savia-surface);
  border-bottom: 1px solid var(--savia-glass-border);
  flex-shrink: 0;
}

.titlebar__brand {
  display: flex;
  align-items: center;
  gap: var(--space-2);
}

.titlebar__owl {
  width: 22px;
  height: 22px;
  border-radius: 4px;
}

.titlebar__title {
  font-size: 13px;
  font-weight: 700;
  color: var(--savia-on-surface);
  letter-spacing: 0.02em;
}

.titlebar__controls {
  display: flex;
  gap: 2px;
}

.titlebar__btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border: none;
  background: transparent;
  color: var(--savia-on-surface-variant);
  border-radius: var(--savia-radius);
  cursor: pointer;
  transition: background var(--savia-transition), color var(--savia-transition);
}

.titlebar__btn:hover {
  background: var(--savia-surface-variant);
  color: var(--savia-on-surface);
}

.titlebar__btn--close:hover {
  background: var(--savia-error);
  color: #fff;
}

/* ---- Tab bar ---- */
.tabbar {
  display: flex;
  border-bottom: 1px solid var(--savia-glass-border);
  background: var(--savia-surface);
  flex-shrink: 0;
}

.tabbar__tab {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  padding: var(--space-2) 0;
  border: none;
  background: transparent;
  color: var(--savia-on-surface-variant);
  cursor: pointer;
  transition: color var(--savia-transition), background var(--savia-transition);
  position: relative;
  font-family: inherit;
}

.tabbar__tab:hover {
  background: var(--savia-surface-variant);
}

.tabbar__tab--active {
  color: var(--savia-primary);
}

.tabbar__tab--active::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: 20%;
  right: 20%;
  height: 2px;
  background: var(--savia-primary);
  border-radius: 1px;
}

.tabbar__label {
  font-size: 10px;
  font-weight: 600;
}

/* ---- Content ---- */
.content {
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

/* ---- Placeholder tabs ---- */
.placeholder {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--space-3);
  color: var(--savia-on-surface-variant);
}

.placeholder__icon {
  opacity: 0.4;
}

.placeholder p {
  font-size: 13px;
  font-weight: 500;
}
</style>
