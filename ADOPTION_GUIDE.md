🌐 [English version](ADOPTION_GUIDE.en.md) · **Español**

# Guía de Adopción de PM-Workspace para Consultoras

> De cero a productividad con IA en la gestión de proyectos .NET — paso a paso.

---

## Índice

1. [Introducción: ¿Qué es PM-Workspace y por qué adoptarlo?](#1-introducción)
2. [Requisitos previos y planificación del despliegue](#2-requisitos-previos)
3. [Registro y suscripción a Claude](#3-registro-y-suscripción-a-claude)
4. [Instalación de Claude Code en la terminal](#4-instalación-de-claude-code)
5. [Descarga y configuración de PM-Workspace](#5-descarga-y-configuración-de-pm-workspace)
6. [Conectar con Azure DevOps](#6-conectar-con-azure-devops)
7. [Primeros comandos: tu primera mañana con PM-Workspace](#7-primeros-comandos-tu-primera-mañana)
8. [Incorporar un proyecto existente](#8-incorporar-un-proyecto-existente)
9. [Crear un proyecto nuevo desde cero](#9-crear-un-proyecto-nuevo-desde-cero)
10. [Onboarding del equipo de programadores](#10-onboarding-del-equipo-de-programadores)
11. [Roadmap de adopción gradual (10 semanas)](#11-roadmap-de-adopción-gradual)
12. [Resolución de problemas frecuentes](#12-resolución-de-problemas-frecuentes)
13. [Glosario](#13-glosario)

---

## 1. Introducción

### ¿Qué es PM-Workspace?

PM-Workspace es un sistema de gestión de proyectos .NET con Scrum que convierte a Claude Code (la herramienta de programación con IA de Anthropic) en un **Project Manager / Scrum Master automatizado**. Se conecta a Azure DevOps y proporciona 27 comandos, 9 skills especializadas y 11 subagentes de IA que cubren desde el sprint planning hasta la implementación de código por agentes.

### ¿Por qué adoptarlo en una consultora?

- **Reduce el tiempo de gestión de sprints** de horas a minutos: burndown, capacity, informes automáticos.
- **Genera informes Excel y PowerPoint** listos para entregar al cliente sin edición manual.
- **Descompone PBIs en tasks** con estimación, asignación y scoring de carga, eliminando reuniones de refinamiento de tareas.
- **Implementa automáticamente tasks repetitivas** (Command Handlers, Repositories, Unit Tests) con agentes IA.
- **Incorpora onboarding automatizado** de nuevos programadores con evaluación de competencias y conformidad RGPD.

### ¿Qué NO es?

PM-Workspace no reemplaza al PM ni al equipo humano. Las decisiones de arquitectura, el Code Review, la negociación con el cliente y la gestión de personas siguen siendo responsabilidad humana. La IA asiste, automatiza tareas repetitivas e informa, pero nunca decide por ti.

> **💡 Para la dirección:** El ROI estimado es 60-70% de reducción en tiempo de gestión administrativa del sprint + 40-60% de tasks técnicas repetitivas automatizadas por agentes IA, con un coste mensual de 20-200€/usuario según el plan elegido.

---

## 2. Requisitos Previos

### Hardware y software

Cada miembro del equipo que vaya a usar PM-Workspace necesita:

| Requisito | Detalle | Cómo verificar |
|-----------|---------|----------------|
| Sistema operativo | macOS, Linux o Windows (con WSL2) | Terminal disponible |
| Node.js | ≥ 18 (para scripts de reporting) | `node --version` |
| Python | ≥ 3.10 (para capacity calculator) | `python3 --version` |
| Azure CLI | Con extensión `az devops` | `az --version` |
| jq | Procesador JSON en terminal | `jq --version` |
| Git | ≥ 2.30 | `git --version` |
| Claude Code | CLI de Anthropic (se instala en paso 4) | `claude --version` |

### Accesos necesarios

- Cuenta de Azure DevOps con acceso a la organización de la consultora.
- PAT (Personal Access Token) de Azure DevOps con scopes: Work Items (Read & Write), Project and Team (Read), Analytics (Read), Code (Read).
- Cuenta de Anthropic (Claude) con suscripción activa (se crea en el paso 3).

### Decisión previa: ¿Quién usa PM-Workspace?

No todo el equipo necesita PM-Workspace. La recomendación para una consultora:

| Rol | ¿Necesita PM-Workspace? | Plan recomendado |
|-----|------------------------|------------------|
| Project Manager / Scrum Master | **Sí** — es el usuario principal | Pro ($20/mes) o Max ($100/mes) |
| Tech Lead | **Sí** — para SDD, specs y code review | Pro ($20/mes) |
| Desarrolladores senior | Opcional — para lanzar agentes sobre specs | Pro ($20/mes) |
| Desarrolladores junior | No — trabajan con Azure DevOps directamente | No necesario |
| QA | No — recibe tasks asignadas en AzDO | No necesario |
| Dirección / PMO | No — recibe informes generados por el PM | No necesario |

---

## 3. Registro y Suscripción a Claude

### 3.1 Crear cuenta en Anthropic

1. Ir a [claude.ai](https://claude.ai) y pulsar «Sign Up».
2. Registrarse con email corporativo (recomendado para trazabilidad).
3. Verificar el email y completar el perfil.

### 3.2 Elegir plan

Para una consultora que empieza con PM-Workspace, el plan recomendado es **Pro ($20/mes por usuario)**. Este plan incluye acceso completo a Claude Code en terminal y límites suficientes para gestión de sprints y generación de informes.

| Plan | Precio | Claude Code | Recomendado para |
|------|--------|-------------|------------------|
| Free | Gratis | Limitado | Prueba inicial (1-2 días) |
| **Pro** | **$20/mes** | **Sí, completo** | **PM y Tech Lead (uso diario)** |
| Max 5x | $100/mes | Sí, 5x Pro | PM con múltiples proyectos + SDD intensivo |
| Max 20x | $200/mes | Sí, 20x Pro | Uso masivo de agentes SDD |
| Team | $25-150/mes por plaza | Sí (Premium) | Equipos con facturación centralizada |
| Enterprise | Personalizado | Sí | Consultoras grandes (>50 usuarios) |

> **💡 Consejo:** Empieza con 1-2 licencias Pro para el PM y el Tech Lead. Si en 2-3 sprints el ROI es positivo, escala al resto del equipo o negocia un plan Team/Enterprise.

### 3.3 Activar la suscripción

1. En claude.ai, ir a Settings > Subscription.
2. Seleccionar el plan deseado e introducir datos de pago.
3. Confirmar la suscripción. El acceso a Claude Code se activa inmediatamente.

---

## 4. Instalación de Claude Code

Claude Code es una herramienta de terminal (CLI) que se instala en el ordenador de cada usuario. Es la interfaz a través de la cual se interacciona con PM-Workspace.

### 4.1 Instalación

**macOS / Linux:**

```bash
curl -fsSL https://claude.ai/install.sh | sh
```

**Windows (PowerShell como Administrador):**

```powershell
irm https://claude.ai/install.ps1 | iex
```

**Alternativa con npm (si ya tienes Node.js):**

```bash
npm install -g @anthropic-ai/claude-code
```

### 4.2 Verificar la instalación

```bash
claude --version
```

Debe mostrar la versión instalada (ej: `claude-code 1.x.x`).

### 4.3 Autenticarse

```bash
claude
```

La primera vez que ejecutas `claude`, se abrirá el navegador para autenticarte con tu cuenta de Anthropic. Sigue las instrucciones en pantalla.

### 4.4 Diagnóstico

Si algo falla durante la instalación:

```bash
claude doctor
```

Este comando comprueba configuración, dependencias y autenticación.

---

## 5. Descarga y Configuración de PM-Workspace

### 5.1 Clonar el repositorio

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
cd ~/claude
```

> **⚠️ Importante:** El directorio `~/claude/` es a la vez tu directorio de trabajo y el repositorio GitHub. Siempre se trabaja desde esta raíz.

### 5.2 Instalar dependencias de scripts

```bash
cd scripts/ && npm install && cd ..
```

### 5.3 Verificar la instalación con el proyecto de test

PM-Workspace incluye un proyecto de prueba (`sala-reservas`) con datos mock que permite verificar que todo está correctamente configurado sin necesidad de conectar con Azure DevOps real:

```bash
chmod +x scripts/test-workspace.sh
./scripts/test-workspace.sh --mock
```

Resultado esperado: **≥ 93/96 tests pasan**. Los 3 fallos son esperados (Azure CLI no conectado y node_modules si no se instaló).

### 5.4 Estructura del workspace

Al clonar, encontrarás esta estructura:

| Directorio | Contenido | Editable |
|------------|-----------|----------|
| `CLAUDE.md` | Punto de entrada de Claude Code (constantes globales) | Sí |
| `.claude/commands/` | 27 slash commands para flujos PM | Avanzado |
| `.claude/skills/` | 9 skills especializadas | Avanzado |
| `.claude/agents/` | 11 subagentes IA | Avanzado |
| `.claude/rules/` | Reglas modulares (Scrum, .NET, Git) | Avanzado |
| `projects/` | Carpeta de proyectos (cada uno con su `CLAUDE.md`) | Sí |
| `scripts/` | Scripts auxiliares (Azure DevOps, informes) | No |
| `docs/` | Documentación de metodología | Lectura |
| `output/` | Informes generados (Excel, PPT, logs) | Automático |

---

## 6. Conectar con Azure DevOps

### 6.1 Crear el Personal Access Token (PAT)

1. Ir a Azure DevOps > User Settings (icono de engranaje) > Personal Access Tokens.
2. Pulsar «New Token».
3. Nombre: `pm-workspace-cli` (o similar).
4. Expiración: 90 días (renovar periódicamente).
5. Scopes: Work Items (Read & Write), Project and Team (Read), Analytics (Read), Code (Read).
6. Copiar el token generado (no se puede volver a ver).

### 6.2 Guardar el PAT de forma segura

```bash
mkdir -p $HOME/.azure
echo -n "PEGA_TU_PAT_AQUI" > $HOME/.azure/devops-pat
chmod 600 $HOME/.azure/devops-pat
```

> **🔒 Seguridad:** El PAT nunca se hardcodea en ningún fichero del repositorio. PM-Workspace siempre lo lee dinámicamente con `$(cat $HOME/.azure/devops-pat)`.

### 6.3 Configurar Azure CLI

```bash
az devops configure --defaults organization=https://dev.azure.com/TU-ORGANIZACION
export AZURE_DEVOPS_EXT_PAT=$(cat $HOME/.azure/devops-pat)
az devops project list --output table
```

Si ves la lista de proyectos de tu organización, la conexión es correcta.

### 6.4 Editar las constantes globales

Abre `CLAUDE.md` (en la raíz del workspace) y actualiza:

```yaml
AZURE_DEVOPS_ORG_URL = "https://dev.azure.com/TU-ORGANIZACION"
```

---

## 7. Primeros Comandos: Tu Primera Mañana

Con todo configurado, abre Claude Code desde la raíz del workspace:

```bash
cd ~/claude && claude
```

### 7.1 Verificar que Claude conoce el workspace

Escribe en lenguaje natural:

```
¿Qué proyectos tengo configurados y qué puedo hacer?
```

Claude leerá `CLAUDE.md` y te mostrará los proyectos activos y los comandos disponibles.

### 7.2 Estado del sprint (tu comando más usado)

```
/sprint:status --project TuProyecto
```

Muestra: burndown del sprint, items en progreso, alertas de WIP, personas al 100%, items bloqueados y capacidad restante. Ideal para preparar la Daily cada mañana.

### 7.3 Carga del equipo

```
/team:workload --project TuProyecto
```

Muestra un mapa visual de la carga de cada miembro del equipo, con alertas de sobrecarga y sugerencias de redistribución.

### 7.4 Informe de horas

```
/report:hours --project TuProyecto --sprint 2026-04
```

Genera un Excel con 4 pestañas (Resumen, Detalle por persona, Detalle por PBI, Agentes) listo para entregar al cliente o al PMO.

### 7.5 Dashboard de KPIs

```
/kpi:dashboard --project TuProyecto
```

Velocity, cycle time, lead time, bug escape rate y más, calculados automáticamente desde los datos reales de Azure DevOps.

> **💡 Recomendación:** Durante las primeras 2 semanas, usa solo `/sprint:status`, `/team:workload` y `/report:hours`. Familiarízate con estos 3 comandos antes de avanzar a descomposición de PBIs y SDD.

---

## 8. Incorporar un Proyecto Existente

Si tu consultora ya tiene proyectos .NET en Azure DevOps, así los incorporas a PM-Workspace:

### 8.1 Crear la estructura del proyecto

```bash
mkdir -p projects/mi-proyecto/{sprints,specs/templates,source}
```

### 8.2 Crear el CLAUDE.md del proyecto

Crea `projects/mi-proyecto/CLAUDE.md` con las constantes específicas:

```yaml
PROJECT_NAME            = "MiProyecto"
PROJECT_TEAM            = "MiProyecto Team"
CURRENT_SPRINT_PATH     = "MiProyecto\\Sprint 2026-05"
VELOCITY_HISTORICA      = 35
SPRINT_DURATION_DAYS    = 10
FOCUS_FACTOR            = 0.75
```

### 8.3 Documentar el equipo

Crea `projects/mi-proyecto/equipo.md` con los miembros del equipo, sus roles, horas/día, y áreas de expertise. Este fichero es fundamental para que el algoritmo de asignación funcione correctamente.

### 8.4 Documentar las reglas de negocio

Crea `projects/mi-proyecto/reglas-negocio.md` con las reglas de dominio del proyecto. Claude las usará al descomponer PBIs y generar specs.

### 8.5 Clonar el código fuente

```bash
cd projects/mi-proyecto/source
git clone https://dev.azure.com/TU-ORG/MiProyecto/_git/mi-proyecto .
cd ../../..
```

### 8.6 Registrar el proyecto

- Añadir entrada en la tabla «Proyectos Activos» de `CLAUDE.md`.
- Si es un proyecto privado (producción real), añadirlo al `.gitignore`.
- Opcionalmente, añadir a `CLAUDE.local.md` (git-ignorado) para datos sensibles.

### 8.7 Verificar

```bash
cd ~/claude && claude
```

```
/sprint:status --project MiProyecto
```

Si ves el estado del sprint con datos reales, el proyecto está correctamente incorporado.

---

## 9. Crear un Proyecto Nuevo Desde Cero

Si vas a arrancar un proyecto nuevo en la consultora, PM-Workspace te guía desde el inicio.

### 9.1 Crear el proyecto en Azure DevOps

1. Ir a Azure DevOps > New Project.
2. Nombre, descripción y visibilidad según política de la consultora.
3. Crear el equipo (Team) con los miembros asignados.
4. Configurar el primer sprint (iteración) con fechas.

### 9.2 Crear la estructura en PM-Workspace

Sigue los pasos 8.1 a 8.6 adaptando las constantes al nuevo proyecto.

### 9.3 Crear los primeros PBIs

Crea los PBIs en Azure DevOps con criterios de aceptación claros. Luego usa PM-Workspace para preparar el sprint:

```
/pbi:plan-sprint --project NuevoProyecto
```

Claude calculará la capacity del equipo, seleccionará los PBIs que caben en el sprint, los descompondrá en tasks y propondrá asignaciones.

### 9.4 Product Discovery (opcional pero recomendado)

Antes de descomponer un PBI, puedes usar los comandos de discovery:

```
/pbi:jtbd {id}    ← Genera el JTBD (Jobs to be Done)
/pbi:prd {id}     ← Genera el PRD (Product Requirements)
```

Esto asegura que el PBI está bien definido antes de invertir tiempo en descomposición y desarrollo.

---

## 10. Onboarding del Equipo de Programadores

PM-Workspace incluye un sistema de onboarding automatizado que facilita la incorporación de nuevos programadores al equipo, cumpliendo con la normativa RGPD/LOPDGDD española y europea.

### 10.1 Flujo de onboarding

El proceso tiene 3 pasos obligatorios, siempre en este orden:

| Paso | Comando | Qué hace |
|------|---------|----------|
| 1. Nota informativa RGPD | `/team:privacy-notice {nombre}` | Genera la nota informativa legal para que el trabajador sepa qué datos se recogen, con qué finalidad y sus derechos ARCO-POL |
| 2. Guía de onboarding | `/team:onboarding {nombre}` | Genera una guía personalizada: contexto del proyecto, tour por el código, convenciones, primeras tasks |
| 3. Evaluación de competencias | `/team:evaluate {nombre}` | Cuestionario interactivo de 26 competencias (12 .NET + 7 transversales + dominio) que actualiza `equipo.md` |

### 10.2 Ejemplo práctico: incorporar a un nuevo programador

**Escenario:** Laura García se incorpora al proyecto GestiónClínica como Full Stack.

**Paso 1 — Generar la nota informativa RGPD**

```
/team:privacy-notice "Laura García" --project GestionClinica
```

Claude genera el documento en `projects/gestion-clinica/privacy/` con los datos de la empresa ya rellenados. El PM imprime el documento, Laura lo lee y firma el acuse de recibo.

**Paso 2 — Generar la guía de onboarding**

```
/team:onboarding "Laura García" --project GestionClinica
```

Claude lee el `CLAUDE.md` del proyecto, `equipo.md`, `reglas-negocio.md` y el código fuente, y genera una guía personalizada con: resumen del proyecto, arquitectura, módulos principales, convenciones de código, y las primeras tasks sugeridas para ir cogiendo ritmo.

**Paso 3 — Evaluar competencias**

```
/team:evaluate "Laura García" --project GestionClinica
```

Claude conduce un cuestionario interactivo en grupos de 3 preguntas. Evalúa 12 competencias .NET/C#, 7 transversales y las del dominio del proyecto. Cada competencia se valora de 1 a 5 (escala Shu-Ha-Ri: Aprendiz → Referente) con evidencias verificables. El resultado se guarda en `equipo.md` para mejorar las asignaciones futuras.

> **⚖️ Conformidad legal:** El sistema usa interés legítimo (Art. 6.1.f RGPD) como base legal, no consentimiento. La nota informativa NO es un formulario de consentimiento sino una comunicación de derechos conforme a los Arts. 13-14 RGPD y la LOPDGDD (Ley Orgánica 3/2018). Los datos se almacenan con minimización (sin datos personales más allá del nombre y nivel) y están protegidos por el `.gitignore`.

---

## 11. Roadmap de Adopción Gradual

La adopción recomendada es incremental. No intentes usar todas las funcionalidades desde el primer día.

| Semanas | Fase | Objetivo | Comandos clave |
|---------|------|----------|----------------|
| 1-2 | Conexión | Configurar PAT, verificar conectividad, primer `/sprint:status` | `/sprint:status` |
| 3-4 | Gestión básica | Usar `/sprint:status` cada mañana, `/team:workload`, ajustar constantes | `/team:workload`, `/report:capacity` |
| 5-6 | Reporting | Generar informes para el cliente con datos reales | `/report:hours`, `/report:executive` |
| 7-8 | SDD piloto | Generar 2-3 specs, probar agente con 1 task de Application Layer | `/spec:generate`, `/agent:run` |
| 9-10 | Onboarding + escala | Incorporar nuevos miembros, escalar SDD a 40%+ | `/team:onboarding`, `/team:evaluate` |

### Indicadores de éxito por fase

- **Fase 1-2:** El PM puede ver el estado real del sprint sin abrir Azure DevOps.
- **Fase 3-4:** El PM prepara la Daily en <5 minutos con `/sprint:status`.
- **Fase 5-6:** El informe de horas se genera en <2 minutos (antes: 30-60 min manual).
- **Fase 7-8:** Al menos 1 task repetitiva implementada por agente sin errores.
- **Fase 9-10:** Nuevos miembros incorporados con guía personalizada y evaluación de competencias.

---

## 12. Resolución de Problemas Frecuentes

| Problema | Causa probable | Solución |
|----------|---------------|----------|
| `claude: command not found` | Claude Code no instalado o no en PATH | Reinstalar con `curl -fsSL https://claude.ai/install.sh \| sh` |
| `TF400813: Not authorized` | PAT inválido o expirado | Regenerar PAT en Azure DevOps y guardar en `$HOME/.azure/devops-pat` |
| `az: command not found` | Azure CLI no instalado | Instalar desde https://aka.ms/installazurecliwindows |
| Resultados vacíos del sprint | Sprint no activo o nombre incorrecto | Verificar en AzDO > Project Settings > Iterations que el sprint esté activo |
| Claude no reconoce el proyecto | `CLAUDE.md` no actualizado | Añadir proyecto a la tabla «Proyectos Activos» de `CLAUDE.md` |
| `/sprint:status` sin datos | IterationPath incorrecto en `CLAUDE.md` | Verificar `CURRENT_SPRINT_PATH` con el nombre exacto de AzDO (con `\\`) |
| Error de contexto largo | Conversación demasiado larga | Usar `/compact` o `/clear` y reformular |
| Agente SDD falla inmediatamente | Spec incompleta o con placeholders | Revisar con `/spec:review` antes de `/agent:run` |
| `npm: command not found` | Node.js no instalado | Instalar Node.js ≥ 18 desde [nodejs.org](https://nodejs.org) |

---

## 13. Glosario

| Término | Definición |
|---------|-----------|
| **Azure DevOps (AzDO)** | Plataforma de Microsoft para gestión de proyectos, repositorios Git y CI/CD |
| **Claude Code** | CLI de Anthropic que permite interactuar con Claude como agente de código en terminal |
| **PAT** | Personal Access Token — credencial para autenticarse con la API de Azure DevOps |
| **PBI** | Product Backlog Item — elemento del backlog (historia de usuario, feature, bug) |
| **SDD** | Spec-Driven Development — metodología en la que las tasks se documentan como specs ejecutables |
| **Spec** | Fichero `.spec.md` que define un contrato técnico para implementación (humana o por agente) |
| **Skill** | Paquete de conocimiento especializado que Claude usa para realizar una tarea específica |
| **Subagente** | Instancia de Claude especializada en una tarea concreta (ej: architect, code-reviewer) |
| **RGPD** | Reglamento General de Protección de Datos (UE 2016/679) |
| **LOPDGDD** | Ley Orgánica 3/2018 de Protección de Datos (transposición española del RGPD) |
| **WIQL** | Work Item Query Language — lenguaje de consulta de Azure DevOps |
| **Burndown** | Gráfico que muestra el progreso del sprint (story points restantes vs días) |
| **Capacity** | Horas reales disponibles de cada miembro del equipo en un sprint |
| **Scoring de asignación** | Algoritmo: `expertise × 0.40 + disponibilidad × 0.30 + balance × 0.20 + crecimiento × 0.10` |

---

*PM-Workspace — Claude Code + Azure DevOps para equipos .NET/Scrum*
*[github.com/gonzalezpazmonica/pm-workspace](https://github.com/gonzalezpazmonica/pm-workspace)*
