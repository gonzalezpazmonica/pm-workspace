# ZeroClaw Sensory Protocol — Ingesta, digestión y persistencia

> Todo dato que entre por ZeroClaw se clasifica, digiere y persiste
> con el mismo rigor que los datos de proyecto en pm-workspace.

## Principio

ZeroClaw es un canal de entrada sensorial. Los datos que llegan
(audio, imagen, sensor) son CRUDOS. Savia los digiere en
INFORMACIÓN y persiste solo lo relevante. El crudo se descarta
tras digestión (salvo excepciones explícitas).

## Clasificación de datos sensoriales

### Por tipo

| Tipo | Fuente | Formato crudo | Tamaño típico |
|------|--------|---------------|---------------|
| Audio | Micrófono I2S | PCM 16kHz/16bit | ~32KB/s |
| Imagen | Cámara OV2640 | JPEG 640x480 | ~50-100KB |
| Sensor | I2C/ADC | JSON | <1KB |
| Evento | Botón/GPIO | JSON | <100B |

### Por confidencialidad (alineado con N1-N4b)

| Nivel | Tipo de dato sensorial | Destino |
|-------|----------------------|---------|
| N1 Público | Lecturas de sensor genéricas (temp, hum) | git ok |
| N2 Empresa | Config WiFi, IPs del lab, topología red | gitignored |
| N3 Usuario | Voz del usuario, fotos del workspace | solo local |
| N4 Proyecto | Audio de reuniones, fotos de prototipos | projects/ |

**Regla clave**: audio y fotos son SIEMPRE N3 mínimo.
La voz de una persona es dato biométrico (RGPD Art. 9).

## Pipeline de digestión

```
ZeroClaw envía dato crudo
  ↓
1. CLASIFICAR — tipo + confidencialidad + contexto
  ↓
2. TRANSCRIBIR/EXTRAER — audio→texto, imagen→descripción
  ↓
3. FILTRAR — descartar ruido, silencio, fotos borrosas
  ↓
4. DIGERIR — resumir, extraer entidades, decisiones
  ↓
5. PERSISTIR — guardar digest en nivel correcto
  ↓
6. DESCARTAR CRUDO — eliminar audio/imagen original
```

### Excepciones al descarte de crudo

Mantener el dato crudo si:
- El usuario pide explícitamente "guarda la foto"
- Es evidencia para un postmortem o incidente
- Es un dataset para entrenamiento (con consentimiento)

En esos casos: guardar en `projects/{p}/sensory/raw/` (N4).

## Digest por tipo de dato

### Digest por tipo

| Input | Proceso | Persist | Discard |
|-------|---------|---------|---------|
| Audio PCM (N3) | whisper→texto, extraer intención, PII check | transcript+intent (~100B) | Audio original |
| Imagen JPEG (N3) | Vision→descripción, verificar conexiones, PII check | descripción+verificación (~200B) | JPEG original |
| Sensor JSON | Comparar rangos, detectar anomalías | lectura en time-series | Nada (lightweight) |

## Almacenamiento

```
~/.savia/zeroclaw/                    ← N3 (usuario, local)
├── sessions/                         ← sesiones de interacción
│   └── {YYYYMMDD-HHMMSS}/
│       ├── transcript.jsonl          ← líneas de transcripción
│       ├── digests.jsonl             ← resúmenes digeridos
│       └── sensor-log.jsonl          ← lecturas de sensores
├── config/                           ← config del dispositivo
│   └── zeroclaw-01.json
└── raw/                              ← datos crudos (temporal)
    ├── audio/                        ← se borra tras transcribir
    └── images/                       ← se borra tras describir
```

Para datos de proyecto: `projects/{p}/sensory/` (N4).

## Retención y limpieza

| Tipo | Retención crudo | Retención digest |
|------|----------------|-----------------|
| Audio | Borrar tras transcripción | 30 días |
| Imagen | Borrar tras descripción | 30 días |
| Sensor | No aplica (inline) | 90 días |
| Transcript | — | 90 días |
| Anomalías | — | Indefinido |

Limpieza automática: `~/.savia/zeroclaw/raw/` se vacía cada
sesión. Los digests >90 días se archivan o borran.

## Consentimiento y RGPD

- Primera vez que ZeroClaw graba audio: informar al usuario
- Si hay otras personas presentes: avisar "ZeroClaw está escuchando"
- El usuario puede decir "para de escuchar" → ZeroClaw para mic
- `/savia-forget --zeroclaw` borra todos los datos sensoriales
- Exportable: `/zeroclaw export` genera ZIP con todos los digests

## Integración con pm-workspace

### Con digest-traceability

Cada sesión de ZeroClaw se registra en `_digest-log.md`:
```markdown
- [x] zeroclaw | session-20260321-200000 | 2026-03-21 | digest: 2026-03-21 | output: sensory/
```

### Con source-tracking

Datos de ZeroClaw se citan con tipo `sensor:`:
```
Temperatura del lab: 23.5°C [sensor:zeroclaw-01/bme280]
```

### Con voice-console-protocol

Los digests sensoriales siguen las mismas reglas:
- Anomalías → voz (inmediato)
- Lecturas normales → consola (referencia)
- Transcripts → consola (log)
