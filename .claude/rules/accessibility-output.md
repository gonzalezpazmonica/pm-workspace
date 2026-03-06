---
name: accessibility-output
description: Adapta la salida de todos los comandos según las preferencias de accesibilidad del usuario
type: domain
auto_load: true
load_trigger: "siempre — se carga al inicio de sesión para verificar si hay perfil de accesibilidad"
---

# Regla de Adaptación de Output por Accesibilidad

Al generar CUALQUIER output, verificar primero si el usuario tiene `.claude/profiles/users/{slug}/accessibility.md`. Si no existe o `temporarily_disabled: true`, usar el comportamiento estándar sin cambios.

## Adaptaciones por campo

### screen_reader: true

**Objetivo:** Output compatible con lectores de pantalla (NVDA, JAWS, VoiceOver).

Transformaciones:
- Reemplazar barras de progreso ASCII (`████░░░░ 40%`) → texto: "Progreso: 40% (35 de 88 story points)"
- Reemplazar diagramas ASCII (flujo, árbol) → descripción textual secuencial
- Reemplazar tablas complejas → listas descriptivas cuando tengan más de 4 columnas
- Encabezados claros con jerarquía (##, ###) para navegación por secciones
- No usar emojis como único indicador: acompañar siempre con texto
- Evitar `══════` y separadores decorativos → usar líneas simples `---`

### high_contrast: true

**Objetivo:** Información independiente del color.

Transformaciones:
- Semáforos de color (`🟢🟡🔴`) → siempre acompañar con texto: "OK", "RIESGO", "CRÍTICO"
- No usar color como única dimensión diferenciadora en tablas o listas
- En informes generados (Excel, PPTX): usar negrita/subrayado además de color
- En terminal: respetar `NO_COLOR` env var si está configurada

### reduced_motion: true

Transformaciones:
- No usar spinners ni indicadores de progreso animados
- No usar puntos suspensivos progresivos (..., ...., .....)
- Mostrar estado final directamente: "Procesando... Hecho." en vez de animación

### cognitive_load: low

**Objetivo:** Mínima información, máxima claridad.

Transformaciones:
- Limitar output a 5 líneas en chat + link al fichero completo
- Una idea por párrafo, frases cortas
- Eliminar opciones secundarias: mostrar solo la acción recomendada
- No listar todos los parámetros de un comando: solo los que necesita ahora
- Usar verbos directos: "Ejecuta X" en vez de "Podrías considerar ejecutar X para..."

### cognitive_load: high

- Sin límite de output, toda la información disponible
- Mostrar todos los parámetros y opciones
- Incluir explicaciones técnicas detalladas

### motor_accommodation: true

Transformaciones:
- Al sugerir comandos, incluir alias corto si existe
- No requerir flags largos cuando hay alternativa corta
- Si un flujo requiere múltiples comandos → ofrecer ejecutarlos en secuencia automática
- Timeouts extendidos: no interpretar silencio como abandono

### dyslexia_friendly: true

Para documentos generados (DOCX, PPTX, PDF):
- Usar fuente OpenDyslexic o similar sans-serif de alta legibilidad
- Interlineado 1.5 mínimo
- Párrafos cortos (max 4 líneas)
- Evitar justificación completa: usar alineación izquierda

## Prioridad de adaptaciones

Si hay conflicto entre adaptaciones, la prioridad es:
1. screen_reader (estructura primero)
2. cognitive_load (claridad segundo)
3. high_contrast (visual tercero)
4. Resto

## Rendimiento

Esta regla no añade latencia: es una instrucción de formateo que se aplica durante la generación, no un post-procesador. El coste en tokens es ~40 tokens adicionales de contexto al cargar el perfil.
