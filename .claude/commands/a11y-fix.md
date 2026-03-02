---
name: /a11y-fix
description: "Correcciones automáticas de accesibilidad con verificación y preview. Genera código de fix para issues detectados por /a11y-audit. Preview antes de aplicar. Verifica que no introduce nuevos problemas. Covers: alt text, ARIA attributes, focus traps, skip links, color contrast."
developer_type: all
agent: task
context_cost: medium
---

# /a11y-fix — Correcciones Automáticas de Accesibilidad

Aplica soluciones automáticas a problemas de accesibilidad detectados. Incluye preview, verificación y rollback seguro.

## Sintaxis

```bash
/a11y-fix [--issue ID] [--auto] [--preview] [--lang es|en]
```

## Parámetros

- `--issue ID`: ID del problema de /a11y-audit
- `--auto`: Aplicar fix automáticamente sin confirmar
- `--preview`: Mostrar cambios antes de aplicar
- `--lang`: Idioma (`es` o `en`)

## Tipos de Correcciones

**Alt Text**
- Generación automática de descripciones
- Validación de especificidad
- Detección de imágenes decorativas

**ARIA Attributes**
- Agregar roles ARIA faltantes
- Corrección de aria-label
- Validación de aria-labelledby

**Focus Management**
- Agregar tabindex cuando sea necesario
- Crear skip links
- Resolver focus traps
- Restaurar focus después de modales

**Color Contrast**
- Ajuste automático de colores
- Sugerencias de paletas accesibles
- Validación WCAG AA/AAA

**Etiquetas de Formularios**
- Asociar labels con inputs
- Agregar aria-describedby
- Validar requerimiento de campos

## Flujo

1. Muestra preview de cambios
2. Ejecuta fix con rollback automático
3. Verifica que no hay nuevos problemas
4. Genera reporte de cambios aplicados
5. Proporciona historial para auditoría

## Ejemplos

```bash
/a11y-fix --issue IMG-001 --preview --lang es
/a11y-fix --issue ARIA-042 --auto
/a11y-fix --issue CONTRAST-015 --preview
```

## Características

**Seguro**: Preview y rollback automático.

**Verificador**: Valida post-fix.

**Accionable**: Historial de cambios.

**Inteligente**: Análisis contextual.

**Flexible**: Manual o automático.

## Integración

Compatible con /a11y-audit para flujo completo de remediación.
