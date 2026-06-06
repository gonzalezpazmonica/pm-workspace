# Eval 01 — Descomposición de PBI de gestión de notificaciones

## Contexto

El proyecto TrazaBios necesita implementar un sistema de notificaciones para
alertar a los técnicos de laboratorio cuando una muestra supera los umbrales
de control de calidad. El sistema debe soportar múltiples canales de envío.

## PBI de entrada (sin descomponer)

**PBI-247: Sistema de notificaciones para alertas de control de calidad**

Como técnico de laboratorio, quiero recibir notificaciones automáticas cuando
una muestra supera los umbrales establecidos de control de calidad, para poder
actuar a tiempo y evitar contaminación cruzada en el proceso de producción.

El sistema debe soportar notificaciones por correo electrónico y mensajes internos
en la plataforma. Las notificaciones deben incluir el identificador de la muestra,
el umbral superado, el valor real medido y la hora del evento. Los técnicos pueden
configurar sus preferencias de canal por tipo de alerta.

## Tarea para el agente business-analyst

Descompón el PBI-247 en tasks técnicas estimables. Para cada task:
- Título descriptivo (qué hace, no qué es)
- Estimación en horas (realista, no optimista)
- Capa técnica afectada (Domain, Application, Infrastructure, API, Frontend)
- Dependencias con otras tasks
- Criterios de aceptación específicos y verificables

La descomposición debe cubrir: dominio, persistencia, envío por correo,
mensajes internos, API de preferencias del usuario, y el mecanismo de
disparo de alertas cuando se superan umbrales.
