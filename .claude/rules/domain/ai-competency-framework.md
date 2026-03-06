---
paths:
  - "**/ai-competency*"
  - "**/competency-*"
---

# AI Competency Framework — Habilidades para la Era IA

> Complementa ADKAR con competencias específicas de "working with AI".
> Fuente: reflexiones Enrique Dans + taxonomía Kelman Celis.

---

## Principio

Las competencias técnicas puras ya no son suficientes. Los equipos
necesitan habilidades para trabajar CON inteligencia artificial:
formular problemas, evaluar outputs, pensar críticamente.

---

## 6 Competencias AI-Era

### 1. Problem Formulation (Formulación de Problemas)

Capacidad de descomponer un problema complejo en prompts accionables.

| Nivel | Descripción |
|---|---|
| 1 - Básico | Pide "arregla el bug" sin contexto |
| 2 - Intermedio | Describe el síntoma + ficheros relevantes |
| 3 - Avanzado | Proporciona reproducción + expectativa + constraints |
| 4 - Experto | Estructura la petición con explorar → planificar → implementar |

### 2. Output Evaluation (Evaluación de Resultados)

Capacidad de evaluar críticamente lo que genera la IA.

| Nivel | Descripción |
|---|---|
| 1 - Básico | Acepta todo output sin revisar |
| 2 - Intermedio | Revisa output superficialmente |
| 3 - Avanzado | Verifica contra tests, ejecuta, compara |
| 4 - Experto | Detecta edge cases, sugiere mejoras, itera |

### 3. Context Engineering (Ingeniería de Contexto)

Capacidad de proporcionar el contexto correcto a la IA.

| Nivel | Descripción |
|---|---|
| 1 - Básico | No proporciona contexto adicional |
| 2 - Intermedio | Referencia ficheros relevantes |
| 3 - Avanzado | Usa CLAUDE.md, rules, skills para enriquecer |
| 4 - Experto | Optimiza contexto: `/compact`, subagentes, output-first |

### 4. AI Orchestration (Orquestación de IA)

Capacidad de coordinar múltiples herramientas y agentes IA.

| Nivel | Descripción |
|---|---|
| 1 - Básico | Usa un solo comando a la vez |
| 2 - Intermedio | Encadena 2-3 comandos en secuencia |
| 3 - Avanzado | Usa SDD completo: spec → implement → test → review |
| 4 - Experto | Orquesta Agent Teams, paraleliza, optimiza flujo |

### 5. Critical Thinking (Pensamiento Crítico)

Capacidad de cuestionar, verificar y no confiar ciegamente.

| Nivel | Descripción |
|---|---|
| 1 - Básico | "La IA lo dice, será correcto" |
| 2 - Intermedio | Verifica outputs obvios, ignora edge cases |
| 3 - Avanzado | Cuestiona suposiciones, pide alternativas |
| 4 - Experto | Diseña tests adversariales, busca fallos |

### 6. Ethical Awareness (Conciencia Ética)

Capacidad de considerar implicaciones éticas del uso de IA.

| Nivel | Descripción |
|---|---|
| 1 - Básico | No considera implicaciones éticas |
| 2 - Intermedio | Conoce RGPD/AEPD básico |
| 3 - Avanzado | Aplica privacy by design, evalúa sesgos |
| 4 - Experto | Implementa governance, EIPD, audit trails |

---

## Scoring

```
score_total = promedio(6 competencias) × 25
```

| Score | Nivel Equipo | Acción |
|---|---|---|
| 80-100 | AI-Native | Mentores para otros equipos |
| 60-79 | AI-Proficient | Profundizar en orquestación |
| 40-59 | AI-Aware | Plan formación 8 semanas |
| 20-39 | AI-Curious | Awareness + sandbox primero |
| 0-19 | AI-Resistant | Storytelling + quick wins |

---

## Integración con ADKAR

| ADKAR | Competencia AI que refuerza |
|---|---|
| Knowledge | Problem Formulation + Context Engineering |
| Ability | Output Evaluation + AI Orchestration |
| Reinforcement | Critical Thinking + Ethical Awareness |

---

## Evaluación

Savia evalúa mediante preguntas situacionales:

```
"Tu equipo recibe un código generado por IA que pasa todos los tests
pero tiene un nombre de variable confuso. ¿Qué hace el equipo?"

a) Lo acepta tal cual (nivel 1)
b) Renombra la variable (nivel 2)
c) Revisa todo el output buscando más issues (nivel 3)
d) Pide al agente que refactorice + añade test de naming (nivel 4)
```
