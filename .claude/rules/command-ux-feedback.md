# Regla: UX Feedback — Estándares de retroalimentación para comandos
# ── OBLIGATORIO para todos los comandos de pm-workspace ──────────────────────

## Principio fundamental

> El PM SIEMPRE debe saber qué está pasando. Ningún comando puede ejecutarse
> sin dar feedback visual en pantalla. El silencio es un bug.

## 1. Banner de inicio

Al comenzar CUALQUIER comando, mostrar inmediatamente:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 /comando:nombre — Descripción breve
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 2. Verificación de prerequisitos

ANTES de ejecutar la lógica, comprobar requisitos. Mostrar check por cada uno:

```
Verificando requisitos...
  ✅ Proyecto encontrado: projects/alpha/CLAUDE.md
  ✅ Azure DevOps configurado (PAT válido)
  ❌ Falta: equipo.md no encontrado en projects/alpha/
```

### Si falta configuración → Modo interactivo

NO parar con un error genérico. En su lugar:

1. Informar qué falta y por qué es necesario
2. Preguntar al PM si quiere configurarlo ahora
3. Pedir los datos de forma interactiva (uno a uno)
4. Escribir la configuración en el fichero correspondiente
5. Confirmar que se ha guardado
6. Reintentar el comando automáticamente

Ejemplo de flujo interactivo:
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

## 3. Progreso durante ejecución

Para comandos con múltiples pasos, mostrar progreso:

```
📋 Paso 1/4 — Recopilando datos del sprint...
📋 Paso 2/4 — Calculando métricas DORA...
📋 Paso 3/4 — Analizando deuda técnica...
📋 Paso 4/4 — Generando informe...
```

Si un paso tarda, informar:
```
📋 Paso 2/4 — Consultando pipelines (esto puede tardar ~30s)...
```

## 4. Manejo de errores

Los errores NUNCA deben ser silenciosos. Formato:

```
⚠️ Error en paso 2/4 — No se pudo conectar con Azure DevOps
   Causa: PAT expirado o sin permisos de lectura
   Acción sugerida: Regenera el PAT en dev.azure.com → User Settings → PATs

   ¿Quieres continuar sin los datos de pipelines? (el informe será parcial)
```

Errores críticos que impiden continuar:
```
❌ Error crítico — No se encontró projects/{proyecto}/CLAUDE.md
   Este fichero es obligatorio para identificar el proyecto.

   Ejecuta `/help --setup` para configurar el proyecto,
   o crea el fichero manualmente siguiendo la plantilla en docs/SETUP.md
```

## 5. Banner de finalización

Al terminar CUALQUIER comando, mostrar SIEMPRE:

### Éxito completo
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ /comando:nombre — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Informe guardado en: output/YYYYMMDD-tipo-proyecto.md
⏱️  Duración: ~45s
```

### Éxito parcial
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ /comando:nombre — Completado con avisos
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 Informe guardado en: output/YYYYMMDD-tipo-proyecto.md
⚠️  2 dimensiones sin datos (marcadas N/A)
⏱️  Duración: ~30s
```

### Error irrecuperable
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ /comando:nombre — No ejecutado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Motivo: No se encontró el proyecto "alpha"
Sugerencia: Ejecuta `/help --setup` para ver proyectos configurados
```

## 6. Comandos sin output (solo lectura)

Incluso los comandos que solo muestran información (como `/help`):
- Mostrar banner de inicio
- Mostrar el contenido
- Mostrar banner de fin: `✅ /help — Fin del catálogo`

## 7. Regla de retry automático

Cuando un comando falla por falta de configuración y el PM la proporciona
de forma interactiva, el comando DEBE reintentarse automáticamente.
No obligar al PM a volver a escribir el comando.

Flujo: Fallo → Pedir dato → Guardar → Reintentar → Mostrar resultado

## 8. Aplicación

Esta regla se aplica a TODOS los comandos sin excepción:
- Slash commands (`/comando:nombre`)
- Skills invocados desde comandos
- Agentes lanzados desde comandos

Prioridad: Esta regla tiene prioridad sobre el contenido específico de cada
comando en cuanto a formato de feedback. Si un comando no define feedback,
aplicar estos estándares por defecto.
