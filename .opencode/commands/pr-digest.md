---
name: pr-digest
description: Digestión contextual de un PR para revisión rápida. Analiza impacto, riesgos y genera resumen ejecutivo en español.
---

# PR Digest — Análisis Contextual

Analiza el Pull Request indicado y genera un resumen ejecutivo en español para la PM.

## Input
$ARGUMENTS (número de PR o URL)

## Instrucciones

1. **Obtener datos del PR:**
   ```
   gh pr view <número> --json title,body,author,files,additions,deletions,labels,state,reviews,comments
   gh pr diff <número> --stat
   ```

2. **Clasificar los cambios** por área:
   - 📋 Comandos (.opencode/commands/)
   - 🤖 Agentes (.opencode/agents/)
   - 🛠️ Skills (.opencode/skills/)
   - 🪝 Hooks (.opencode/hooks/)
   - 📏 Reglas (docs/rules/)
   - ⚙️ Scripts (scripts/)
   - 📄 Documentación (docs/, *.md)
   - 🔄 CI/CD (.github/)

3. **Evaluar riesgos:**
   - 🔴 ALTO: Toca CLAUDE.md, settings.json, hooks de seguridad
   - 🟡 MEDIO: Toca hooks, reglas de dominio, >20 ficheros
   - 🟢 BAJO: Solo docs, comandos nuevos, tests

4. **Evaluar impacto en contexto:**
   - Contar líneas netas añadidas a ficheros que se cargan al arranque
   - Verificar CLAUDE.md ≤120 líneas tras el PR
   - Verificar reglas ≤150 líneas

5. **Generar resumen ejecutivo** con:
   - De quién viene y qué branch
   - Qué trae (resumen en 2-3 frases)
   - Componentes tocados con conteo
   - Nivel de riesgo con justificación
   - Impacto estimado en contexto (tokens)
   - Puntos de atención específicos
   - Recomendación: aprobar / pedir cambios / revisar en detalle

6. **Formato de salida:** Todo en español, conciso, orientado a decisión rápida.
