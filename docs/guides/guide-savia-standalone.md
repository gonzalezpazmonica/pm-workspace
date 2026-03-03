# Guía: Solo Savia + Savia Flow (sin herramienta externa)

> Escenario: equipo pequeño (2–8 personas) que quiere gestionar su proyecto de software usando exclusivamente Savia y Git, sin Azure DevOps, Jira ni otra herramienta de PM externa.

---

## ¿Por qué elegir Savia standalone?

- **Cero dependencias externas**: todo vive en Git. Sin licencias, sin APIs, sin internet obligatorio.
- **Portabilidad total**: el repositorio ES tu herramienta de gestión. Clona y trabaja.
- **Cifrado E2E**: mensajería interna con RSA-4096 + AES-256-CBC.
- **Travel mode**: llévalo en un USB y trabaja offline.
- **Coste cero**: solo necesitas Git y Claude Code.

---

## Tu equipo

| Rol | Comandos principales |
|---|---|
| **Lead / PM** | `/savia-pbi`, `/savia-sprint`, `/savia-board`, `/savia-team` |
| **Developers** | `/flow-task-move`, `/flow-timesheet`, `/my-focus` |
| **Todos** | `/savia-send`, `/savia-inbox`, `/savia-directory` |

---

## Setup desde cero

### 1. Instalar pm-workspace

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

### 2. Crear el repositorio compartido de empresa

> "Savia, crea un repositorio de empresa para mi equipo"

Savia ejecuta `/company-repo` y te pide:

- Nombre de la empresa (genérico para el repo, e.g. "mi-equipo")
- Datos básicos (sector, tamaño)

Esto crea un repo Git con ramas orphan:

- `main` — configuración, reglas, pubkeys (solo admin)
- `user/{handle}` — espacio personal de cada miembro
- `team/{nombre}` — proyectos y datos de equipo
- `exchange` — bus de mensajería cifrada

### 3. Incorporar al equipo

Por cada persona:

> "Savia, incorpora a @carlos como developer"

Savia genera claves RSA-4096 para cifrado, crea la rama `user/carlos`, publica la clave pública en `main:pubkeys/carlos.pem`, y registra el perfil.

### 4. Crear tu primer proyecto

> "Savia, crea un proyecto llamado app-mobile en el equipo dev"

```
/savia-pbi create "Diseño de la pantalla de login" --project app-mobile
/savia-pbi create "API de autenticación" --project app-mobile
/savia-pbi create "Tests E2E del flujo de login" --project app-mobile
```

---

## El día a día

### El Lead / PM

**Lunes — Sprint planning:**

> "Savia, inicia un sprint de 2 semanas para app-mobile"

```
/savia-sprint start --project app-mobile --goal "MVP del login"
/savia-board app-mobile              → Board Kanban ASCII de 5 columnas
```

**Asignar tareas:**

```
/flow-task-create story "Pantalla de login"
/flow-task-assign TASK-001 @carlos
/flow-task-assign TASK-002 @elena
```

**Ver progreso diario:**

> "Savia, ¿cómo va el sprint?"

```
/savia-board app-mobile              → Board visual
/flow-burndown                       → Burndown chart
/flow-velocity                       → Velocidad del equipo
```

**Cierre de sprint:**

```
/savia-sprint close --project app-mobile
/flow-timesheet-report --monthly     → Informe de horas
```

### Los Developers

**Al empezar el día:**

> "Savia, ¿qué tengo pendiente?"

Savia muestra tus tasks asignadas ordenadas por prioridad.

**Mover tareas:**

```
/flow-task-move TASK-001 in-progress  → Empezar a trabajar
/flow-task-move TASK-001 review       → Pedir review
/flow-task-move TASK-001 done         → Completada
```

**Registrar horas:**

```
/flow-timesheet TASK-001 4           → 4 horas en esta task
```

### Comunicación interna

**Enviar mensaje directo:**

> "Savia, dile a @carlos que el endpoint de auth necesita validación de tokens"

```
/savia-send @carlos "El endpoint de auth necesita validación de tokens JWT"
```

**Revisar bandeja:**

```
/savia-inbox                         → Ver mensajes pendientes
/savia-reply {msg-id} "Entendido, lo miro esta tarde"
```

**Anuncio al equipo:**

```
/savia-announce "Sprint review mañana a las 10:00"
```

---

## Flujo SDD sin herramienta externa

Puedes usar el ciclo SDD completo aunque no tengas Azure DevOps:

1. `/savia-pbi create` — creas el PBI en Git
2. `/pbi-decompose` — Savia descompone en tasks
3. `/flow-spec-create` — genera una spec SDD
4. Implementa (tú o un agente Claude)
5. `/pr-review` — review automatizado
6. `/flow-task-move {id} done` — marca como hecho

---

## Trabajo offline y Travel Mode

### Preparar para viaje

> "Savia, prepárame un pack portable"

```
/savia-travel-pack                   → Crea paquete para USB
```

Genera: shallow clone + manifest + backup cifrado con AES-256-CBC.

### En la máquina nueva

```
/savia-travel-init                   → Bootstrap completo
```

Detecta OS, verifica dependencias, restaura perfil y configuración.

---

## Comparativa: ¿cuándo elegir standalone?

| Criterio | Standalone | + Azure DevOps | + Jira |
|---|---|---|---|
| Equipo pequeño (<8) | Ideal | Overkill | Overkill |
| Sin presupuesto para licencias | Perfecto | Requiere licencias | Requiere licencias |
| Trabajo offline frecuente | Nativo | Limitado | Limitado |
| Cliente requiere portal de gestión | No tiene portal web | Azure Boards | Jira Board |
| Métricas avanzadas | Savia Flow metrics | Completas | Vía sync |
| CI/CD | GitHub Actions | Azure Pipelines | GitHub/GitLab CI |

---

## Tips

- Haz `git push` frecuente para que todo el equipo vea los cambios
- Usa `/savia-board` en la daily como tablero visual compartido
- Los mensajes cifrados E2E garantizan privacidad incluso en repos compartidos
- `/index-rebuild` reconstruye índices si algo se desincroniza
- El repo de empresa se puede alojar en GitHub, GitLab, Bitbucket o incluso un servidor propio
