---
globs: [".opencode/commands/**"]
---

# Anexo: UX Feedback — Checklists Detalladas
# ── Patrones de error, retry flow, ejemplos de feedback interactivo ────────

## Checklist de Requisitos

**ANTES de ejecutar la lógica:**
```
✅ Proyecto encontrado: projects/alpha/CLAUDE.md
✅ Azure DevOps configurado (PAT válido)
✅ Equipo.md encontrado
❌ Falta: AZURE_DEVOPS_ORG_URL contiene placeholder "MI-ORGANIZACION"
```

Si falta configuración → Modo interactivo:
1. Informar qué falta y por qué
2. Preguntar al PM si quiere configurarlo ahora
3. Pedir datos uno a uno (interactivamente)
4. Escribir configuración en fichero
5. Confirmar que se ha guardado
6. Reintentar comando automáticamente

Ejemplo:
```
❌ Falta: AZURE_DEVOPS_ORG_URL contiene placeholder "MI-ORGANIZACION"
  Este dato es necesario para conectar con tu organización Azure DevOps.
  → ¿Cuál es la URL de tu organización?
    Ejemplo: https://dev.azure.com/mi-empresa
  PM responde: https://dev.azure.com/acme-corp
  ✅ Guardado AZURE_DEVOPS_ORG_URL = "https://dev.azure.com/acme-corp"
     en CLAUDE.md
  → Reintentando verificación...
```

## Progreso durante Ejecución

Para comandos con múltiples pasos:
```
📋 Paso 1/4 — Recopilando datos del sprint...
📋 Paso 2/4 — Calculando métricas DORA (esto puede tardar ~30s)...
📋 Paso 3/4 — Analizando deuda técnica...
📋 Paso 4/4 — Generando informe...
```

## Manejo de Errores

**Errores no-críticos (continuar disponible):**
```
⚠️ Error en paso 2/4 — No se pudo conectar con Azure DevOps
   Causa: PAT expirado o sin permisos de lectura
   Acción sugerida: Regenera el PAT en dev.azure.com → User Settings → PATs
   ¿Quieres continuar sin los datos de pipelines? (el informe será parcial)
```

**Errores críticos (parar):**
```
❌ Error crítico — No se encontró projects/{proyecto}/CLAUDE.md
   Este fichero es obligatorio para identificar el proyecto.
   Ejecuta `/help --setup` para configurar el proyecto,
   o crea el fichero manualmente siguiendo la plantilla en docs/SETUP.md
```

## Banners de Finalización

**Éxito completo:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /comando:nombre — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Informe guardado en: output/YYYYMMDD-tipo-proyecto.md
⏱️  Duración: ~45s
```

**Éxito parcial (con avisos):**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ /comando:nombre — Completado con avisos
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Informe guardado en: output/YYYYMMDD-tipo-proyecto.md
⚠️  2 dimensiones sin datos (marcadas N/A)
⏱️  Duración: ~30s
```

**Error irrecuperable:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ /comando:nombre — No ejecutado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Motivo: No se encontró el proyecto "alpha"
Sugerencia: Ejecuta `/help --setup` para ver proyectos configurados
```

## Retry Flow

1. Fallo por configuración
2. Pedir dato interactivamente
3. Guardar en fichero
4. Reintentar comando automáticamente
5. Si sigue fallando → error explícito con sugerencias
