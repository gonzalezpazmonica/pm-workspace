---
name: nctalk-search
description: >
  Buscar mensajes en Nextcloud Talk como contexto.
  Decisiones, acuerdos y conversaciones del equipo.
---

# Nextcloud Talk Search

**Argumentos:** $ARGUMENTS

> Uso: `/nctalk:search {query}` o `/nctalk:search --room {sala} {query}`

## Parámetros

- `{query}` — Texto a buscar en los mensajes
- `--room {sala}` — Buscar solo en una sala específica
- `--since {fecha}` — Desde cuándo buscar (YYYY-MM-DD, defecto: 30 días)
- `--limit {n}` — Máximo de resultados (defecto: 20)
- `--participant {nombre}` — Filtrar por participante
- `--context {n}` — Mensajes de contexto antes/después (defecto: 2)

## Contexto requerido

1. @.claude/rules/messaging-config.md — Config Nextcloud Talk
2. Acceso a la API REST de Nextcloud Talk

## Pasos de ejecución

### 1. Verificar conexión
- Comprobar `NCTALK_ENABLED = true` y acceso a la API

### 2. Buscar mensajes
- `GET /ocs/v2.php/apps/spreed/api/v4/room` → listar salas
- Si `--room` → filtrar por sala
- `GET /ocs/v2.php/apps/spreed/api/v4/chat/{token}?lookIntoFuture=0`
- Paginar y filtrar por query + fecha + participante

### 3. Presentar resultados

```
## Nextcloud Talk Search — "{query}"
Resultados: 3 mensajes en 1 sala (últimos 30 días)

### Sala "Equipo Sala Reservas"
[2026-02-25 11:00] Ana García:
  "La arquitectura del nuevo módulo será hexagonal, lo confirmamos"
  → contexto: discusión técnica post-sprint review

[2026-02-26 16:00] Carlos Sanz:
  "Los tests de integración del módulo de pagos están fallando
   por el cambio en la API del banco"
  → contexto: reporte de bug

[2026-02-27 09:30] Pedro López:
  "He subido el diagrama de la nueva arquitectura a /docs/"
  → adjunto: arquitectura-v2.drawio
```

## Ejemplos

```bash
/nctalk:search "arquitectura"
/nctalk:search --room "equipo-sala-reservas" "decisión"
/nctalk:search --participant "Ana García" --since 2026-02-01
```

## Restricciones

- Solo lectura — no modifica ni borra mensajes
- La API de Nextcloud Talk no tiene búsqueda full-text nativa;
  se descarga historial y se filtra localmente
- Rendimiento depende del volumen del historial de la sala
