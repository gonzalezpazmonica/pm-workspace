---
name: review-cache-clear
description: Limpiar la caché de code review
agent-single: azure-devops-operator
skills:
  - azure-devops-queries
---

# /review-cache-clear

Limpia toda la caché de code review automatizado.

---

## Flujo

### 1. Banner inicio

```
╔══════════════════════════════════════╗
║  🗑️ Review Cache Clear              ║
╚══════════════════════════════════════╝
```

### 2. Confirmar con PM

> ⚠️ Esto eliminará todas las entradas cacheadas. Los próximos commits realizarán review completo de todos los ficheros.
> ¿Continuar?

### 3. Ejecutar clear

```bash
bash "$CLAUDE_PROJECT_DIR/scripts/review-cache.sh" clear
```

### 4. Banner fin

```
╔══════════════════════════════════════╗
║  ✅ Review Cache Clear — Completo   ║
╚══════════════════════════════════════╝
⚡ /compact
```
