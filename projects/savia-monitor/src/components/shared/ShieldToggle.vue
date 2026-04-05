<script setup lang="ts">
defineProps<{
  modelValue: boolean
}>()

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
}>()
</script>

<template>
  <label class="shield-toggle" :class="{ 'shield-toggle--on': modelValue }">
    <input
      type="checkbox"
      :checked="modelValue"
      class="shield-toggle__input"
      @change="emit('update:modelValue', !modelValue)"
    />
    <span class="shield-toggle__track">
      <span class="shield-toggle__thumb" />
    </span>
    <span class="shield-toggle__label">
      {{ modelValue ? 'Shield ON' : 'Shield OFF' }}
    </span>
  </label>
</template>

<style scoped>
.shield-toggle {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  cursor: pointer;
  user-select: none;
}

.shield-toggle__input {
  position: absolute;
  opacity: 0;
  width: 0;
  height: 0;
}

.shield-toggle__track {
  position: relative;
  width: 40px;
  height: 22px;
  border-radius: 11px;
  background: var(--savia-outline);
  transition: background var(--savia-transition);
}

.shield-toggle--on .shield-toggle__track {
  background: var(--savia-success);
}

.shield-toggle__thumb {
  position: absolute;
  top: 2px;
  left: 2px;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #fff;
  box-shadow: var(--savia-shadow);
  transition: transform var(--savia-transition);
}

.shield-toggle--on .shield-toggle__thumb {
  transform: translateX(18px);
}

.shield-toggle__label {
  font-size: 12px;
  font-weight: 600;
  color: var(--savia-on-surface);
}
</style>
