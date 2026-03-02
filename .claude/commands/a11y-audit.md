---
name: /a11y-audit
description: "Auditoría de accesibilidad WCAG 2.2 completa con escaneo de HTML/componentes. Detecta: alt text faltante, problemas de contraste, navegación por teclado, etiquetas ARIA, gestión de focus, jerarquía de encabezados, etiquetas de formularios. Genera reporte accionable con instrucciones de remediación."
developer_type: all
agent: task
context_cost: medium
---

# /a11y-audit — Auditoría de Accesibilidad WCAG 2.2

Realiza una auditoría exhaustiva de accesibilidad según estándares WCAG 2.2. Analiza componentes HTML, detecta problemas comunes de inclusión digital y proporciona recomendaciones accionables.

## Sintaxis

```bash
/a11y-audit [--url URL] [--scope page|site|component] [--standard WCAG2.2-AA|WCAG2.2-AAA] [--lang es|en]
```

## Parámetros

- `--url URL`: URL o ruta del componente a auditar
- `--scope`: 
  - `page` — Analiza una página individual
  - `site` — Escanea todo el sitio (limitado)
  - `component` — Componente específico
- `--standard`:
  - `WCAG2.2-AA` — Nivel AA (recomendado)
  - `WCAG2.2-AAA` — Nivel AAA (máximo)
- `--lang`: Idioma del reporte (`es` o `en`)

## Problemas Detectados

**Crítico**
- Alt text faltante en imágenes
- Botones sin contenido accesible
- Formularios sin etiquetas
- Navegación sin teclado
- Contraste insuficiente (< 4.5:1)

**Mayor**
- Alt text poco descriptivo
- Etiquetas ARIA conflictivas
- Encabezados saltados
- Focus trap
- Iframe sin título

**Menor**
- Iconos sin descripción
- Title innecesarios
- Orden de tabulación subóptimo
- Espaciado insuficiente táctil

## Salida

Reporte con:
- Puntuación 0-100
- Problemas por severidad
- Ubicación exacta en DOM
- Código problemático
- Instrucciones de fix
- Métricas WCAG
- Tendencia histórica

## Ejemplos

```bash
/a11y-audit --url https://ejemplo.com --scope site --standard WCAG2.2-AA
/a11y-audit --url ./components/button.html --scope component --lang es
/a11y-audit --url /dashboard --scope page --standard WCAG2.2-AAA
```

## Características

**Análisis Profundo**: Estructura HTML, atributos, CSS, estados focus, tabindex.

**Compatibilidad**: axe, WAVE, Lighthouse.

**Accionable**: Código correctivo incluido.

**Multiidioma**: Español e inglés.

**Legal**: Conformidad WCAG 2.2 AA/AAA.

## Uso

Para desarrolladores, QA y arquitectos de calidad garantizando experiencias inclusivas.
