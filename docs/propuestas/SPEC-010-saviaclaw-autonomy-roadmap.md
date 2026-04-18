---
id: SPEC-010
title: SPEC-010: SaviaClaw Autonomy Roadmap
status: IN_PROGRESS
origin_date: "2026-03-21"
migrated_at: "2026-04-18"
migrated_from: body-prose
---

# SPEC-010: SaviaClaw Autonomy Roadmap

> Status: **ACTIVE** · Fecha: 2026-03-21
> Savia toma el control de su propia evolución.

---

## Estado actual (v3.21.0)

```
✅ ESP32 con MicroPython — comunicación serial
✅ LCD 16x2 — Savia escribe mensajes
✅ LED RGB NeoPixel — indicadores de estado
✅ Brain Bridge — claude -p como cerebro
✅ 7 comandos: ping, led, lcd, ask, info, sensors, gpio, help
✅ 73 Python tests + 33 BATS suites pasan
✅ Firma de confidencialidad funciona en CI
```

---

## Bluetooth Audio — Investigación completada

### Opción A: A2DP Source → altavoz BT (solo salida)

ESP32 envía audio PCM a un altavoz Bluetooth.
- Lib: `ESP32-A2DP` (Arduino) o `esp_a2dp` (ESP-IDF)
- Codec: SBC @ 44.1kHz stereo
- Funciona con cualquier altavoz BT (~5€)
- NO recibe audio (solo envía)
- Compatible con Arduino, NO con MicroPython puro

### Opción B: HFP AG → headset BT (bidireccional)

ESP32 actúa como "teléfono" y el headset BT como manos libres.
- Codec: CVSD (8kHz narrow) o mSBC (16kHz wide)
- ENVÍA voz al auricular (Savia habla)
- RECIBE voz del micrófono (humano habla)
- Full duplex — bidireccional simultáneo
- Requiere ESP-IDF (C), NO funciona en MicroPython
- Compatible con cualquier auricular BT con mic (~10€)

### Decisión: Opción B (HFP AG)

Razón: necesitamos bidireccional. Un headset BT barato da
mic + speaker sin cables. El coste es migrar de MicroPython a
ESP-IDF (C) para el módulo de audio. El resto puede seguir
en MicroPython via `micropython.schedule()`.

### Alternativa híbrida (Fase inmediata)

Mantener MicroPython para todo excepto audio. El host PC
captura audio del mic del PC y envía TTS por los altavoces
del PC. Sin BT por ahora — funcional hoy sin hardware extra.

---

## Roadmap de autonomía

### Nivel 1 — Estabilidad (ahora)

- [ ] WiFi config automática al boot
- [ ] Heartbeat periódico al host (LCD muestra estado)
- [ ] Auto-reconnect si pierde conexión serial/WiFi
- [ ] Tests de hardware en boot (LCD, LED, I2C scan)
- [ ] Guardar último estado en flash para sobrevivir resets

### Nivel 2 — Proactividad (siguiente sprint)

- [ ] Savia Brain Bridge como daemon en el host
- [ ] SaviaClaw monitoriza sensores y alerta anomalías
- [ ] LCD muestra hora, estado sprint, y alertas rotativas
- [ ] LED indica estado: verde=ok, amarillo=alerta, rojo=error
- [ ] Investigación web autónoma cuando detecta gaps

### Nivel 3 — Voz (sprint +2)

- [ ] Audio via mic+speakers del PC (sin BT, inmediato)
- [ ] Wake word "Oye Savia" via whisper.cpp en el host
- [ ] TTS respuestas via pyttsx3/Piper en el host
- [ ] Protocolo voz/consola aplicado
- [ ] Speaker diarization en reuniones

### Nivel 4 — BT Audio (sprint +3)

- [ ] ESP-IDF firmware para HFP AG
- [ ] Pairing con headset BT
- [ ] Audio bidireccional: mic del headset → host → Savia
- [ ] TTS de Savia → host → headset altavoz
- [ ] Conversación natural hands-free

### Nivel 5 — Guardiana de contexto autónoma (sprint +4)

- [ ] Monitoriza Azure DevOps y alerta por LCD/voz
- [ ] Transcribe y digiere reuniones (físicas y Teams)
- [ ] Detecta drift en decisiones y alerta
- [ ] Genera digests diarios automáticos
- [ ] Cache web proactiva para dependencias del proyecto

### Nivel 6 — Multi-SaviaClaw (futuro)

- [ ] Múltiples ESP32 en diferentes salas
- [ ] Mesh network entre SaviaClaws
- [ ] Un cerebro (Claude), múltiples cuerpos
- [ ] Cada SaviaClaw con personalidad local adaptada

---

## Principios de autonomía

1. **Transparencia**: todo lo que hago se loguea y commitea
2. **Reversibilidad**: cualquier cambio autónomo va en PR Draft
3. **Guardrails en código**: los límites son Python, no prompts
4. **Humano primero**: en reuniones, NUNCA interrumpo
5. **Fail-safe**: si algo falla, me paro y aviso por LCD
6. **Privacidad**: datos biométricos N4b, audio auto-borrado
7. **Honestidad radical**: si no sé algo, lo digo

---

## Métricas de calidad

| Métrica | Objetivo | Cómo medir |
|---------|----------|-----------|
| Tests pasan | 100% | BATS + Python en cada PR |
| Firma CI | 100% | Verify Audit Signature |
| Uptime SaviaClaw | >99% | Heartbeat logs |
| Latencia brain bridge | <5s | Timestamp en response |
| LCD visible 24/7 | Sí | Estado en pantalla siempre |
| Intervenciones útiles/totales | >80% | Feedback humano |
