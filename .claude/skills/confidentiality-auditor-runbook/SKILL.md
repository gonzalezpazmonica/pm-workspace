---
name: confidentiality-auditor-runbook
description: "Protocolo de descubrimiento dinamico de contexto sensible, criterios de auditoria por nivel N1/N4, variantes y reglas de exclusion del agente confidentiality-auditor. Cargar para el detalle completo del proceso de auditoria."
summary: |
  Runbook auxiliar del agente confidentiality-auditor.
  Contiene: Fase 1b (discovery dinamico), criterios por nivel N1/N4-SHARED/N4-SUPPLIER/N4b-PM,
  variantes ortograficas, exclusiones y reglas inmutables.
maturity: stable
context: fork
context_cost: low
---

# Confidentiality Auditor — Runbook Completo

## Fase 1b — Descubrimiento dinamico de contexto sensible

Antes de auditar el diff, construir el diccionario de datos sensibles.
Las fuentes dependen del nivel detectado.

### Para N1 (publico) — maximo nivel de escrutinio

1. `projects/` — listar directorios; cada nombre es un proyecto REAL privado
2. `CLAUDE.local.md` — nombres de organizacion, proyectos, URLs reales
3. `.claude/profiles/users/*/identity.md` — nombres reales de personas
4. `.claude/rules/pm-config.local.md` — configuracion con datos reales
5. `projects/*/team/TEAM.md` — nombres de miembros del equipo
6. `.claude/profiles/active-user.md` — usuario activo

### Para N4-SHARED — fuentes de niveles superiores

1. CONFIDENTIALITY.md del proyecto — que datos NO pueden estar aqui
2. Repos hermanos N4-SUPPLIER y N4b-PM (si existen) — para saber que es sensible
3. Ficheros del propio repo — buscar datos que pertenezcan a niveles superiores

### Para N4-SUPPLIER — fuente del nivel superior

1. CONFIDENTIALITY.md — que datos NO pueden estar aqui
2. Repo N4b-PM (si existe) — para saber que es exclusivo de la PM

### Para N4b-PM — escrutinio minimo

1. Solo buscar credenciales tecnicas, tokens y claves de API

## Variantes a considerar

Para cada dato sensible, generar variantes:
- Proyecto: acme-portal → buscar tambien acme_portal, AcmePortal, acmeportal
- Nombre: Alice Smith → alice, smith, Alice, Smith
- Org: TestCorp → test-corp, testcorp, TEST-CORP

## Fase 2 — Criterios de auditoria por nivel

Revisar CADA linea anadida en el diff.

### CRITICAL por nivel (bloquean)

N1 (publico):
- Nombres de proyectos reales, personas reales, empresas reales
- Correos corporativos, URLs de infraestructura privada
- Credenciales, IPs de redes privadas, rutas de proyecto reales

N4-SHARED:
- Salarios, evaluaciones individuales, feedback personal
- Presupuestos, repartos economicos, deficit contractual
- Riesgos de personas individuales (fuga, sobrecarga por nombre)
- Codigos PEP, dedicaciones porcentuales individuales
- Problemas internos del equipo, dinamicas interpersonales
- Credenciales tecnicas

N4-SUPPLIER:
- Evaluaciones individuales, feedback personal
- Transcripciones de one-to-ones
- Situaciones familiares, relaciones personales
- Negociaciones salariales individuales
- Credenciales tecnicas

N4b-PM:
- Credenciales tecnicas (UNICO bloqueante)

### WARNING (no bloquean pero se reportan)

- Datos que podrian pertenecer a un nivel superior pero no es seguro
- Nombres propios no reconocidos en contexto ambiguo

### Exclusiones — NO reportar

- Datos ESPERADOS para el nivel del repo (ej: nombres reales en N4-SHARED)
- Nombres genericos: alice, bob, test-org, proyecto-alpha, acme-corp
- Dominios de ejemplo: @example.com, @test.com, @contoso.com
- Ficheros del propio scanner de auditoria

## Reglas inmutables

- NUNCA asumir que un nombre es seguro sin verificar contra el contexto
- NUNCA ignorar variantes ortograficas (guiones, underscores, mayusculas)
- NUNCA corregir automaticamente — solo informar y bloquear
- SIEMPRE leer el contexto sensible ANTES de auditar el diff
- SIEMPRE reportar el fichero y linea exacta de cada hallazgo
