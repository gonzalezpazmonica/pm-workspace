# Eval 01 — CRUD Spec básico para API de tareas

## Contexto

El equipo de TrazaBios necesita una API REST para gestión de tareas de campo.
Los técnicos de laboratorio crean, consultan y cierran tareas desde una app mobile.
La API se implementará en .NET 8 con Entity Framework y PostgreSQL.

## Tarea para el agente sdd-spec-writer

Crea una spec ejecutable para una API REST de gestión de tareas. El endpoint
`POST /tasks` debe crear una tarea con los campos: `title` (string, obligatorio,
máx 200 chars), `description` (string, opcional), `assignee_id` (UUID, obligatorio)
y `priority` (enum: LOW, MEDIUM, HIGH, default MEDIUM).

La spec debe incluir validación de campos obligatorios con mensajes de error claros,
manejo de errores HTTP (400 para validación, 404 para recursos no encontrados, 409
para duplicados), y al menos 5 criterios de aceptación verificables en formato
Given/When/Then. El dominio es gestión de tareas de laboratorio biológico.

Referencia de arquitectura: la capa API delega a Application, que usa un
repositorio de dominio. No incluir lógica de negocio en controladores.
