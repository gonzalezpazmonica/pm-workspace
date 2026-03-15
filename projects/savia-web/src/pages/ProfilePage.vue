<script setup lang="ts">
import { useI18n } from 'vue-i18n'
const { t } = useI18n()
import { ref, onMounted } from 'vue'
import { useBridge } from '../composables/useBridge'
import LoadingSpinner from '../components/LoadingSpinner.vue'
import type { UserProfile } from '../types/bridge'

const { get } = useBridge()
const profile = ref<UserProfile | null>(null)
const loading = ref(false)

onMounted(async () => {
  loading.value = true
  try { profile.value = await get<UserProfile>('/profile') }
  catch { /* ignore */ }
  finally { loading.value = false }
})
</script>

<template>
  <div class="profile-page">
    <h1>{{ t('profile.title') }}</h1>
    <LoadingSpinner v-if="loading" />
    <div v-else-if="profile" class="profile-card">
      <div class="avatar">{{ profile.name.charAt(0) }}</div>
      <h2>{{ profile.name }}</h2>
      <p class="role">{{ profile.role }}</p>
      <p class="email">{{ profile.email }}</p>
      <p class="org">{{ profile.organization }}</p>
      <div v-if="profile.stats" class="stats">
        <div class="stat"><strong>{{ profile.stats.sprintsCompleted }}</strong><span>Sprints</span></div>
        <div class="stat"><strong>{{ profile.stats.pbisDelivered }}</strong><span>PBIs</span></div>
        <div class="stat"><strong>{{ profile.stats.hoursLogged.toFixed(0) }}h</strong><span>Logged</span></div>
      </div>
    </div>
  </div>
</template>

<style scoped>
h1 { font-size: 20px; margin-bottom: 20px; }
.profile-card { background: var(--savia-surface); padding: 32px; border-radius: var(--savia-radius-lg); box-shadow: var(--savia-shadow); text-align: center; max-width: 400px; }
.avatar { width: 64px; height: 64px; border-radius: 50%; background: var(--savia-primary); color: white; font-size: 28px; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; }
h2 { font-size: 20px; }
.role { color: var(--savia-primary); font-weight: 600; font-size: 14px; }
.email, .org { font-size: 13px; color: var(--savia-on-surface-variant); }
.stats { display: flex; justify-content: center; gap: 24px; margin-top: 20px; padding-top: 16px; border-top: 1px solid var(--savia-surface-variant); }
.stat { text-align: center; }
.stat strong { display: block; font-size: 18px; color: var(--savia-primary); }
.stat span { font-size: 12px; color: var(--savia-on-surface-variant); }
</style>
