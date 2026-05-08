# Plantilla — Auditoría objetiva de desarrollador (HR-grade)

**Última actualización**: 2026-04-28
**Estado**: estable v1.0
**Uso**: auditorías de desarrolladores para expediente RR.HH., evaluaciones de desempeño, calibración de squads, decisiones de continuidad.
**Audiencia**: PM, RR.HH., PM-Center, TLs.
**Autor de la plantilla**: PM Mónica (a partir de las auditorías `20260424-audit-lester-arellano.md` y `20260428-alex-gonzalez-sprint26-hr-audit.md`).

---

## 0. Cómo usar esta plantilla

1. Sustituye `{PERSONA}`, `{PERIODO}`, `{SQUAD}` y demás placeholders entre llaves por los valores reales.
2. Recoge los datos de las **fuentes obligatorias** (sec. A) antes de empezar a redactar. No infieras lo que no consta en fuente.
3. Ejecuta los **scripts de extracción** (sec. F) o equivalente manual para obtener métricas comparativas reproducibles.
4. Para cada bloque del scoreboard:
   - **Productividad** → puntuación por posición relativa dentro del cohorte de devs del squad/team con commits en el periodo.
   - **Calidad, disciplina, comunicación** → puntuación por umbrales absolutos (ver sec. E).
5. Si la auditoría es para un caso disciplinario, el informe **debe** incluir tanto lo imputable a la persona como lo imputable al proceso (sec. 6 del informe). RR.HH. necesita ambas lecturas.
6. **Nunca** sustituyas datos por opiniones. La sección 5 (negligencias) sólo se rellena con commits y SHAs verificables.
7. Persiste el informe con nombre `YYYYMMDD-{persona-slug}-{periodo}-hr-audit.md` en la carpeta `audits/` del proyecto.
8. Si el caso es sensible (RR.HH., expediente disciplinario), clasifica como **N4b-PM** o **N4c-MONICA-ONLY** según corresponda.

---

## Estructura del informe (copiar-pegar y rellenar)

```markdown
# Auditoría objetiva — {NOMBRE COMPLETO} — {PERIODO}

**Última actualización**: {YYYY-MM-DD}
**Periodo cubierto**: {Sprint NN o rango YYYY-MM-DD → YYYY-MM-DD} ({días laborables})
**Persona auditada**: {nombre tal como aparece en Azure DevOps}
**Equipo**: {Squad / Team / Área}
**Solicitante**: {PM, TL, RR.HH., DL...}
**Fuentes**: {Azure DevOps REST API · repos Git · Excel sprint · transcripciones de retros · etc.}
**Clasificación**: {N4b-PM | N4c-MONICA-ONLY | N4-VASS}

## 1. Resumen ejecutivo

{Un párrafo: qué se observa, magnitud, riesgo, decisión que el informe permite tomar.}

Hechos objetivos del periodo:
- {Bullet 1}
- {Bullet 2}
- {Bullet 3}
- {Bullet 4}

## 2. Trabajo declarado en Azure DevOps

PBIs en los que ha contribuido en el periodo:

| PBI | Título | Owner declarado | State |
|---|---|---|---|
| AB#... | ... | ... | ... |

Tareas asignadas (estimación / horas imputadas / estado):

| Task | Título | OE | CW | RW | State al cierre auditoría |
|---|---|:---:|:---:|:---:|:---:|

Observaciones objetivas sobre la imputación:
- {anomalías de tracking, transiciones extrañas, comentarios ausentes, etc.}

## 3. Actividad en Git ({rango de fechas})

Total commits firmados en el periodo:

| Repositorio | Commits | Notas |
|---|:---:|---|
| ... | ... | ... |

Distribución por mensaje de commit (calidad descriptiva):
- Mensajes informativos: {%}
- Mensajes vagos: {%}
- Mensajes con typo: {%}
- Mensajes que delatan trabajo de hotfix post-merge: {%}

Patrones notables:
- {commits duplicados, ramas equivocadas, push de credenciales locales, etc.}

PRs propios abiertos y abandonados el mismo día:

| PR | Repo | Apertura → abandono | Tiempo de vida |
|---|---|---|---|

## 4. Pull Requests del periodo

Tabla de PRs creados con métricas:

| Métrica | Valor |
|---|---|
| Reviewers únicos en sus PRs (periodo) | ... |
| Reviewers únicos en sus PRs (histórico) | ... |
| PRs con más de un reviewer | ... |
| PRs con comentarios técnicos en threads | ... |
| Tiempo medio merge desde apertura | ... |
| Tests añadidos | ... |

| PR | Repo | Título | Estado | Apertura | Cierre |
|---|---|---|---|---|---|

## 5. Hallazgos de {negligencia | excelencia | observación} con evidencia

> Solo se incluyen casos donde el commit en sí mismo evidencia el rasgo evaluado, no opiniones sobre estilo.

### 5.{N} {Título descriptivo del hallazgo} — {AB#PBI}

**Repo**: {nombre}
**Rama**: `{branch}`
**Commit**: `{SHA completo}` — {autor} — **{YYYY-MM-DD HH:MM:SS}** — message: "{mensaje}"
**Fichero**: `{path}`

{Snippet de código, máximo ~12 líneas, solo si aporta evidencia objetiva.}

**Lectura**: {1-2 líneas explicando por qué este commit es evidencia del rasgo.}

## 6. Calidad del proceso de revisión y entorno

Importante separar lo imputable a la persona de lo imputable al equipo:
- **Imputable a {PERSONA}**: {lista}
- **Imputable al proceso / equipo**: {lista}
- **No imputable directamente a nadie (contexto)**: {lista}

## 7. Comparación con periodos anteriores (control)

{Indica si el patrón observado es específico del periodo o sostenido. Pulla 2-3 PRs / commits previos del mismo perfil para comparar.}

## 8. Datos cuantitativos para el expediente

| Métrica | Valor |
|---|---|
| Tareas asignadas | ... |
| Tareas marcadas Done | ... |
| Horas estimadas (OE total) | ... |
| Horas imputadas (CW total) | ... |
| Comentarios escritos en sus tareas | ... |
| Comentarios escritos en PBIs padre | ... |
| Commits totales | ... |
| Commits con mensaje vago o typo | ... |
| PRs creados | ... |
| PRs propios abandonados | ... |
| PRs hotfix tras merge del PR original | ... |
| Reviewers únicos | ... |
| Tests automatizados añadidos | ... |
| Bugs/regresiones tras merge atribuibles a sus PRs | ... |

## 9. Lectura objetiva para RR.HH. / decisión

Lo que el dato sí dice:
1. {hecho}
2. {hecho}

Lo que el dato no dice:
- {limitación 1}
- {limitación 2}

## 10. Recomendaciones en términos de proceso

{Independientemente de la decisión RR.HH., qué cambios necesita el equipo.}

## 11. Anexos para verificación independiente

- Azure DevOps work items: `https://dev.azure.com/{org}/{project}/_workitems/edit/{id}`
- Repos: `https://dev.azure.com/{org}/{project}/_git/{repo}`
- Branches relevantes: {lista}
- SHAs completos: ya citados en sec. 5.

## 12. Scoreboard — puntuación por categoría

Sistema de puntuación: las **categorías de productividad** se puntúan por posición relativa dentro del cohorte de devs del squad/team con commits en el periodo. Las **categorías de calidad, disciplina y comunicación** se puntúan contra umbrales absolutos definidos en el Anexo A.

Escala posicional (n devs en cohorte): se reparten los puntos 100/(n-1) en cada posición. Para 8 devs: 1º=100, 2º=87, 3º=75, 4º=62, 5º=50, 6º=37, 7º=25, 8º=12. Para 6 devs: 100, 80, 60, 40, 20, 0.
Barra visual: 25 caracteres, cada ■ ≈ 4 puntos.
Símbolos: ★ = top del cohorte / categoría; * = nota al margen.

```
CATEGORÍA                                   PUNTUACIÓN   BARRA                                NOTA
──────────────────────────────────────────────────────────────────────────────────────────────────────────
PRODUCTIVIDAD (relativa, cohorte = N devs)
Presencia (días con commit)                ... / 100    {bar}                      {pos}
Volumen commits totales                    ... / 100    {bar}                      {pos}
Volumen líneas/ficheros tocados            ... / 100    {bar}                      {pos}
Cobertura backend                          ... / 100    {bar}                      {pos}
Cobertura frontend                         ... / 100    {bar}                      {pos}
Cobertura BBDD                             ... / 100    {bar}                      {pos}
──────────────────────────────────────────────────────────────────────────────────────────────────────────
CALIDAD DE CÓDIGO (umbral absoluto)
Negligencias técnicas documentadas         ... / 100    {bar}                      {n} casos
Cumplimiento DoD                           ... / 100    {bar}                      {n} incumplimientos
Cobertura tests automatizados              ... / 100    {bar}                      {n} tests / {n} PRs
Calidad mensajes de commit                 ... / 100    {bar}                      {%} vagos/typos
──────────────────────────────────────────────────────────────────────────────────────────────────────────
DISCIPLINA DE PROCESO (umbral absoluto)
Tasa hotfix post-merge                     ... / 100    {bar}                      {n} hotfix PRs
PBIs entregados sin hotfix posterior       ... / 100    {bar}                      {n}/{N} limpios
Diversidad de revisores en sus PRs         ... / 100    {bar}                      {n} reviewers únicos
PRs propios abandonados                    ... / 100    {bar}                      {n} abandonados
──────────────────────────────────────────────────────────────────────────────────────────────────────────
COMUNICACIÓN Y TRACKING
Comentarios escritos en sus tareas         ... / 100    {bar}                      {n} comentarios
Comentarios técnicos en sus PRs            ... / 100    {bar}                      {n} threads técnicos
Coherencia tracking horas                  ... / 100    {bar}                      {n} anomalías
──────────────────────────────────────────────────────────────────────────────────────────────────────────
CUMPLIMIENTO SPRINT
Cumplimiento sprint (CW vs cap.)           ... / 100    {bar}                      {%} vs OE
Compromiso / esfuerzo sostenido            ... / 100    {bar}                      {nota}
──────────────────────────────────────────────────────────────────────────────────────────────────────────
GLOBAL PONDERADO                           ... / 100    {bar}
══════════════════════════════════════════════════════════════════════════════════════════════════════════
```

**Pesos aplicados** (deben sumar 100 %): ver tabla más abajo. **Los pesos de esta plantilla pueden ajustarse según el propósito de la auditoría** (HR-grade, evaluación calibración, retención de talento, etc.); declararlo siempre explícitamente.

**Distribución por bloque**:

| Bloque | Peso | Score bloque | Aportación al global |
|---|:---:|:---:|:---:|
| Productividad | ... % | ... / 100 | ... |
| Calidad de código | ... % | ... / 100 | ... |
| Disciplina de proceso | ... % | ... / 100 | ... |
| Comunicación y tracking | ... % | ... / 100 | ... |
| Cumplimiento sprint | ... % | ... / 100 | ... |
| **Total** | **100 %** | — | **... / 100** |

**Comparativa con auditorías previas del mismo proyecto** (referencia, no medida en el mismo periodo):

| Persona | Squad / Team | Periodo auditado | Global ponderado |
|---|:---:|:---:|:---:|
```

---

## Anexo A — Umbrales absolutos (referencia para puntuación)

Estos umbrales son los aplicados en las auditorías de example-project; pueden adaptarse a la práctica del proyecto auditado y deben **declararse explícitamente** en el Anexo A del informe concreto.

| Métrica | 100/100 | 50/100 | 0/100 |
|---|---|---|---|
| Negligencias técnicas (sec. 5 del informe) | 0 | 1-2 | 3+ |
| Cumplimiento DoD (incumplimientos sostenibles) | 0 | 1-2 | 3+ |
| Cobertura tests automatizados | ≥1 test por PR de feature | tests en ≥30 % de PRs | 0 tests |
| Calidad mensajes commit (% vagos/typos sobre total) | <10 % | 10-30 % | >30 % |
| Tasa hotfix post-merge | 0 hotfix | 1-2 hotfix | 3+ hotfix |
| PBIs entregados sin hotfix posterior (%) | 100 % | 50-99 % | <50 % |
| Diversidad reviewers (únicos rotando en PRs propios) | ≥3 distintos | 2 distintos | 1 único |
| PRs propios abandonados | 0 | 1-2 | 3+ |
| Comentarios escritos en sus tareas (por sprint) | ≥3 sustantivos | 1-2 | 0 |
| Comentarios técnicos en sus PRs (no system) | ≥1 thread técnico por PR | ocasional | 0 |
| Coherencia tracking horas (anomalías por sprint) | 0 | 1-2 | 3+ |

Las **definiciones de "negligencia técnica" y "incumplimiento DoD"** son las del proyecto y deben listarse en la sección 5 del informe con commits/SHAs concretos.

---

## Anexo B — Pesos sugeridos por tipo de auditoría

### B.1 Auditoría HR-grade (caso disciplinario / bajo desempeño)

Prioriza calidad, disciplina y comunicación; productividad secundaria.

| Bloque | Peso |
|---|:---:|
| Calidad de código | 35-40 % |
| Disciplina de proceso | 20-25 % |
| Comunicación y tracking | 15 % |
| Productividad | 15-20 % |
| Cumplimiento sprint | 5-10 % |

### B.2 Auditoría de calibración / evaluación regular (squad-wide)

Equilibra todos los bloques; mide consistencia.

| Bloque | Peso |
|---|:---:|
| Productividad | 30 % |
| Calidad de código | 25 % |
| Disciplina de proceso | 15 % |
| Cumplimiento sprint | 15 % |
| Comunicación y tracking | 15 % |

### B.3 Auditoría de retención / talento alto

Pesa más volumen, calidad y compromiso; menos disciplina formal.

| Bloque | Peso |
|---|:---:|
| Productividad | 35 % |
| Calidad de código | 25 % |
| Cumplimiento sprint | 20 % |
| Compromiso / esfuerzo | 10 % |
| Comunicación y tracking | 10 % |

---

## Anexo C — Cohorte de comparación

Reglas para definir el cohorte de productividad relativa:

1. **Mínimo 4 devs** en el cohorte para que la posición relativa sea estadísticamente significativa. Por debajo de 4, usar **solo umbrales absolutos** y omitir el bloque de productividad relativa.
2. Incluir solo devs con **≥10 commits sustantivos** en el periodo (excluyendo merges automáticos).
3. Si hay devs cross-squad (commits en repos del proyecto pero asignaciones formales a otro squad), incluirlos solo si tienen ≥1 PBI asignado en el AreaPath del cohorte.
4. Excluir TLs/managers que codifican ocasionalmente (su patrón de commits no es comparable con devs full-time).
5. Documentar el cohorte explícitamente en la sec. 12 del informe.

---

## Anexo D — Métricas que NO se incluyen en el scoreboard (intencional)

- **Líneas brutas añadidas**: distorsionado por merges, cherry-picks, generación automática.
- **Días en oficina / asistencia**: no es un indicador de output ni de calidad.
- **Velocidad de typing / commits por hora**: incentiva commits ruido.
- **Issues cerrados sin contexto del trabajo real**: un dev puede cerrar issues triviales y dejar abiertos los difíciles.
- **Aprobaciones recibidas en PRs propios**: depende del reviewer, no del autor. Si todas vienen de un único reviewer (caso negativo) ya se mide en "Diversidad de revisores".

---

## Anexo E — Casos límite y reglas de decisión

| Caso | Regla |
|---|---|
| Persona con menos de 5 días laborables en el periodo (vacaciones, baja) | NO auditar. Esperar a periodo normal o ampliar ventana. |
| Persona en periodo de prueba (<3 meses) | Etiquetar el informe como "evaluación junior, no comparativa". Ajustar umbrales DoD a junior. |
| Persona que cambió de squad durante el periodo | Auditar por cada squad por separado o eliminar el cambio del periodo. |
| Persona TL/lead que codifica ocasionalmente | Excluir del cohorte de productividad. Auditar disciplina y revisión, no volumen. |
| Persona con incidencia personal grave reconocida | Anexar nota de contexto en sec. 6 (impactable al proceso, no a la persona). |
| Falta de fuente de datos (DevOps caído, repo migrado) | Aplazar. NUNCA inventar. |
| Periodo demasiado corto (<5 días laborables) | Aplazar. Resultados no significativos. |

---

## Anexo F — Scripts de extracción (referencia)

Las consultas usadas se documentan en cada informe concreto pero el patrón base es:

### F.1 Sprint dates

```bash
PAT=$(cat $HOME/.azure/{proyecto}-pat | tr -d '\r\n')
ORG="https://dev.azure.com/{org}/{proyecto-url-encoded}"
curl -s -u ":$PAT" "$ORG/_apis/wit/classificationnodes/iterations?\$depth=10&api-version=7.1"
```

### F.2 Work items asignados a la persona en sprint

```bash
WIQL='{"query":"SELECT ... WHERE [System.IterationPath] = '\''{path}'\'' AND ([System.AssignedTo] CONTAINS '\''{persona}'\'' OR [System.ChangedBy] CONTAINS '\''{persona}'\'')"}'
curl -s -u ":$PAT" -H "Content-Type: application/json" -d "$WIQL" "$ORG/_apis/wit/wiql?api-version=7.1"
```

### F.3 Revisiones de un work item (estados, horas)

```bash
curl -s -u ":$PAT" "$ORG/_apis/wit/workItems/{id}/revisions?api-version=7.1"
```

### F.4 Comentarios en work item

```bash
curl -s -u ":$PAT" "$ORG/_apis/wit/workItems/{id}/comments?api-version=7.1-preview.4"
```

### F.5 Commits por autor en repo y rango

```bash
curl -s -u ":$PAT" "$ORG/_apis/git/repositories/{repo-id}/commits?searchCriteria.author={persona}&searchCriteria.fromDate={YYYY-MM-DD}&searchCriteria.toDate={YYYY-MM-DD}&searchCriteria.\$top=200&api-version=7.1"
```

### F.6 PRs por persona en repo

```bash
curl -s -u ":$PAT" "$ORG/_apis/git/repositories/{repo-id}/pullrequests?searchCriteria.status=all&\$top=200&api-version=7.1"
```

### F.7 Threads (comentarios) en PR

```bash
curl -s -u ":$PAT" "$ORG/_apis/git/repositories/{repo-id}/pullRequests/{pr-id}/threads?api-version=7.1"
```

### F.8 Diff de un commit concreto

```bash
curl -s -u ":$PAT" "$ORG/_apis/git/repositories/{repo-id}/commits/{sha-completo}/changes?api-version=7.1&top=200"
```

### F.9 Contenido de un fichero en un commit (para snippets)

```bash
curl -s -u ":$PAT" "$ORG/_apis/git/repositories/{repo-id}/items?path={ruta}&versionDescriptor.version={sha}&versionDescriptor.versionType=commit&\$format=text&api-version=7.1"
```

---

## Anexo G — Ética del informe

Reglas no negociables al producir una auditoría con esta plantilla:

1. **Solo datos verificables**. Ninguna afirmación sin commit, SHA, work item ID o snapshot reproducible.
2. **No afirmaciones testimoniales como hechos**. Si Ana dijo en chat "Alex insistió en standup que funcionaba", eso se incluye con atribución y como testimonio, no como hecho.
3. **No interpretación motivacional**. No calificar como "negligente" cuando el dato sólo prueba "no funcional". El lector decide la atribución de causa.
4. **No comparación contra estándares ad-hoc**. Si se compara contra el cohorte, declarar el cohorte. Si se compara contra umbrales, declararlos en el Anexo A.
5. **Separar lo imputable a la persona de lo imputable al proceso**. Sec. 6 obligatoria.
6. **Lectura para RR.HH. acotada al dato**. Sec. 9 dice "lo que el dato sí dice" y "lo que el dato no dice". Esa segunda es tan importante como la primera.
7. **Reproducibilidad**. Cualquier auditor con acceso a las fuentes debe poder reproducir las cifras. Sec. 11 lista las URLs y SHAs necesarios.
8. **Confidencialidad**. Clasificar el informe (N4b-PM o N4c-MONICA-ONLY si afecta a evaluaciones disciplinarias). NUNCA compartir con personas fuera del círculo autorizado.

---

## Anexo H — Versión de la plantilla

| Versión | Fecha | Cambios |
|---|:---:|---|
| v1.0 | 2026-04-28 | Versión inicial. Síntesis de Lester (rango temporal largo, posicional dominante) y Alex (HR-grade, umbrales absolutos dominantes). Incluye cohorte cross-squad, perfiles de pesos según propósito, y reglas de ética. |

---

*Esta plantilla es propiedad del PM-Center. Cualquier modificación estructural (añadir/quitar bloques, cambiar la escala de barras) debe consensuarse con PM-Center y RR.HH. para mantener la comparabilidad histórica de los informes.*
