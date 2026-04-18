# Ejemplo de Implantación: SocialApp — Fase 1: Inicio

> Caso práctico completo: desde la decisión de crear una red social hasta el primer spec en producción.
> Equipo: la usuaria (CEO/CTO), Elena (Producto/QA), Ana (Front mid-junior), Isabel (Back senior).

---

## Semana 0 — La decisión

la usuaria decide construir SocialApp, una red social tipo Twitter. Stack: Ionic (Android/Web/iOS), microservicios Node.js, API Gateway, MongoDB, RabbitMQ. Elena será producto y QA. Ana hará front con Ionic. Isabel llevará back y arquitectura.

### Paso 1: la usuaria configura el entorno

```
la usuaria → /flow-setup --project SocialApp --plan
```

**Savia responde** con el plan de configuración de Azure DevOps: 8 columnas de board (3 exploración + 5 producción), 4 campos custom (Track, Outcome ID, Cycle Time Start/End), 2 area paths. la usuaria revisa y confirma:

```
la usuaria → /flow-setup --project SocialApp --execute
```

Savia crea todo en Azure DevOps. El tablero dual-track queda:

```
EXPLORACIÓN                          │ PRODUCCIÓN
Discovery → Spec-Writing → Spec-Ready│ Ready → Building → Gates → Deployed → Validating
```

### Paso 2: la usuaria define el equipo y sus roles

```
la usuaria → /profile-setup
```

Savia hace onboarding conversacional. la usuaria configura: ella misma como Flow Facilitator (métricas, desbloqueo), Elena como AI PM + Quality Architect (WIP 3, discovery + specs + gates), Ana como Pro Builder Front (WIP 2, Ionic), Isabel como Pro Builder Back + Arch (WIP 2, APIs + MongoDB + RabbitMQ).

### Paso 3: Elena define los outcomes

```
Elena → /pbi-jtbd
```

Savia guía el discovery con Jobs To Be Done. Elena define 4 outcomes (Epics): (1) User Onboarding — registro <3 min, 70% completion, mes 1. (2) Social Feed — timeline <500ms p95, mes 1-2. (3) Real-time Messaging — entrega <1s, mes 2-3. (4) Notifications — engagement +30%, mes 3.

```
Elena → /pbi-prd
```

Savia genera PRD por outcome. Elena revisa, ajusta y crea Epics en Azure DevOps.

### Paso 4: la usuaria valida la capacidad

```
la usuaria → /capacity-forecast --sprints 6
```

Savia calcula: 2 builders × 6h efectivas/día × 10 días/sprint = 120h/sprint. Con el stack definido (Ionic + microservicios + RabbitMQ), estima 4-6 specs por outcome. Timeline realista: 3 meses para MVP.

---

## Semana 1 — Primer ciclo de exploración

### Elena escribe las primeras specs

Elena empieza por el Outcome 1 (User Onboarding). Pide ayuda a Savia:

```
Elena → /flow-spec --outcome "User Onboarding"
```

Savia genera un stub de spec con las 5 secciones:
1. **Outcome**: referencia al Epic + métricas de éxito
2. **Functional Spec**: escenarios Given/When/Then
3. **Technical Constraints**: stack, performance, seguridad
4. **Dependencies**: qué servicios necesita
5. **Definition of Done**: checklist verificable

Elena completa la spec "User Registration" con los detalles de negocio. Savia la crea como User Story en Azure DevOps en la columna **Spec-Writing** con Area Path = Exploration.

```
Elena → /flow-spec --outcome "User Onboarding"
```

Repite para "Profile Setup Wizard". Ahora tiene 2 specs en Spec-Writing.

### Isabel consulta las restricciones técnicas

Isabel revisa las specs en progreso para validar viabilidad:

```
Isabel → /flow-board --track exploration
```

Savia muestra el track de exploración. Isabel ve que "User Registration" necesita auth-service con bcrypt + OAuth2. Comenta en la User Story: "Necesitamos JWT + refresh tokens. Propongo auth-service como primer microservicio."

### Elena marca specs como Spec-Ready

Cuando Elena termina una spec completa (outcome claro, métricas, Given/When/Then, constraints técnicas validadas por Isabel, DoD testable), la mueve a **Spec-Ready**:

```
Elena cambia el estado → Spec-Ready (en Azure DevOps)
```

---

## Semana 1 — Primer intake a producción

### la usuaria hace el intake semanal

En el sync del lunes (30 min), la usuaria ejecuta:

```
la usuaria → /flow-intake
```

Savia muestra los items Spec-Ready:
```
📋 Items Spec-Ready: 2
  #1001 User Registration — Outcome: User Onboarding
  #1002 Profile Setup Wizard — Outcome: User Onboarding

👥 Capacidad builders:
  Ana (Front): 0/2 WIP ✅
  Isabel (Back): 0/2 WIP ✅

📌 Asignación propuesta:
  #1001 → Isabel (back: auth-service) + Ana (front: registration page)
  #1002 → Ana (front: profile wizard) — esperar a que #1001 esté en Gates
```

la usuaria confirma. Savia mueve los items: Area Path Exploration → Production, estado → Ready.

### Isabel descompone la spec en tasks

Isabel recibe la spec #1001 y pide a Savia que la descomponga:

```
Isabel → /pbi-decompose --id 1001
```

Savia genera tasks con estimación:

Savia genera 10 tasks: setup auth-service (4h, Isabel), modelo User + bcrypt (3h, Isabel), endpoints register/login (4h, Isabel), OAuth2 Google (6h, Isabel), Ionic registration page (4h, Ana), integración API (3h, Ana), OAuth2 Capacitor (4h, Ana), event RabbitMQ (2h, Isabel), tests unitarios (3h, Isabel), E2E (3h, Ana). Total: 36h (~3.5 días con 2 personas en paralelo). Isabel confirma y Savia crea los tasks en Azure DevOps.

> **Continúa en** [13-ejemplo-implantacion-dia-a-dia.md](13-ejemplo-implantacion-dia-a-dia.md)
