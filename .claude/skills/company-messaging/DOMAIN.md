# Company Messaging — Dominio

## Por que existe esta skill

Los equipos necesitan comunicacion asincrona sin depender de servicios externos.
Company Savia resuelve esto usando ramas git huerfanas como transporte, con cifrado
E2E opcional y zero dependencias externas mas alla de git y openssl.

## Conceptos de dominio

- **Rama huerfana**: rama git sin ancestro comun con main; aislamiento total de datos por usuario
- **Exchange branch**: rama pub/sub donde los mensajes transitan antes de ser entregados al inbox del destinatario
- **Cifrado hibrido RSA+AES**: clave AES aleatoria cifra el cuerpo; la clave AES se cifra con la pubkey RSA del destinatario
- **Threading**: mensajes encadenados via campos `thread` y `reply_to` en frontmatter YAML
- **@Handle**: identificador unico de usuario resuelto desde el directorio de la empresa

## Reglas de negocio que implementa

- Community Protocol (community-protocol.md): validacion de privacidad antes de push
- Data Sovereignty (data-sovereignty.md): mensajes son N2 (empresa), nunca en repo publico
- PII Sanitization (pii-sanitization.md): sin datos personales en commits de mensajeria

## Relacion con otras skills

- **Upstream**: company-setup (crea la estructura de empresa y directorio de handles)
- **Downstream**: scheduled-messaging (programa envio automatico de mensajes)
- **Paralelo**: notify-nctalk, notify-whatsapp (canales alternativos de notificacion)

## Decisiones clave

- Git como transporte en vez de API externa: zero dependencias, funciona offline, auditable
- Worktrees temporales para escritura: evita contaminar el checkout principal
- Cifrado opcional (no obligatorio): pragmatismo para mensajes no sensibles dentro de la org
