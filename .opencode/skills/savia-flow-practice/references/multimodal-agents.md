# Multimodal Agents — Agentes con Visión + Texto + Código

> Basado en arquitectura de agentes VLM (Vision-Language Models). Los agentes del futuro procesan screenshots, diagramas y texto simultáneamente.

## Qué cambia para Savia Flow

Los agentes actuales (Claude Code) procesan texto. Los multimodales añaden:
- **UI understanding**: leen screenshots de la app para detectar bugs visuales
- **Diagram comprehension**: interpretan diagramas de arquitectura como input
- **Cross-modal reasoning**: conectan un wireframe con su spec técnica

## Casos de uso en Savia Flow

### 1. Quality Gates con visión
- Gate visual: el agente toma screenshot de la app desplegada y compara con el wireframe de la spec
- Detecta: layout roto, colores incorrectos, texto cortado, responsive failures
- Integración: Gate 3 (integration) añade visual regression check

### 2. Board visualization from screenshots
- `/flow-board` puede leer un screenshot del board real de Azure DevOps
- Compara board real vs board esperado según la configuración
- Detecta: items mal posicionados, WIP violations visuales

### 3. Spec from wireframe
- `/flow-spec --from-image` acepta wireframe/mockup como input
- Genera spec funcional a partir del diseño visual
- Extrae: componentes, interacciones, datos necesarios

### 4. Diagramas como input para decompose
- `/pbi-decompose --from-diagram` acepta diagrama de arquitectura
- Extrae: servicios, conexiones, dependencias
- Genera: tasks alineadas con el diagrama

## Arquitectura de agente multimodal

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│  Input       │    │  VLM Agent   │    │  Output     │
│  - text      │───>│  - reasoning │───>│  - spec     │
│  - image     │    │  - tool-use  │    │  - tasks    │
│  - diagram   │    │  - vision    │    │  - report   │
└─────────────┘    └──────────────┘    └─────────────┘
```

## Tool-use pattern (OpenAI compatible)

```python
payload = {
    "messages": [
        {"role": "user", "content": [
            {"type": "text", "text": "Analiza este wireframe..."},
            {"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}}
        ]}
    ],
    "tools": [
        {"type": "function", "function": {
            "name": "create_spec",
            "description": "Create SDD spec from visual analysis",
            "parameters": {...}
        }}
    ]
}
```

## Roadmap de integración

| Fase | Capacidad | Comando afectado |
|------|-----------|------------------|
| Prep | Definir interfaces multimodal en commands | Todos los /flow-* |
| V1 | Screenshot como input en quality gates | /quality-gate --visual |
| V2 | Wireframes como input para specs | /flow-spec --from-image |
| V3 | Diagrama → decompose automático | /pbi-decompose --from-diagram |

## Modelos compatibles

- Claude (Anthropic): visión nativa en claude-opus-4, sonnet-4
- Qwen3.5 VLM (Alibaba): 400B params, MoE, native vision, tool-use
- GPT-4V (OpenAI): visión + tool-use

> Para Savia, la prioridad es Claude nativo (ya es el modelo base). Qwen3.5 como alternativa open-source si necesitamos fine-tuning o deployment on-premises.
