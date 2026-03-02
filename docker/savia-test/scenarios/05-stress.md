# Scenario 05 — Stress Test (Context Overflow)

Force context saturation with 10+ concurrent specs to detect limits.

## Step 1
- **Role**: Elena
- **Command**: flow-spec-batch

```prompt
Eres Savia. Elena necesita escribir 6 specs de golpe para acelerar el proyecto SocialApp. Genera specs para: SPEC-005 Timeline Feed (O-004), SPEC-006 Push Notifications (O-005), SPEC-007 Search Users (O-003), SPEC-008 Direct Messages (nuevo outcome O-006), SPEC-009 Media Upload (O-002), SPEC-010 Hashtag Trending (O-002). Cada spec con las 5 secciones SDD completas. Esto fuerza la ventana de contexto al máximo.
```

## Step 2
- **Role**: Mónica
- **Command**: flow-intake-batch

```prompt
Eres Savia. Mónica ejecuta intake masivo de las 6 specs creadas (SPEC-005 a SPEC-010) más las 2 pendientes (SPEC-003, SPEC-004). Total 8 specs en Spec-Ready. El equipo solo tiene capacidad para 4 (Ana WIP 2, Isabel WIP 2). Ejecuta flow-intake validando las 8 specs simultáneamente. Esto debe provocar alertas de WIP overflow y saturación del contexto al cargar 8 specs completas.
```

## Step 3
- **Role**: Mónica
- **Command**: flow-board-full

```prompt
Eres Savia. Visualiza el tablero completo con 10 specs en diferentes estados: 4 en Exploration (Spec-Ready), 4 en Production (2 Building + 2 Ready), 2 en Gates. Más los 6 outcomes originales. Esto genera un tablero de ~60 items. Renderiza el tablero dual-track completo sin filtros. Mide si el contexto puede manejar esta carga.
```

## Step 4
- **Role**: Mónica
- **Command**: flow-metrics-full

```prompt
Eres Savia. Ejecuta flow-metrics con trend de 8 semanas para un proyecto con 10 specs activas. Calcula cycle time, lead time, throughput, CFR para cada spec individual. Añade métricas por persona (Ana: 3 specs, Isabel: 4 specs, Elena: 10 specs escritas). Genera dashboard completo + interpretación + recomendaciones. Esto fuerza el máximo consumo de tokens de salida.
```

## Step 5
- **Role**: Equipo
- **Command**: retro-summary-full

```prompt
Eres Savia. Genera retrospectiva completa del proyecto SocialApp con 10 specs, 6 outcomes, 4 personas, 8 semanas de datos. Incluye: qué fue bien (5+ items), qué mejorar (5+ items), acciones (5+ items), métricas detalladas por persona y por spec, evolución semanal, comparativa con targets DORA, análisis de context overflow detectados, recomendaciones de optimización. Este es el comando más pesado de todo el harness.
```
