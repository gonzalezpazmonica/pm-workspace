---
status: PROPOSED
---

# SPEC-SE-007 — Enterprise Onboarding & Scale

> **Prioridad:** P2 · **Estima:** 5 días · **Tipo:** onboarding a escala

## Objetivo

Permitir que una organización de 50-500 personas pueda incorporar Savia
Enterprise en menos de una semana, con SSO/SAML agnóstico, onboarding batch
de equipos, y un dashboard de adopción que mida uso real sin telemetría
externa.

## Principios afectados

- #4 Privacidad absoluta (métricas de adopción NUNCA salen del cliente)
- #6 Igualdad (onboarding no sesgado por rol/género)

## Diseño

### Onboarding batch

Reutilizar `/onboard-enterprise` existente. Input: CSV con `nombre,email,rol,equipo`.
Output:
- Perfil Savia generado por persona
- Permisos RBAC asignados por rol
- Buddy IA asignado (`buddy-ia` agent)
- Plan de formación por competencias detectadas

### SSO/SAML adapters (agnósticos)

Adaptadores para los 5 proveedores IdP más comunes:

| IdP | Protocolo | Notas |
|-----|-----------|-------|
| Microsoft Entra ID | SAML 2.0, OIDC | Mercado corporativo España |
| Okta | SAML 2.0, OIDC | Internacional |
| Keycloak | SAML 2.0, OIDC | Sovereign (recomendado) |
| Google Workspace | OIDC | SMB |
| Auth0 | OIDC | Startups |

El adaptador es **solo lectura**: Savia nunca escribe en el IdP. Solo
valida tokens y extrae `email`, `groups`, `roles`.

### Enterprise dashboard

Reutilizar `/enterprise-dashboard`. Métricas:
- Adopción por equipo (% personas con perfil activo)
- Comandos más usados por rol
- Tiempo medio ahorrado (vs baseline preOnboarding)
- Competencias cubiertas/descubiertas
- Incidentes de compliance por equipo

**Todas las métricas son locales**. No hay telemetría externa. Export
opcional a CSV/PDF para reporting interno.

### Buddy IA

Cada persona nueva recibe un `buddy-ia` agent asignado. El buddy:
- Genera 12 docs de onboarding auto-adaptados al rol
- Acompaña las primeras 2 semanas
- Detecta bloqueos y los escala al mentor humano asignado
- Genera plan de desarrollo de competencias

## Criterios de aceptación

1. `/onboarding-dev batch equipo.csv` crea 20 perfiles con buddies
2. Adaptador SAML para Keycloak funcional (caso soberano prioritario)
3. Adaptador OIDC para Entra ID funcional (caso corporativo prioritario)
4. Dashboard muestra adopción sin ninguna llamada externa
5. Export PDF con métricas de sprint reporting
6. Test: 50 usuarios simulados, onboarding < 10 min, cero intervención manual

## Out of scope

- Sincronización bidireccional con IdP (fuera de scope, nunca)
- Provisioning automático de usuarios en IdP

## Dependencias

- SE-001, SE-002
