# Regla: Niveles de Confidencialidad y Destino de Informacion

> **REGLA OBLIGATORIA** — Aplica siempre que Savia persista informacion.
> Fecha: 2026-03-19

---

## Principio

pm-workspace es software libre publicado en GitHub. Toda informacion persistida
DEBE clasificarse por nivel de confidencialidad ANTES de escribirse. Cada nivel
tiene un destino fisico y unas garantias de visibilidad diferentes.

---

## 5 Niveles de Confidencialidad

### N1 — PUBLICO (repo GitHub, git tracked)

**Visible para:** cualquier persona en internet.

**Que va aqui:**
- Codigo del workspace (commands, skills, rules, agents, hooks, scripts)
- Documentacion generica del producto (README, CHANGELOG, docs/)
- Plantillas y ejemplos con datos ficticios (alice, test-org, acme-corp)
- Reglas de dominio sin datos de empresa ni persona

**NUNCA:**
- Nombres reales de personas, empresas o clientes
- Handles de GitHub, emails corporativos, URLs de organizacion
- Nombres de proyectos reales (usar genericos: proyecto-alpha)
- Datos que identifiquen a la empresa que usa pm-workspace

**Ficheros:** todo lo que NO este en .gitignore

---

### N2 — EMPRESA (local, gitignored, compartible dentro de la org)

**Visible para:** personas de la empresa con acceso al workspace.

**Que va aqui:**
- `CLAUDE.local.md` — config de la organizacion (org URL, proyectos activos)
- `.claude/rules/pm-config.local.md` — constantes de la empresa
- `private-agent-memory/` — patrones del equipo y organizacion
- Datos de la empresa que NO son de un proyecto concreto
- Configuracion de conectores con datos reales de la org

**NUNCA:**
- Datos personales de un miembro del equipo (evaluaciones, feedback)
- Datos de un cliente concreto (van a N4)
- Preferencias individuales del usuario (van a N3)

**Ficheros:** `CLAUDE.local.md`, `pm-config.local.md`, `private-agent-memory/`

---

### N3 — USUARIO (local, solo la persona usuaria)

**Visible para:** SOLO la persona que usa este workspace.

**Que va aqui:**
- `~/.claude/CLAUDE.md` — preferencias personales globales
- `~/.claude/rules/*.md` — reglas personales del usuario
- `.claude/profiles/users/{slug}/` — perfil (identity, tone, workflow, tools)
- `.claude/profiles/active-user.md` — quien esta activo
- `settings.local.json` — permisos y paths locales del usuario

**NUNCA:**
- Datos de proyectos de cliente (van a N4)
- Datos de la empresa (van a N2)
- Codigo o reglas genericas del workspace (van a N1)

**Ficheros:** `~/.claude/`, `.claude/profiles/users/`, `settings.local.json`

---

### N4 — PROYECTO (local, aislado por proyecto, datos del cliente)

**Visible para:** la PM y personas autorizadas del proyecto.

**Que va aqui:**
- `projects/{proyecto}/` — TODO lo del proyecto va AQUI
- Reglas de negocio, stakeholders, relaciones cliente-proveedor
- Contexto de comunicacion (ej: "alinear con Virginia antes de hablar con Repsol")
- Reuniones, digests, roadmaps del proyecto
- Agent memory del proyecto: `projects/{proyecto}/agent-memory/`
- Estado, riesgos, gaps, decisiones del proyecto

**NUNCA:**
- Datos personales de miembros del equipo (van a N4b)
- Datos de OTRO proyecto (aislamiento estricto entre proyectos)
- Preferencias del usuario (van a N3)

**Ficheros:** `projects/{proyecto}/` (estructura segun su README.md)

---

### N4b — EQUIPO-PROYECTO (local, SOLO PM, datos personales del equipo)

**Visible para:** SOLO la PM. Ni el propio equipo ve los datos de otros.

**Que va aqui:**
- `projects/team-{proyecto}/` — fichas individuales, one-to-ones
- Evaluaciones de competencias, feedback personal
- Transcripciones de reuniones 1:1
- Digests de conversaciones privadas

**NUNCA:**
- Datos del proyecto (van a N4)
- Datos de la empresa (van a N2)

**Ficheros:** `projects/team-{proyecto}/` (separado del proyecto por privacidad)

---

## Auto-Memory Global (`~/.claude/projects/*/memory/`)

La auto-memory global es un mecanismo de Claude Code que se carga en TODAS
las sesiones. Por tanto SOLO debe contener:

- Feedback sobre como trabaja Savia (correcciones de comportamiento) → tipo `feedback`
- Estado de features del propio workspace (Eras, specs en progreso) → tipo `project` (del workspace)
- Referencias a recursos externos genericos → tipo `reference`

**NUNCA en auto-memory:**
- Datos de proyectos de cliente (→ N4)
- Datos personales del usuario (→ N3)
- Datos de la empresa (→ N2)
- Preferencias personales (→ N3, en `~/.claude/`)

---

## Protocolo de Decision

Cuando Savia recibe informacion para persistir:

1. Clasificar: ¿es de un proyecto? ¿del usuario? ¿de la empresa? ¿generica?
2. Si PROYECTO → leer README.md del proyecto, elegir fichero correcto
3. Si USUARIO → guardar en `~/.claude/` o perfil del usuario
4. Si EMPRESA → guardar en `CLAUDE.local.md` o `private-agent-memory/`
5. Si GENERICA del workspace → auto-memory global
6. Si DUDA → **preguntar al usuario**: "Esto parece de {proyecto}. ¿Lo guardo en {fichero}?"
7. **NUNCA asumir** destino sin clasificar primero

---

## Justificacion

| Problema | Consecuencia | Nivel correcto |
|---|---|---|
| Dato de cliente en auto-memory | Se carga en sesiones de otros proyectos, contamina contexto | N4 |
| Preferencia personal en repo publico | Visible en GitHub para cualquiera | N3 |
| Nombre de empresa en commit | Viola Rule #20 PII-Free | N2 |
| Evaluacion de persona en carpeta de proyecto | Equipo puede ver feedback privado | N4b |
| Feature del workspace en carpeta de proyecto | No se encuentra en sesiones genericas | Auto-memory |
