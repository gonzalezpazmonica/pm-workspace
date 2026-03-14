<script setup lang="ts">
import { ref } from 'vue'
import { UserPlus } from 'lucide-vue-next'
import type { TeamMember } from '../types/bridge'

const props = defineProps<{ slug: string; serverUrl: string; token: string }>()
const emit = defineEmits<{ registered: [member: TeamMember]; cancel: [] }>()

const name = ref('')
const role = ref('Developer')
const email = ref('')
const error = ref('')
const saving = ref(false)

const roles = ['PM', 'Tech Lead', 'Developer', 'QA', 'Product Owner', 'CEO/CTO']

async function register() {
  if (!name.value.trim()) { error.value = 'Name is required'; return }
  saving.value = true
  error.value = ''

  try {
    const res = await fetch(`${props.serverUrl}/team`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${props.token}` },
      body: JSON.stringify({
        action: 'add',
        slug: props.slug,
        identity: { name: name.value.trim(), role: role.value, email: email.value.trim() },
      }),
    })
    if (!res.ok) { error.value = 'Registration failed. Check permissions.'; saving.value = false; return }

    const member: TeamMember = { slug: props.slug, name: name.value.trim(), role: role.value, email: email.value.trim() }
    emit('registered', member)
  } catch {
    error.value = 'Network error. Try again.'
  }
  saving.value = false
}
</script>

<template>
  <div class="register-card glass-card">
    <div class="register-icon"><UserPlus :size="48" color="var(--savia-primary)" /></div>
    <h2>Welcome, @{{ slug }}!</h2>
    <p class="register-subtitle">You're not in the team yet. Let's set up your profile.</p>
    <div class="form-row">
      <label>Name *</label>
      <input v-model="name" placeholder="Your name" />
    </div>
    <div class="form-row">
      <label>Role</label>
      <select v-model="role">
        <option v-for="r in roles" :key="r" :value="r">{{ r }}</option>
      </select>
    </div>
    <div class="form-row">
      <label>Email (optional)</label>
      <input v-model="email" type="email" placeholder="you@company.com" />
    </div>
    <p v-if="error" class="error-msg">{{ error }}</p>
    <div class="actions">
      <button class="btn-register" @click="register" :disabled="saving">
        {{ saving ? 'Registering...' : 'Join Team' }}
      </button>
      <button class="btn-cancel" @click="emit('cancel')">Back</button>
    </div>
  </div>
</template>

<style scoped>
.register-card { padding: 40px; width: 420px; text-align: center; }
.register-icon { display: flex; justify-content: center; margin-bottom: 12px; }
h2 { font-size: 20px; color: var(--savia-primary); margin-bottom: 4px; }
.register-subtitle { font-size: 13px; color: var(--savia-on-surface-variant); margin-bottom: 20px; }
.form-row { margin-bottom: 12px; text-align: left; }
.form-row label { display: block; font-size: 12px; color: var(--savia-on-surface-variant); margin-bottom: 3px; }
.form-row input, .form-row select {
  width: 100%; padding: 10px 12px; border: 1px solid var(--savia-outline);
  border-radius: var(--savia-radius); font-size: 14px;
  background: var(--savia-background); color: var(--savia-on-surface);
  transition: border-color var(--savia-transition);
}
.form-row input:focus, .form-row select:focus { border-color: var(--savia-primary); outline: none; }
.actions { display: flex; gap: var(--space-2); margin-top: var(--space-4); }
.btn-register {
  flex: 1; padding: 12px; background: var(--savia-primary); color: white;
  border-radius: var(--savia-radius); font-weight: 600; font-size: 14px;
  transition: background var(--savia-transition);
  box-shadow: 0 2px 8px rgba(107, 76, 154, 0.3);
}
.btn-register:hover:not(:disabled) { background: var(--savia-primary-dark); }
.btn-register:disabled { opacity: 0.6; cursor: not-allowed; }
.btn-cancel {
  padding: 12px 20px; background: var(--savia-surface-variant); color: var(--savia-on-surface);
  border-radius: var(--savia-radius); font-size: 14px; transition: background var(--savia-transition);
}
.btn-cancel:hover { background: var(--savia-outline); }
.error-msg { color: var(--savia-error); font-size: 12px; margin: 8px 0; }
</style>
