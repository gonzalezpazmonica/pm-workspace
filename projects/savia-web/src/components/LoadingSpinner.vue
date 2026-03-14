<template>
  <div class="spinner-container">
    <div class="spinner" />
    <p v-if="$slots.default" class="spinner-text">
      <slot />
    </p>
  </div>
</template>

<style scoped>
.spinner-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px;
  gap: 12px;
}
.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--savia-surface-variant);
  border-top-color: var(--savia-primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}
.spinner-text {
  color: var(--savia-on-surface-variant);
  font-size: 14px;
}
</style>
