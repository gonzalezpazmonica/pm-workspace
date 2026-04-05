<script setup lang="ts">
import type { HookProfile } from '@/stores/shield'
import { useI18n } from '@/locales/i18n'

const { t } = useI18n()

defineProps<{
  modelValue: HookProfile
}>()

const emit = defineEmits<{
  'update:modelValue': [value: HookProfile]
}>()

const profiles: { value: HookProfile; key: string }[] = [
  { value: 'minimal', key: 'profile.minimal' },
  { value: 'standard', key: 'profile.standard' },
  { value: 'strict', key: 'profile.strict' },
  { value: 'ci', key: 'profile.ci' },
]
</script>

<template>
  <div class="profile-selector">
    <label class="profile-selector__label">{{ t('profile.label') }}</label>
    <select
      :value="modelValue"
      class="profile-selector__select"
      @change="emit('update:modelValue', ($event.target as HTMLSelectElement).value as HookProfile)"
    >
      <option v-for="p in profiles" :key="p.value" :value="p.value">
        {{ t(p.key) }}
      </option>
    </select>
  </div>
</template>

<style scoped>
.profile-selector { display: inline-flex; align-items: center; gap: var(--space-2); }
.profile-selector__label { font-size: 12px; font-weight: 600; color: var(--savia-on-surface-variant); }
.profile-selector__select {
  appearance: none; -webkit-appearance: none;
  background: var(--savia-surface-variant);
  border: 1px solid var(--savia-glass-border);
  border-radius: var(--savia-radius);
  padding: var(--space-1) var(--space-6) var(--space-1) var(--space-3);
  font-size: 12px; font-weight: 500; color: var(--savia-on-surface);
  cursor: pointer; transition: border-color var(--savia-transition);
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%23625B71' stroke-width='2'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E");
  background-repeat: no-repeat; background-position: right 8px center;
}
.profile-selector__select:hover { border-color: var(--savia-primary-light); }
.profile-selector__select:focus-visible { outline: 2px solid var(--savia-primary); outline-offset: 2px; }
</style>
