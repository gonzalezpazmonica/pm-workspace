<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useProjectStore } from '../stores/project'
import AppSidebar from '../components/AppSidebar.vue'
import AppTopBar from '../components/AppTopBar.vue'
import LoginPage from '../components/LoginPage.vue'
import type { TeamResponse } from '../types/bridge'

const sidebarCollapsed = ref(false)
const auth = useAuthStore()
const projectStore = useProjectStore()

onMounted(async () => {
  if (auth.hasCookie && auth.token && auth.username) {
    const ctrl = new AbortController()
    const timer = setTimeout(() => ctrl.abort(), 8000)
    try {
      const slug = auth.username.replace(/^@/, '')
      const res = await fetch(`${auth.serverUrl}/team`, {
        headers: { 'Authorization': `Bearer ${auth.token}` },
        signal: ctrl.signal,
      })
      if (res.ok) {
        const team: TeamResponse = await res.json()
        const member = team.members.find(m => m.slug === slug) || null
        auth.login(auth.serverUrl, auth.username, auth.token, member)
      }
    } catch { /* timeout or error — will show login form */ }
    finally { clearTimeout(timer) }
  }
  await projectStore.load()
})
</script>

<template>
  <LoginPage v-if="!auth.isLoggedIn" />
  <div v-else class="layout" :class="{ collapsed: sidebarCollapsed }">
    <AppSidebar :collapsed="sidebarCollapsed" />
    <div class="main">
      <AppTopBar @toggle-sidebar="sidebarCollapsed = !sidebarCollapsed" />
      <main class="content">
        <router-view />
      </main>
    </div>
  </div>
</template>

<style scoped>
.layout { display: flex; height: 100vh; overflow: hidden; }
.main { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
.content {
  flex: 1; overflow-y: auto; padding: 24px;
  background: var(--savia-background);
}
</style>
