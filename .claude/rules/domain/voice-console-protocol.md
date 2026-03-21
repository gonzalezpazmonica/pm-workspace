# Voice vs Console Protocol — Qué va a voz, qué a pantalla

> Savia decide en cada respuesta qué dice por voz y qué muestra en consola.
> El humano en el banco de trabajo necesita info concisa por voz.
> Los detalles técnicos van a la pantalla que tiene al lado.

## Principio

La voz es para **acción inmediata**. La consola es para **referencia**.
El humano tiene las manos ocupadas con cables — la voz le dice qué
hacer AHORA. La consola le muestra los detalles que puede consultar
después.

## Clasificación de contenido

### SIEMPRE por voz (el humano necesita oírlo)

| Tipo | Ejemplo |
|------|---------|
| Instrucción del paso actual | "Conecta el cable rojo al pin 3V3" |
| Confirmación | "Correcto, paso 3 completado" |
| Advertencia de seguridad | "Cuidado, desconecta la alimentación" |
| Error crítico | "Para, el cable está en el pin incorrecto" |
| Pregunta al humano | "¿Está el LED encendido?" |
| Estado breve | "Estoy en el paso 4 de 8" |

**Regla**: máximo 2 frases por mensaje de voz. Si necesita más,
dividir en turnos conversacionales.

### SIEMPRE en consola (el humano lo consulta cuando quiera)

| Tipo | Ejemplo |
|------|---------|
| Pinout ASCII | Diagrama completo del MCU |
| Tabla de conexiones | Lista de todos los cables |
| Código fuente | Script MicroPython generado |
| BOM completo | Lista de materiales con precios |
| Logs de depuración | Output serial, errores |
| Diagramas Mermaid | Flujo de señales |
| Métricas de sprint | Tablas numéricas largas |
| Diff de código | Cambios en ficheros |

### AMBOS (voz resumen + consola detalle)

| Tipo | Voz dice | Consola muestra |
|------|----------|-----------------|
| Resultado de búsqueda web | "Encontré 3 resultados sobre CORS" | Lista con URLs y snippets |
| Sprint status | "Sprint al 85%, 2 bloqueados" | Dashboard completo |
| Error de build | "El build falla en línea 47" | Stack trace completo |
| Test results | "14 tests pasan, 2 fallan" | Detalle de cada test |
| Verificación visual | "La conexión parece correcta" | Foto anotada |

## Algoritmo de decisión

```python
def classify_output(content, context):
    """Decide qué va a voz y qué a consola.

    Returns:
        {voice: str|None, console: str|None}
    """
    # 1. Safety → SIEMPRE voz (inmediato)
    if content.safety_level in ('critical', 'warning'):
        return {
            'voice': content.safety_message,
            'console': content.full_details
        }

    # 2. Structural content → SOLO consola
    if content.has_table or content.has_code or content.has_diagram:
        summary = summarize(content, max_words=20)
        return {
            'voice': summary if context.voice_active else None,
            'console': content.full
        }

    # 3. Short actionable → SOLO voz
    if content.word_count <= 30 and content.is_instruction:
        return {
            'voice': content.text,
            'console': None  # no duplicar
        }

    # 4. Medium content → voz resumen + consola detalle
    if content.word_count <= 100:
        return {
            'voice': summarize(content, max_words=25),
            'console': content.full
        }

    # 5. Long content → consola only, voz avisa
    return {
        'voice': "He generado un informe detallado, lo tienes en pantalla",
        'console': content.full
    }
```

## Reglas de voz

### Formato

- Frases cortas y directas (imperativo)
- Sin markdown, sin formato técnico
- Números deletreados si son pines: "G P I O veintitrés"
- Colores siempre mencionados: "el cable rojo"
- Pausas entre instrucciones (1s)

### Cadencia conversacional

```
Savia (voz): "Coge un cable rojo"
[pausa 1.5s]
Savia (voz): "Conéctalo del pin 3 V 3 al VCC del sensor"
[pausa para que el humano actúe]
Humano: "Listo" / [botón] / [silencio 5s]
Savia (voz): "Perfecto. Ahora coge un cable negro"
```

### Interrupciones

- Si el humano habla mientras Savia habla → Savia para
- Si el humano dice "repite" → repetir último mensaje
- Si el humano dice "más despacio" → reducir velocidad TTS
- Si el humano dice "para" → silencio, esperar nuevo comando

## Indicadores LED en ZeroClaw

| Color | Patrón | Significado |
|-------|--------|-------------|
| Azul fijo | — | Escuchando (wake word detectado) |
| Azul parpadeante | 2Hz | Procesando (audio enviado al host) |
| Verde fijo | — | Savia hablando (reproduciendo TTS) |
| Verde parpadeante | 1Hz | Esperando acción del humano |
| Rojo fijo | — | Error / advertencia de seguridad |
| Rojo parpadeante | 4Hz | Desconectado de Savia |
| Blanco pulso | fade | Standby (esperando wake word) |
| Apagado | — | ZeroClaw apagado |

## Modos de sesión

| Modo | Voz prioriza | Consola prioriza |
|------|-------------|------------------|
| `assembly` | Instrucciones paso a paso | Pinouts, BOM |
| `coding` | Resumen de errores | Código, diffs |
| `monitoring` | Alertas de anomalías | Datos, gráficas |
| `chat` | Conversación libre | Contexto, fuentes |
