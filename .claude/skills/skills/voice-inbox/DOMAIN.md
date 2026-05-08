# voice-inbox — Dominio

## Por que existe esta skill

El PM a menudo esta lejos del teclado (en reuniones, desplazandose, en el taller) y necesita interactuar con pm-workspace por voz. Sin esta skill, los mensajes de audio de WhatsApp o Nextcloud Talk se pierden como contexto no estructurado. Voice inbox transcribe localmente, interpreta la intencion y propone el comando correspondiente, convirtiendo audio en accion.

## Conceptos de dominio

- **Transcripcion local**: conversion de audio a texto usando Faster-Whisper en la maquina del usuario, sin enviar audio a APIs externas (privacidad total)
- **Mapeo intencion-comando**: analisis del texto transcrito para identificar el comando de pm-workspace mas adecuado con nivel de confianza (alta/media/baja)
- **Confirmacion obligatoria**: el PM siempre ve la transcripcion y el comando propuesto antes de ejecutar, sin ejecucion automatica
- **Faster-Whisper**: motor de transcripcion local basado en Whisper, con modelos de tiny (1GB) a large-v3 (10GB) segun precision necesaria

## Reglas de negocio que implementa

- Principio foundacional #4: privacidad absoluta (audio procesado local, nunca en cloud)
- Principio foundacional #5: el humano decide (confirmacion antes de ejecutar)
- NL command resolution: misma logica de mapeo intencion-comando con scoring de confianza
- ZeroClaw sensory protocol: clasificacion de audio como dato biometrico N3 (RGPD Art. 9)

## Relacion con otras skills

- **Upstream**: `scheduled-messaging` (mensajes entrantes de WhatsApp/Nextcloud activan voice-inbox)
- **Downstream**: cualquier comando (voice-inbox es un punto de entrada alternativo al teclado)
- **Paralelo**: `smart-routing` (routing por texto complementa routing por voz)
- **Paralelo**: `meeting-digest` (transcripcion de reuniones vs transcripcion de mensajes cortos)

## Decisiones clave

- Faster-Whisper local en vez de API de transcripcion cloud: la voz es dato biometrico, privacidad no es negociable
- Modelo small como default: equilibrio calidad/velocidad para mensajes cortos del dia a dia
- Confianza baja no ejecuta ni sugiere un unico comando: lista opciones para que el PM elija
- ffmpeg como dependencia para conversion de formatos: ubicuo, sin licencia restrictiva, soporta todos los codecs relevantes
