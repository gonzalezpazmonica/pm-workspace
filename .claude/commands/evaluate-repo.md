---
name: evaluate-repo
description: >
  Evaluación estática de seguridad y calidad de un repositorio externo antes de
  incorporar herramientas, librerías, MCP servers o skills al workspace. Asigna
  puntuación 1-10 en 6 categorías y genera un veredicto: Recomendar, Con reservas,
  Requiere revisión manual o Rechazar.
---

# Evaluación de Repositorio Externo

**Repositorio a evaluar:** $ARGUMENTS

> Si no se pasa argumento, evalúa el repositorio en el que estés trabajando actualmente.

---

## Contexto de evaluación (ecosistema Claude Code + .NET)

Estás evaluando un repositorio destinado a incorporarse al ecosistema pm-workspace,
donde ciertas funciones (hooks, commands, scripts, MCP servers) pueden ejecutarse
implícitamente una vez habilitadas por el usuario.

El riesgo en este ecosistema no proviene de código malicioso obvio, sino de
**superficies de ejecución implícita**: hooks que se disparan automáticamente,
scripts que se ejecutan en el entorno local del usuario, o ficheros de estado
persistente que controlan el flujo de ejecución.

Tu tarea: revisión conservadora, basada en evidencia, solo lectura estática.

---

## Instrucciones

1. **NO ejecutes código** — no instales dependencias, no lances scripts
2. **Clona el repo** a `/tmp/` para inspección:
   ```bash
   git clone $ARGUMENTS /tmp/eval-repo-$(date +%s) --depth 1
   ```
3. Lee todos los ficheros relevantes: README, CLAUDE.md, package.json, *.csproj,
   hooks, commands, scripts, configs
4. Basa tu evaluación solo en el contenido observable

---

## Criterios de evaluación (1-10 cada uno)

### 1. Calidad de código
Estructura, legibilidad, corrección, consistencia interna.

### 2. Seguridad y safety
- Ejecución implícita (hooks, background, startup scripts)
- Acceso a filesystem (qué lee, qué escribe, dónde)
- Acceso a red (HTTP requests, telemetría, analytics)
- Manejo de credenciales (¿pide tokens? ¿los almacena?)
- Escalación de privilegios o asunciones de confianza

### 3. Documentación y transparencia
¿La documentación describe fielmente el comportamiento? ¿Revela side effects?
¿Coincide la implementación con lo documentado?

### 4. Funcionalidad y scope
¿Hace lo que dice dentro de su scope declarado?

### 5. Higiene del repositorio y mantenimiento
Señales de cuidado, mantenibilidad, licencia, calidad de publicación.

### 6. Compatibilidad con pm-workspace
- ¿Es compatible con arquitectura Hexagonal/DDD?
- ¿Respeta las convenciones .NET del workspace (`dotnet-conventions.md`)?
- ¿No contradice las reglas de `github-flow.md`?
- ¿No genera conflicto con los agentes o skills existentes?
- ¿Se puede integrar sin modificar reglas críticas?

---

## Checklist específico Claude Code

Responde explícitamente a cada punto:

- [ ] Define hooks (stop, lifecycle, pre/post-commit)
- [ ] Los hooks ejecutan shell scripts
- [ ] Los commands invocan shell o herramientas externas
- [ ] Escribe ficheros de estado persistente en el sistema local
- [ ] Lee estado para controlar flujo de ejecución
- [ ] Ejecuta acciones implícitas sin confirmación del usuario
- [ ] Documenta los side effects de hooks/commands
- [ ] Tiene defaults seguros (opt-in, no opt-out)
- [ ] Tiene mecanismo claro de desactivar/desinstalar

Explica brevemente cada punto marcado.

---

## Análisis de permisos y side effects

### A. Permisos declarados (desde documentación/config)
- Filesystem:
- Red:
- Ejecución/hooks:
- APIs/herramientas:

### B. Permisos inferidos (desde inspección estática)
- Filesystem:
- Red:
- Ejecución/hooks:
- APIs/herramientas:

Marcar cada item como: **confirmado**, **probable** o **incierto**.

### C. Discrepancias
Listar las diferencias entre lo declarado y lo inferido.

---

## Scan de red flags

Verificar y justificar cada uno:
- [ ] Indicadores de malware o spyware
- [ ] Ejecución implícita no documentada
- [ ] Actividad de red o filesystem no documentada
- [ ] Claims no respaldados por la implementación
- [ ] Riesgos de supply-chain o confianza transitiva
- [ ] Auto-updates que puedan modificar el comportamiento post-instalación

---

## Formato del informe

```
╔══════════════════════════════════════════════════════════════╗
║           EVALUACIÓN DE REPOSITORIO EXTERNO                  ║
║           Repo: [nombre]                                     ║
║           Fecha: [YYYY-MM-DD]                                ║
╚══════════════════════════════════════════════════════════════╝

  1. Calidad de código .............. X/10
  2. Seguridad y safety ............ X/10
  3. Documentación y transparencia . X/10
  4. Funcionalidad y scope ......... X/10
  5. Higiene y mantenimiento ....... X/10
  6. Compatibilidad pm-workspace ... X/10

  PUNTUACIÓN GLOBAL: X.X / 10

══════════════════════════════════════════════════════════════

  VEREDICTO:
  ✅ RECOMENDAR — seguro para incorporar
  🟡 CON RESERVAS — incorporar con las modificaciones listadas
  🔍 REQUIERE REVISIÓN MANUAL — hallazgos que necesitan inspección humana
  🔴 RECHAZAR — riesgos inaceptables

══════════════════════════════════════════════════════════════

  HEURÍSTICA DE RECHAZO RÁPIDO:
  (Solo si RECHAZAR — indicar cuál aplica)
  - Comportamiento malicioso claro
  - Ejecución implícita de alto riesgo no documentada
  - Discrepancia severa entre claims y comportamiento
  - Defaults inseguros sin mitigación
  - Otro: [explicar]

══════════════════════════════════════════════════════════════

  MEJORAS SUGERIDAS:
  [Lista de cambios mínimos que cambiarían el veredicto]
```

---

## Restricciones

- **NUNCA** instalar dependencias ni ejecutar código del repo evaluado
- **NUNCA** aprobar automáticamente — el veredicto es una recomendación al humano
- Si hay duda entre 🟡 y 🔴, elevar siempre a 🔴
- Limpiar el clon temporal tras la evaluación:
  ```bash
  rm -rf /tmp/eval-repo-*
  ```
