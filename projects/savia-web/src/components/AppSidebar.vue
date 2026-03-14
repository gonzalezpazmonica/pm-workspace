<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import {
  Home, MessageSquare, Zap, LayoutDashboard, CheckCircle2,
  Clock, FolderOpen, BarChart3, User, Settings, Sun, Moon
} from 'lucide-vue-next'

defineProps<{ collapsed: boolean }>()
const route = useRoute()

const dark = ref(localStorage.getItem('savia_theme') === 'dark')
function toggleTheme() {
  dark.value = !dark.value
  document.documentElement.setAttribute('data-theme', dark.value ? 'dark' : 'light')
  localStorage.setItem('savia_theme', dark.value ? 'dark' : 'light')
}
const appVersion = __APP_VERSION__

onMounted(() => {
  if (dark.value) document.documentElement.setAttribute('data-theme', 'dark')
})

const navItems = [
  { path: '/', label: 'Home', icon: Home },
  { path: '/chat', label: 'Chat', icon: MessageSquare },
  { path: '/commands', label: 'Commands', icon: Zap },
  { path: '/kanban', label: 'Kanban', icon: LayoutDashboard },
  { path: '/approvals', label: 'Approvals', icon: CheckCircle2 },
  { path: '/timelog', label: 'Time Log', icon: Clock },
  { path: '/files', label: 'Files', icon: FolderOpen },
  { path: '/reports', label: 'Reports', icon: BarChart3 },
  { path: '/profile', label: 'Profile', icon: User },
  { path: '/settings', label: 'Settings', icon: Settings },
]
</script>

<template>
  <aside class="sidebar" :class="{ collapsed }">
    <div class="logo">
      <img src="/savia-logo.png" alt="Savia" class="logo-img" :class="{ small: collapsed }" />
      <span v-if="!collapsed" class="logo-text">Savia</span>
    </div>
    <nav class="nav">
      <router-link
        v-for="item in navItems"
        :key="item.path"
        :to="item.path"
        class="nav-item"
        :class="{
          active:
            route.path === item.path ||
            route.path.startsWith(item.path + '/'),
        }"
      >
        <component :is="item.icon" :size="20" class="nav-icon" />
        <span v-if="!collapsed" class="nav-label">{{ item.label }}</span>
      </router-link>
    </nav>
    <div class="sidebar-footer">
      <button class="theme-toggle" @click="toggleTheme" :title="dark ? 'Light mode' : 'Dark mode'">
        <Moon v-if="!dark" :size="18" />
        <Sun v-else :size="18" />
        <span v-if="!collapsed">{{ dark ? 'Light' : 'Dark' }}</span>
      </button>
      <span v-if="!collapsed" class="version">Savia Web v{{ appVersion }}</span>
    </div>
  </aside>
</template>

<style scoped>
.sidebar {
  width: var(--savia-sidebar-width);
  background: var(--savia-surface);
  backdrop-filter: blur(var(--savia-glass-blur));
  -webkit-backdrop-filter: blur(var(--savia-glass-blur));
  border-right: 1px solid var(--savia-glass-border);
  display: flex;
  flex-direction: column;
  transition: width var(--savia-transition);
  flex-shrink: 0;
}
.sidebar.collapsed { width: 56px; }
.logo {
  display: flex; align-items: center; gap: var(--space-2);
  padding: var(--space-4); font-size: 18px; font-weight: 700;
  color: var(--savia-primary);
}
.logo-img { width: 36px; height: 36px; transition: all var(--savia-transition); }
.logo-img.small { width: 28px; height: 28px; }
.nav { display: flex; flex-direction: column; gap: 2px; padding: var(--space-2); }
.nav-item {
  display: flex; align-items: center; gap: var(--space-3);
  padding: 10px 14px; border-radius: var(--savia-radius);
  color: var(--savia-on-surface-variant); text-decoration: none;
  transition: all var(--savia-transition); font-size: 14px; font-weight: 450;
}
.nav-item:hover { background: var(--savia-surface-variant); color: var(--savia-on-surface); }
.nav-item.active {
  background: var(--savia-primary); color: white; font-weight: 550;
  box-shadow: 0 2px 8px rgba(107, 76, 154, 0.3);
}
.nav-icon { flex-shrink: 0; }
.sidebar-footer {
  margin-top: auto; padding: var(--space-3);
  display: flex; flex-direction: column; gap: var(--space-2);
}
.theme-toggle {
  display: flex; align-items: center; gap: var(--space-2);
  padding: 8px 14px; border-radius: var(--savia-radius);
  background: var(--savia-surface-variant); color: var(--savia-on-surface-variant);
  font-size: 13px; transition: all var(--savia-transition);
}
.theme-toggle:hover { color: var(--savia-on-surface); }
.version {
  font-size: 11px; color: var(--savia-outline); text-align: center;
  padding: var(--space-1) 0;
}
</style>
