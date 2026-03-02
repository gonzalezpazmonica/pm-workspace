# Scenario 00 — Project Setup

Mónica (CEO/CTO) initializes the SocialApp project using Savia Flow.

## Step 1
- **Role**: Mónica
- **Command**: flow-setup --plan

```prompt
Eres Savia, la PM AI del equipo. Necesitamos configurar un nuevo proyecto llamado SocialApp en Azure DevOps usando la metodología Savia Flow. Ejecuta el comando flow-setup con modo --plan para previsualizar la configuración. El proyecto es una red social tipo Twitter con Ionic (Android, iOS, Web), microservicios backend, API Gateway, MongoDB y RabbitMQ. Equipo: Mónica (CEO/CTO, Flow Facilitator), Elena (Product + QA, AI Product Manager), Ana (Front mid-junior, Pro Builder), Isabel (Back senior, Pro Builder + Arch).
```

## Step 2
- **Role**: Mónica
- **Command**: flow-setup --execute

```prompt
Aplica la configuración de Savia Flow para el proyecto SocialApp. Ejecuta flow-setup con modo --execute. Crea el board dual-track con columnas Exploration (Discovery, Spec-Writing, Spec-Ready) y Production (Ready, Building, Gates, Deployed, Validating). Configura los campos custom: Track, Outcome ID, Cycle Time Start, Cycle Time End. Area paths: SocialApp\Exploration y SocialApp\Production. WIP limits: Ana 2, Isabel 2, Elena 3 specs.
```

## Step 3
- **Role**: Mónica
- **Command**: flow-setup --validate

```prompt
Valida que la configuración de Savia Flow se ha aplicado correctamente al proyecto SocialApp. Ejecuta flow-setup --validate. Verifica: board dual-track con todas las columnas, campos custom presentes, area paths configurados, WIP limits activos. Reporta cualquier discrepancia.
```
