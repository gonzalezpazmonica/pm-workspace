---
context_tier: L3
token_budget: 1200
resource: internal://docs/rules/domain/kokoro-voice-protocol.md
se: SE-075
slice: 3
status: IMPLEMENTED
---

# Kokoro Voice Protocol — SE-075 Slice 3

> 100% local CPU TTS for Savia. Zero data leaves the machine.

## Qué es Kokoro

Kokoro 82M (`hexgrad/Kokoro-82M`) es un modelo TTS ligero (~82M parámetros)
que corre en CPU con latencia ~150x realtime. Sin GPU, sin cloud, sin tokens.
Sopota español e inglés con calidad media-alta.

## Activación

```bash
# Switch maestro — por defecto OFF para no generar audio inesperado
export SAVIA_VOICE=on

# Sintetizar y reproducir (si aplay disponible)
bash scripts/savia-voice-speak.sh "Texto a hablar"

# Sintetizar sin reproducir — solo genera el fichero
bash scripts/savia-voice-speak.sh "Texto" --no-play

# CLI directo con JSON output
python3 scripts/savia-kokoro.py \
    --text "Hola mundo" \
    --output /tmp/out.wav \
    --json
```

## Voces disponibles

| Voice ID   | Idioma   | Género   | Cuándo usar |
|------------|----------|----------|-------------|
| `ef_dora`  | Español  | Femenino | Default Savia — español (ES/LATAM) |
| `em_alex`  | Español  | Masculino | Variación masculina en español |
| `af_heart` | Inglés   | Femenino | Textos en inglés, documentación |
Selección de voz:

```bash
# Por parámetro
python3 scripts/savia-kokoro.py --text "Hello" --voice af_heart --lang en-us --output /tmp/en.wav

# Por variable de entorno
export SAVIA_KOKORO_VOICE=em_alex
bash scripts/savia-voice-speak.sh "Texto en voz masculina"
```

## Variables de entorno

| Variable              | Default    | Descripción |
|-----------------------|------------|-------------|
| `SAVIA_VOICE`         | `off`      | Master switch — `on` para activar |
| `SAVIA_KOKORO_VOICE`  | `ef_dora`  | Voz por defecto |
| `SAVIA_KOKORO_LANG`   | `es`       | Código de idioma |
| `SAVIA_KOKORO_SPEED`  | `1.0`      | Velocidad (0.5–2.0) |
| `SAVIA_TTS_CMD`       | kokoro     | Override completo del backend TTS en voice-chunk.sh |
## Chunking automático

Textos >500 caracteres se dividen automáticamente en frases usando
`scripts/lib/sentence-splitter.py` (español-aware: abreviaturas Sr./Dr./etc.).
Los chunks se sintetizan y concatenan de forma transparente.

Para textos muy largos (notas, summaries), usar `savia-voice-chunk.sh`
directamente, que soporta concurrencia controlada (default 2 workers):

```bash
bash scripts/savia-voice-chunk.sh --file nota.txt --out /tmp/nota.wav
```

`savia-voice-chunk.sh` ya usa Kokoro como backend primario si está disponible,
con fallback a espeak-ng/espeak si no lo está.

## Integración con voice-inbox

La skill `voice-inbox` (`.opencode/skills/voice-inbox/SKILL.md`) usa
Whisper para **transcripción de entrada** (speech → text).
Kokoro cubre el lado **complementario** de salida (text → speech):

```
Entrada de voz → [whisper-env] → texto → Savia procesa → [Kokoro] → respuesta hablada
```

Para activar respuestas habladas en voice-inbox, añadir a la config:

```bash
export SAVIA_VOICE=on
```

## Telemetría

Cada síntesis escribe un registro en `output/kokoro-telemetry.jsonl`:

```json
{"ts": "2026-06-24T19:00:00Z", "voice": "ef_dora", "lang": "es",
 "duration_s": 2.4, "chars": 120, "ok": true}
```

Campos: `ts` (UTC ISO-8601), `voice`, `lang`, `duration_s` (audio generado),
`chars` (longitud texto entrada), `ok` (bool éxito).

## Privacidad

**Kokoro es 100% local.** El modelo descarga los pesos desde HuggingFace
(`hexgrad/Kokoro-82M`) en el primer uso y los cachea en `~/.cache/huggingface/`.
Tras la descarga inicial, funciona completamente offline. Ningún texto de
síntesis sale del equipo.

Comparativa con alternativas cloud:

| | Kokoro (este SE) | Cloud TTS (ElevenLabs/etc.) | SE-042 (GPU) |
|---|---|---|---|
| GPU requerida | No | No | Sí |
| Calidad ES | Media-alta | Alta | Alta personalizada |
| Latencia | ~150x RT en CPU | Red (100-500ms) | N/A |
| Privacidad | 100% local | Datos a cloud | 100% local |
| Estado | IMPLEMENTADO | Disponible con API key | GPU-blocked |
## Troubleshooting

**Kokoro no instalado:**
```
pip install kokoro soundfile
```

**Primer uso lento:** descarga pesos ~500MB de HuggingFace (una sola vez).

**Sin audio después de sintetizar:** verificar `SAVIA_VOICE=on`; si `--no-play`,
la ruta del fichero se imprime por stdout.

**HF_TOKEN para evitar rate-limit:**
```bash
export HF_TOKEN=hf_...
```

## Referencias

- Script: `scripts/savia-kokoro.py` — CLI wrapper
- Script: `scripts/savia-voice-speak.sh` — integración high-level
- Script: `scripts/savia-voice-chunk.sh` — chunker (usa Kokoro como backend)
- Spec: `docs/propuestas/SE-075-voicebox-adoption.md`
- Skill: `.opencode/skills/voice-inbox/SKILL.md` — transcripción entrada
- Modelo: `hexgrad/Kokoro-82M` (MIT)