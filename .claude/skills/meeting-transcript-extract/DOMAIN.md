# Domain — Meeting Transcript Extract

## Por qué existe esta skill

Las reuniones de Teams generan transcripciones que contienen decisiones, action items, y contexto de negocio crítico. Extraerlas manualmente es lento y propenso a omisiones. Esta skill automatiza la extracción vía CDP del browser-daemon, capturando la transcripción completa en tiempo real.

## Conceptos de dominio

- **Browser daemon**: servicio local que controla una instancia de navegador para interactuar con Teams Web
- **Transcript chunk**: fragmento de transcripción capturado en un intervalo de polling
- **Speaker diarization**: identificación del hablante en cada segmento de la transcripción
- **Live session**: reunión en curso que se está transcribiendo activamente

## Reglas de negocio

- Solo se extraen transcripciones de reuniones a las que el usuario está invitado
- La extracción se detiene automáticamente cuando la reunión termina
- Las transcripciones se guardan en `meetings/transcripts/` con marca de tiempo
