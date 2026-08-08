# transcriptor-digest — Dominio

## Por que existe esta skill

Savia Sonora (ex-Savia Transcriptor) captura reuniones y conversaciones de voz
(audio + transcripcion + capturas de pantalla) en `~/.savia/transcriptor/`.
Sin esta skill, ese contenido queda como ficheros inertes: el contexto de las
reuniones no alimenta el conocimiento del workspace. Esta skill detecta las
carpetas nuevas sin digerir y las convierte en notas estructuradas.

## Conceptos de dominio

- **Reunion**: sesion capturada (audio.wav + transcript.vtt + capturas + meta.json).
- **Digest**: transformacion de la transcripcion en notas accionables (meeting-digest).
- **meta.json**: estado `digested` (el flag que la skill respeta para no re-procesar).
- **Savia Sonora**: proyecto unificado de la interfaz hablada de Savia.
