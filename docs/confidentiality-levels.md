# Niveles de Confidencialidad — Arquitectura de Separación de Datos

> Documento de referencia para la separación de datos en pm-workspace.
> Fecha: 2026-03-19

---

## Principio

pm-workspace es software libre publicado en GitHub. Los datos del usuario,
empresa y proyectos NUNCA deben mezclarse con el código público. Cada nivel
tiene su propio repositorio git con permisos independientes.

---

## 5 Niveles (de más abierto a más restringido)

### N1 — PUBLICO (repo pm-workspace en GitHub)

- Código del workspace: commands, skills, rules, agents, hooks, scripts
- Documentación genérica del producto: README, CHANGELOG, docs/
- Plantillas y ejemplos con datos ficticios (alice, test-org, acme-corp)
- Reglas de dominio sin datos de empresa ni persona
- NUNCA datos reales de personas, empresas, clientes ni proyectos

### N2 — EMPRESA (local, gitignored)

- `CLAUDE.local.md` — config de la organización (org URL, proyectos activos)
- `.claude/rules/pm-config.local.md` — constantes de la empresa
- `private-agent-memory/` — patrones del equipo y organización
- Configuración de conectores con datos reales de la org
- NUNCA datos personales de miembros ni datos de un cliente concreto

### N3 — USUARIO (repo separado: personal-vault)

- Perfil del usuario (identity, tone, workflow, tools, preferences)
- Memoria cross-project (instintos aprendidos, patrones personales)
- Cache de sesiones y contexto personal
- Preferencias de accesibilidad y formato
- Portable entre máquinas via `~/.savia/personal-vault/`
- NUNCA datos de proyectos de cliente ni datos de la empresa

### N4 — PROYECTO (repo separado por proyecto)

- Datos del cliente, reglas de negocio, stakeholders, arquitectura
- Reuniones, digests, roadmaps, estado, riesgos, decisiones
- Agent memory del proyecto: `projects/{proyecto}/agent-memory/`
- Puede subdividirse en:
  - **N4-SHARED**: compartible con el cliente (ej: proyecto-alpha)
  - **N4-VASS**: solo equipo proveedor (ej: proyecto-alpha-internal)
- NUNCA datos personales de miembros del equipo (van a N4b)

### N4b — EQUIPO-PROYECTO (repo separado, solo PM)

- Fichas individuales, one-to-ones, evaluaciones de competencias
- Feedback personal, transcripciones de reuniones 1:1
- Digests de conversaciones privadas
- Protegido por RGPD — solo la PM tiene acceso
- NUNCA datos del proyecto ni de la empresa

---

## Mecanismos de Separación

### Repositorios git independientes

- Cada nivel tiene su propio repo con permisos de acceso diferenciados
- N1: repo público en GitHub (pm-workspace)
- N2: ficheros gitignored dentro del repo N1
- N3: repo personal (`~/.savia/personal-vault/`)
- N4: repo por proyecto (uno por cliente/proyecto)
- N4b: repo separado por equipo-proyecto (solo PM)

### Junctions y symlinks

- El vault personal (N3) usa junctions para integrar datos dispersos
- Los perfiles de usuario se enlazan desde el vault al workspace
- Las preferencias cross-project viven en el vault, no en cada proyecto

### Reglas de enrutamiento para Savia

- `CONFIDENTIALITY.md` por proyecto define qué consultar según quien pregunta
- Savia clasifica cada dato ANTES de escribirlo (ver Protocolo de Decisión)
- Si hay duda, Savia pregunta al usuario antes de persistir

### Hooks pre-commit

- `security-guardian` verifica que no se filtren datos entre niveles
- `confidentiality-auditor` escanea patrones de datos personales
- Detección de credenciales, salarios, evaluaciones en repos compartidos

### Comando /confidentiality-check

- Auditoría bajo demanda de cumplimiento de niveles
- Escanea ficheros .md buscando datos fuera de nivel
- Genera informe con severidad: CRITICAL, WARNING, INFO

### .gitignore por nivel

- N2+: siempre gitignored en el repo N1
- Cada repo de proyecto tiene su propio .gitignore
- Ficheros sensibles excluidos por patron: `*.local.md`, `*.pat`, `*.secret`

---

## Ejemplo con Proyecto Genérico

- `projects/proyecto-alpha/` (N4-SHARED) — repo git compartible con el cliente
- `projects/proyecto-alpha-internal/` (N4-VASS) — repo git solo equipo proveedor
- `projects/proyecto-alpha-pm/` (N4b-PM) — repo git solo PM y superiores, datos RGPD
- `~/.savia/personal-vault/` (N3) — repo git personal cross-project

---

## Flujo de Decisión

Cuando Savia recibe información para persistir:

1. Clasificar: ¿es de un proyecto? ¿del usuario? ¿de la empresa? ¿genérica?
2. Si PROYECTO → determinar subnivel (N4-SHARED, N4-VASS o N4b)
3. Si USUARIO → escribir en el vault personal (N3)
4. Si EMPRESA → guardar en ficheros gitignored (N2)
5. Si GENÉRICA del workspace → repo público (N1)
6. Si DUDA → preguntar al usuario antes de escribir
7. NUNCA asumir destino sin clasificar primero

---

## Migración Futura

Cuando los repos se muevan de Gitea local a Gitlab/Azure DevOps:

- Los permisos de acceso se configuran por rol en el sistema destino
- N4-SHARED: acceso cliente + equipo proveedor
- N4-VASS: acceso solo equipo proveedor
- N4b: acceso solo PM (permisos individuales, no por grupo)
- N3: repo personal del usuario, no migra a plataforma compartida
- N2: se incluye en el onboarding de nuevos miembros del equipo

---

## Referencias

- `@docs/rules/domain/context-placement-confirmation.md` — regla operativa
- `@docs/rules/domain/pii-sanitization.md` — sanitización PII
- `@docs/rules/domain/confidentiality-config.md` — config de confidencialidad
- `@.opencode/agents/confidentiality-auditor.md` — agente auditor
- `/confidentiality-check` — comando de auditoría
