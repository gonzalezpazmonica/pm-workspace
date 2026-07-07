# CRITERIO.md — Criterio publicado de la operadora

> Propiedad exclusiva de la operadora. Modificable solo con trailer Human-Authored.
> Cada entrada es citable como CRIT-XXX. Ninguna entrada se activa sin
> provenance:human_authored.

## Schema

Cada entrada: {id, ambito, principio, ejemplos, contraejemplos, dureza, provenance}

Ambitos validos: tecnicas, comunicacion, priorizacion, riesgo, delegacion
Dureza: linea_roja | preferencia | estilo
Provenance: human_authored (unico valor que activa la entrada)

## Entradas activas

<!-- CRIT: las entradas se poblaran via /criterio-init (S2 bootstrap) -->
<!-- Ninguna entrada de ejemplo: el criterio es de la operadora, no del agente. -->

CRIT-000: PLANTILLA — esta entrada es un ejemplo de estructura, no criterio activo.
  ambito: tecnicas
  principio: [una frase que capture la decision]
  ejemplos: [casos donde se aplica]
  contraejemplos: [casos donde NO se aplica]
  dureza: preferencia
  provenance: placeholder
