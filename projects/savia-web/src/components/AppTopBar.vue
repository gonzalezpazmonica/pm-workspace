<script setup lang="ts">
import { useAuthStore } from '../stores/auth'
import { Menu, LogOut } from 'lucide-vue-next'
import ProjectSelector from './ProjectSelector.vue'

const emit = defineEmits<{ 'toggle-sidebar': [] }>()
const auth = useAuthStore()
</script>

<template>
  <header class="topbar">
    <button class="menu-btn" @click="emit('toggle-sidebar')"><Menu :size="20" /></button>
    <ProjectSelector />
    <div class="spacer" />
    <div class="user-info" v-if="auth.isLoggedIn">
      <span class="status connected">Connected</span>
      <span class="profile-name">{{ auth.profileName }}</span>
      <button class="btn-logout" @click="auth.logout()"><LogOut :size="14" /> Logout</button>
    </div>
    <div v-else class="status">Disconnected</div>
  </header>
</template>

<style scoped>
.topbar {
  height: var(--savia-topbar-height);
  background: var(--savia-surface);
  backdrop-filter: blur(var(--savia-glass-blur));
  -webkit-backdrop-filter: blur(var(--savia-glass-blur));
  border-bottom: 1px solid var(--savia-glass-border);
  display: flex; align-items: center; padding: 0 var(--space-4); gap: var(--space-3);
}
.menu-btn {
  background: none; padding: var(--space-2);
  border-radius: var(--savia-radius); color: var(--savia-on-surface);
  transition: background var(--savia-transition);
  display: flex; align-items: center;
}
.menu-btn:hover { background: var(--savia-surface-variant); }
.spacer { flex: 1; }
.user-info { display: flex; align-items: center; gap: 10px; }
.profile-name { font-size: 14px; font-weight: 600; color: var(--savia-on-surface); }
.status {
  font-size: 12px; padding: 4px 12px; border-radius: 12px;
  background: var(--savia-error-container); color: var(--savia-error);
}
.status.connected { background: var(--savia-success-container); color: var(--savia-success); }
.btn-logout {
  display: flex; align-items: center; gap: 4px;
  font-size: 12px; padding: 6px 12px; border-radius: var(--savia-radius);
  background: var(--savia-surface-variant); color: var(--savia-on-surface-variant);
  transition: all var(--savia-transition);
}
.btn-logout:hover { background: var(--savia-error-container); color: var(--savia-error); }
</style>
