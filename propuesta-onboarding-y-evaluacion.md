# Onboarding con IA + Evaluaci&oacute;n de Expertise del Equipo

**Propuesta para pm-workspace** &mdash; febrero 2026

---

## 1. Onboarding de nuevos desarrolladores asistido por IA

### 1.1 Problema actual

Cuando un programador se incorpora a un proyecto .NET en curso, el ramp-up t&iacute;pico es de 4-8 semanas hasta alcanzar productividad plena. La mayor&iacute;a del tiempo se pierde en: entender la arquitectura, localizar c&oacute;digo relevante, descifrar convenciones no documentadas y esperar a que un senior est&eacute; disponible para resolver dudas.

### 1.2 Propuesta: onboarding en 5 fases asistido por Claude

El proceso se dise&ntilde;a para que un nuevo miembro del equipo llegue a su primera contribuci&oacute;n significativa en **3-5 d&iacute;as** (no semanas), usando la IA como acelerador y al mentor humano como validador.

#### Fase 1 &mdash; Contexto inmediato (D&iacute;a 1, ma&ntilde;ana)

**Qu&eacute; hace la persona nueva:** ejecuta `/context:load` y despu&eacute;s pregunta a Claude:

```
Soy nuevo en este proyecto. Expl&iacute;came la arquitectura general,
los m&oacute;dulos principales, las convenciones del equipo y qu&eacute; debo
saber antes de tocar c&oacute;digo.
```

**Qu&eacute; hace Claude:** lee el CLAUDE.md del proyecto, el equipo.md, las reglas-negocio.md, la estructura del source/ y genera un resumen ejecutivo personalizado con: diagrama de capas, m&oacute;dulos principales, patrones usados (CQRS, Clean Architecture, etc.), convenciones de naming y la cadena de dependencias cr&iacute;ticas.

**Tiempo:** 30-60 minutos. **Verificable:** el nuevo miembro puede dibujar el diagrama de arquitectura sin ayuda.

#### Fase 2 &mdash; Navegaci&oacute;n del c&oacute;digo (D&iacute;a 1, tarde)

**Qu&eacute; hace la persona nueva:** Claude genera un tour guiado del codebase, empezando por el entry point de la API, siguiendo el flujo de un request t&iacute;pico hasta la base de datos, y mostrando el patr&oacute;n de cada capa con un ejemplo real del proyecto.

```
Mu&eacute;strame el flujo completo de un POST /salas desde el Controller
hasta la base de datos, explicando cada capa que atraviesa.
```

**Herramientas complementarias:** Claude Code con `/evaluate:repo` sobre el propio proyecto para que el nuevo miembro entienda la calidad actual y las &aacute;reas de mejora.

**Tiempo:** 2-3 horas. **Verificable:** la persona puede explicar el flujo de un endpoint al mentor.

#### Fase 3 &mdash; Primera tarea asistida (D&iacute;as 2-3)

**Qu&eacute; hace el mentor:** selecciona una task sencilla (complejidad B o C en la nomenclatura SDD &mdash; un validator, un DTO, un unit test) y la asigna al nuevo miembro.

**Qu&eacute; hace la persona nueva:** usa Claude como pair programmer. Claude sugiere c&oacute;digo, la persona revisa, entiende y modifica. El mentor revisa el resultado final (Code Review humano obligatorio &mdash; regla E1 del SDD).

**Patr&oacute;n clave: "Pausa y Resuelve"** &mdash; la persona intenta resolver el problema sola durante 15-20 minutos ANTES de pedir ayuda a Claude. Despu&eacute;s compara su soluci&oacute;n con la de la IA. Esto construye comprensi&oacute;n real, no dependencia.

**Tiempo:** 1-2 d&iacute;as. **Verificable:** PR aprobado con code review del Tech Lead.

#### Fase 4 &mdash; Cuestionario de competencias (D&iacute;a 3)

La persona nueva completa el cuestionario de evaluaci&oacute;n de expertise (Secci&oacute;n 2 de este documento). Esto permite:

- Registrar su perfil t&eacute;cnico para el algoritmo de asignaci&oacute;n.
- Identificar &aacute;reas de mentoring espec&iacute;fico.
- Ajustar el peso de `growth` en su scoring de asignaci&oacute;n para las primeras semanas.

**Tiempo:** 30-45 minutos. **Verificable:** perfil registrado en equipo.md con consentimiento documentado.

#### Fase 5 &mdash; Autonom&iacute;a progresiva (D&iacute;as 4-10)

**Semana 1:** tasks de capa Application con spec SDD (el contrato elimina ambig&uuml;edad).
**Semana 2:** tasks de capa m&aacute;s variada, incluyendo alguna de Infrastructure.
**Semana 3+:** flujo normal del equipo, con mentor disponible bajo demanda.

El mentor revisa c&oacute;digo de TODAS las tasks del nuevo miembro durante las primeras 3 semanas (no solo las E1 de SDD).

### 1.3 M&eacute;tricas de &eacute;xito del onboarding

| M&eacute;trica | Objetivo | C&oacute;mo se mide |
|---------|----------|-----------------|
| Time-to-First-PR | &le; 3 d&iacute;as | Timestamp del primer PR aprobado |
| Calidad del primer PR | &le; 3 rondas de review | N&uacute;mero de comentarios de code review |
| Confianza autoreportada | &ge; 7/10 | Encuesta al d&iacute;a 5 y d&iacute;a 15 |
| Independencia al d&iacute;a 10 | Puede tomar tasks sin spec | Validaci&oacute;n del mentor |
| Retenci&oacute;n a 90 d&iacute;as | 100% | Seguimiento HR |

### 1.4 Lo que la IA NO sustituye en el onboarding

- **El mentor humano.** Claude acelera, no reemplaza. Las preguntas de "por qu&eacute;" y "c&oacute;mo decidimos esto" necesitan contexto de equipo que la IA no tiene.
- **La cultura de equipo.** Las din&aacute;micas de la Daily, la forma de comunicarse en PR, el estilo de los commits: eso se aprende conviviendo, no preguntando a un chatbot.
- **El juicio sobre qu&eacute; tarea asignar.** El mentor decide la secuencia de tareas del onboarding seg&uacute;n el perfil del nuevo miembro.

---

## 2. Cuestionario de evaluaci&oacute;n de expertise

### 2.1 Objetivo

Construir un perfil de competencias de cada programador para alimentar el algoritmo de asignaci&oacute;n de pm-workspace (`expertise &times; 0.40 + disponibilidad &times; 0.30 + balance &times; 0.20 + crecimiento &times; 0.10`), identificar necesidades de formaci&oacute;n y planificar mentoring.

### 2.2 Escala de evaluaci&oacute;n

Se usa una escala de 5 niveles inspirada en el modelo Shu-Ha-Ri (aprendiz, practicante, competente, experto, referente):

| Nivel | Nombre | Descripci&oacute;n operativa |
|-------|--------|---------------------------|
| 1 | **Aprendiz** | Conoce la teor&iacute;a b&aacute;sica. Necesita supervisi&oacute;n constante para producir c&oacute;digo. |
| 2 | **Practicante** | Puede trabajar con gu&iacute;a. Resuelve problemas conocidos siguiendo patrones establecidos. |
| 3 | **Competente** | Trabaja de forma aut&oacute;noma. Ocasionalmente consulta con un experto en casos complejos. |
| 4 | **Experto** | Resuelve problemas complejos, hace mentoring a otros, propone mejoras arquitect&oacute;nicas. |
| 5 | **Referente** | Dise&ntilde;a soluciones originales. Es la persona a quien el equipo acude para las decisiones m&aacute;s cr&iacute;ticas de esta &aacute;rea. |

Cada competencia se eval&uacute;a en dos dimensiones:

- **Nivel actual** (1-5): d&oacute;nde est&aacute; hoy.
- **Inter&eacute;s** (S&iacute;/No): si quiere desarrollar esta competencia. Esto alimenta el peso `growth` del algoritmo.

### 2.3 Formato del cuestionario

El cuestionario es de **autoevaluaci&oacute;n validada por el Tech Lead**. La persona se eval&uacute;a a s&iacute; misma, el Tech Lead revisa y ajusta si hay discrepancias significativas (&plusmn;2 niveles), y ambos firman el resultado. Esto combina honestidad con calibraci&oacute;n objetiva.

### 2.4 Secci&oacute;n A &mdash; Competencias t&eacute;cnicas .NET/C#

| # | Competencia | Evidencia verificable | Nivel (1-5) | Inter&eacute;s (S/N) |
|---|-------------|----------------------|-------------|------------------|
| A1 | **C# y OOP** &mdash; herencia, interfaces, genricos, LINQ, async/await | Puede escribir un QueryHandler as&iacute;ncrono con LINQ sin ayuda | ___ | ___ |
| A2 | **Clean Architecture** &mdash; capas Domain, Application, Infrastructure, API | Sabe en qu&eacute; capa va cada clase y por qu&eacute; | ___ | ___ |
| A3 | **CQRS y MediatR** &mdash; Commands, Queries, Handlers, Pipeline Behaviors | Puede crear un nuevo Command + Handler de cero | ___ | ___ |
| A4 | **Entity Framework Core** &mdash; DbContext, Fluent API, Migrations, Queries | Puede configurar una entidad con relaciones y escribir consultas eficientes | ___ | ___ |
| A5 | **FluentValidation** &mdash; Validators, reglas de negocio, mensajes custom | Puede crear un AbstractValidator completo para un DTO | ___ | ___ |
| A6 | **Unit Testing** &mdash; xUnit/NUnit, Moq/NSubstitute, AAA pattern | Puede escribir tests con mocks para un Handler sin ver ejemplos | ___ | ___ |
| A7 | **Integration Testing** &mdash; TestServer, TestContainers, fixtures | Puede montar un test que levante la API y haga requests reales | ___ | ___ |
| A8 | **API REST** &mdash; Controllers, routing, model binding, Swagger, versionado | Puede dise&ntilde;ar un endpoint RESTful con status codes correctos | ___ | ___ |
| A9 | **SQL y bases de datos** &mdash; T-SQL, &iacute;ndices, planes de ejecuci&oacute;n, migraciones | Puede optimizar una query lenta analizando el plan de ejecuci&oacute;n | ___ | ___ |
| A10 | **Seguridad** &mdash; autenticaci&oacute;n JWT, autorizaci&oacute;n basada en roles/pol&iacute;ticas, OWASP | Puede implementar un middleware de autorizaci&oacute;n | ___ | ___ |
| A11 | **Principios SOLID y Design Patterns** &mdash; DI, Repository, Factory, Strategy | Sabe identificar violaciones SOLID en code review | ___ | ___ |
| A12 | **CI/CD y DevOps b&aacute;sico** &mdash; Azure DevOps Pipelines, Docker, YAML | Puede leer y modificar un pipeline YAML existente | ___ | ___ |

### 2.5 Secci&oacute;n B &mdash; Competencias transversales

| # | Competencia | Evidencia verificable | Nivel (1-5) | Inter&eacute;s (S/N) |
|---|-------------|----------------------|-------------|------------------|
| B1 | **Git avanzado** &mdash; branching, rebase, cherry-pick, resoluci&oacute;n de conflictos | Puede resolver un merge conflict complejo sin perder c&oacute;digo | ___ | ___ |
| B2 | **Code Review** &mdash; dar y recibir feedback constructivo | Da reviews que mejoran el c&oacute;digo sin generar conflicto | ___ | ___ |
| B3 | **Documentaci&oacute;n t&eacute;cnica** &mdash; XML docs, READMEs, ADRs | Documenta sus decisiones t&eacute;cnicas por escrito | ___ | ___ |
| B4 | **Comunicaci&oacute;n con stakeholders** &mdash; explicar t&eacute;cnico a no-t&eacute;cnicos | Puede explicar un problema t&eacute;cnico al Product Owner | ___ | ___ |
| B5 | **Estimaci&oacute;n de esfuerzo** &mdash; Story Points, descomposici&oacute;n de tareas | Sus estimaciones se desv&iacute;an &lt;30% del real | ___ | ___ |
| B6 | **Mentoring** &mdash; capacidad de ense&ntilde;ar a otros | Ha guiado a un junior en una tarea completa | ___ | ___ |
| B7 | **Trabajo con IA** &mdash; Claude Code, Copilot, prompting efectivo | Usa IA como acelerador sin perder comprensi&oacute;n del c&oacute;digo | ___ | ___ |

### 2.6 Secci&oacute;n C &mdash; Conocimiento del dominio (por proyecto)

Esta secci&oacute;n se personaliza para cada proyecto. Ejemplo para un proyecto cl&iacute;nico:

| # | &Aacute;rea de dominio | Nivel (1-5) | Inter&eacute;s (S/N) |
|---|---------------------|-------------|------------------|
| C1 | M&oacute;dulo de Pacientes &mdash; entidades, reglas de negocio, flujos | ___ | ___ |
| C2 | M&oacute;dulo de Citas &mdash; reservas, cancelaciones, notificaciones | ___ | ___ |
| C3 | M&oacute;dulo de Facturaci&oacute;n &mdash; tarifas, seguros, cobros | ___ | ___ |
| C4 | Integraciones externas &mdash; APIs de terceros, pasarela de pago | ___ | ___ |

### 2.7 C&oacute;mo se transforma en datos para el algoritmo

El resultado del cuestionario se traduce al campo `expertise` del archivo `equipo.md` de cada proyecto:

```yaml
miembros:
  - nombre: "Laura S&aacute;nchez"
    role: "Full Stack"
    horas_dia: 7.5
    expertise:
      # Promedio ponderado de las competencias relevantes para cada m&oacute;dulo
      pacientes: 4.2    # Media de A1-A8 aplicadas al m&oacute;dulo Pacientes
      citas: 3.1        # Baja porque no ha trabajado este m&oacute;dulo a&uacute;n
      facturacion: 2.0   # &Aacute;rea de crecimiento identificada
      testing: 4.5       # A6 + A7 altos
    growth_areas: ["facturacion", "seguridad"]  # Derivado de Inter&eacute;s = S&iacute;
    ultima_evaluacion: "2026-02-26"
```

El algoritmo de asignaci&oacute;n usa `expertise[modulo]` como input directo para el factor `expertise &times; 0.40` del scoring, y `growth_areas` para el factor `crecimiento &times; 0.10`.

### 2.8 Frecuencia de actualizaci&oacute;n

- **Primera evaluaci&oacute;n:** al incorporarse (Fase 4 del onboarding).
- **Actualizaci&oacute;n trimestral:** autoevaluaci&oacute;n r&aacute;pida (&le;15 min, solo cambios).
- **Evaluaci&oacute;n completa anual:** revisi&oacute;n conjunta con Tech Lead.
- **Actualizaci&oacute;n puntual:** cuando alguien completa una formaci&oacute;n significativa o lidera un m&oacute;dulo nuevo.

---

## 3. Cumplimiento RGPD / LOPDGDD

### 3.1 Marco legal aplicable

Los datos de competencias de los programadores son **datos personales** seg&uacute;n el art&iacute;culo 4 del RGPD (Reglamento UE 2016/679) y est&aacute;n protegidos tanto por el RGPD como por la **LOPDGDD** (Ley Org&aacute;nica 3/2018 de Protecci&oacute;n de Datos Personales y Garant&iacute;a de Derechos Digitales).

### 3.2 Base legal: inter&eacute;s leg&iacute;timo del empleador (Art. 6.1.f RGPD)

La base legal para tratar datos de competencias es el **inter&eacute;s leg&iacute;timo del empleador** en organizar el trabajo de forma eficiente, no el consentimiento del trabajador. Razones:

1. **El consentimiento no es libre en relaciones laborales** &mdash; existe desequilibrio de poder (el trabajador puede sentir que negarse tiene consecuencias). Por eso el RGPD desaconseja el consentimiento como base en contexto laboral.
2. **El inter&eacute;s leg&iacute;timo** cubre la gesti&oacute;n y organizaci&oacute;n del trabajo, la asignaci&oacute;n de tareas seg&uacute;n capacidades, la planificaci&oacute;n de formaci&oacute;n y el desarrollo profesional.
3. **Se requiere una Evaluaci&oacute;n de Inter&eacute;s Leg&iacute;timo (LIA)** documentada ANTES de empezar a recoger datos.

**Evaluaci&oacute;n de inter&eacute;s leg&iacute;timo resumida:**

| Test | Resultado |
|------|-----------|
| **Prop&oacute;sito** | Asignar tareas de forma eficiente seg&uacute;n las capacidades reales del equipo, identificar necesidades formativas, planificar mentoring. |
| **Necesidad** | No existe alternativa menos intrusiva que capture la informaci&oacute;n necesaria para asignaci&oacute;n &oacute;ptima de trabajo. |
| **Ponderaci&oacute;n** | Los derechos del trabajador no se ven significativamente afectados porque: (a) los datos no son sensibles (Art. 9), (b) el trabajador tiene acceso y rectificaci&oacute;n, (c) los datos se usan exclusivamente para organizaci&oacute;n del trabajo, (d) se aplica minimizaci&oacute;n estricta. |

### 3.3 Principios de minimizaci&oacute;n (Art. 5.1.c RGPD + LOPDGDD)

La AEPD (Agencia Espa&ntilde;ola de Protecci&oacute;n de Datos) interpreta la minimizaci&oacute;n de forma estricta en contexto laboral. Solo se recogen:

| Se recoge | No se recoge |
|-----------|-------------|
| Competencias directamente relacionadas con las tareas del proyecto | Datos m&eacute;dicos, discapacidades, condiciones de salud |
| Nivel de competencia (escala 1-5) | Resultados de tests de personalidad o psicot&eacute;cnicos |
| Inter&eacute;s en &aacute;reas de crecimiento | Informaci&oacute;n financiera, salario, evaluaci&oacute;n de rendimiento num&eacute;rica |
| Fecha de &uacute;ltima evaluaci&oacute;n | Datos de navegaci&oacute;n, productividad por hora, m&eacute;tricas de c&oacute;digo individuales |

**Importante:** las m&eacute;tricas de productividad individual (l&iacute;neas de c&oacute;digo, commits/d&iacute;a, velocidad de cierre de tasks) **no se recogen como parte del perfil de competencias**. Estas m&eacute;tricas se usan solo a nivel de equipo (KPIs del sprint) y nunca se asocian a una persona individual.

### 3.4 Derechos del trabajador (Arts. 15-21 RGPD)

Cada trabajador tiene garantizados estos derechos sobre sus datos de competencias:

| Derecho | C&oacute;mo se ejerce | Plazo |
|---------|-------------------|-------|
| **Acceso** (Art. 15) | El trabajador puede pedir una copia de su perfil completo de competencias en cualquier momento. | 30 d&iacute;as naturales |
| **Rectificaci&oacute;n** (Art. 16) | Si el trabajador considera que un nivel est&aacute; mal evaluado, puede solicitar correcci&oacute;n. Se resuelve en reuni&oacute;n con el Tech Lead. | Sin demora indebida |
| **Supresi&oacute;n** (Art. 17) | Al finalizar la relaci&oacute;n laboral, los datos se eliminan salvo obligaci&oacute;n legal de conservaci&oacute;n (4 a&ntilde;os por legislaci&oacute;n laboral espa&ntilde;ola). | 30 d&iacute;as naturales |
| **Oposici&oacute;n** (Art. 21) | El trabajador puede oponerse al tratamiento. Se analiza caso a caso. Si la oposici&oacute;n es fundada, se deja de usar su perfil para asignaci&oacute;n autom&aacute;tica. | Sin demora indebida |
| **Portabilidad** (Art. 20) | El trabajador puede pedir sus datos en formato estructurado (YAML/JSON) para llevarlos a otro empleador. | 30 d&iacute;as naturales |

### 3.5 Transparencia obligatoria (Arts. 13-14 RGPD)

Antes de recoger ning&uacute;n dato de competencias, se entrega al trabajador una **nota informativa** que incluye:

1. **Responsable del tratamiento:** nombre de la empresa, datos de contacto, DPO si aplica.
2. **Finalidad:** "Asignaci&oacute;n &oacute;ptima de tareas seg&uacute;n competencias, identificaci&oacute;n de necesidades formativas y planificaci&oacute;n de mentoring."
3. **Base legal:** "Inter&eacute;s leg&iacute;timo del empleador en la organizaci&oacute;n eficiente del trabajo (Art. 6.1.f RGPD)."
4. **Datos recogidos:** competencias t&eacute;cnicas (escala 1-5), inter&eacute;s en &aacute;reas de crecimiento, fecha de evaluaci&oacute;n.
5. **Destinatarios:** Tech Lead del proyecto, PM/Scrum Master, sistema de asignaci&oacute;n pm-workspace.
6. **Conservaci&oacute;n:** durante la vigencia de la relaci&oacute;n laboral + 4 a&ntilde;os tras la finalizaci&oacute;n (obligaci&oacute;n legal laboral).
7. **Derechos:** acceso, rectificaci&oacute;n, supresi&oacute;n, oposici&oacute;n, portabilidad, reclamaci&oacute;n ante la AEPD (www.aepd.es).

**Formato:** lenguaje claro y sencillo. No enterrada en un contrato de 40 p&aacute;ginas. Se recomienda documento independiente de 1-2 p&aacute;ginas con acuse de recibo firmado.

### 3.6 Consideraciones de la Ley de IA de la UE (Reglamento UE 2024/1689)

El algoritmo de asignaci&oacute;n de pm-workspace (`expertise &times; 0.40 + disponibilidad &times; 0.30 + balance &times; 0.20 + crecimiento &times; 0.10`) es **determinista y transparente** (no es machine learning), lo que reduce significativamente las obligaciones bajo la Ley de IA. Sin embargo:

| Aspecto | Situaci&oacute;n | Acci&oacute;n requerida |
|---------|------------|---------------------|
| **Clasificaci&oacute;n de riesgo** | Si el algoritmo se usa como apoyo a la decisi&oacute;n humana (recomendaci&oacute;n, no decisi&oacute;n autom&aacute;tica), no es alto riesgo. | Mantener siempre la decisi&oacute;n final en el humano (PM/Scrum Master). |
| **Supervisi&oacute;n humana** | pm-workspace ya la tiene: Claude propone, el PM confirma. | Documentar que ninguna asignaci&oacute;n es autom&aacute;tica. |
| **Transparencia** | El trabajador debe saber que existe un algoritmo de scoring. | Incluir en la nota informativa: "Se utiliza un algoritmo de scoring basado en expertise, disponibilidad, balance de carga y crecimiento para proponer asignaciones de tareas. La decisi&oacute;n final es siempre del PM." |
| **No discriminaci&oacute;n** | El algoritmo no debe producir sesgos por g&eacute;nero, edad, origen, etc. | Auditar peri&oacute;dicamente que las asignaciones no presentan patrones discriminatorios. |

### 3.7 Derecho a la desconexi&oacute;n digital (Art. 88 LOPDGDD)

Las evaluaciones de competencias y el seguimiento de skills **solo se realizan en horario laboral**. No se env&iacute;an cuestionarios fuera de jornada ni se analiza actividad (commits, PRs) fuera del horario de trabajo para inferir competencias.

### 3.8 Medidas de seguridad

| Medida | Implementaci&oacute;n en pm-workspace |
|--------|--------------------------------------|
| **Control de acceso** | Solo Tech Lead y PM del proyecto acceden al perfil completo. Los compa&ntilde;eros no ven niveles individuales. |
| **Almacenamiento** | El archivo `equipo.md` est&aacute; en el directorio del proyecto, incluido en `.gitignore` (nunca se sube al repositorio p&uacute;blico). |
| **Cifrado** | El disco del equipo con los datos est&aacute; cifrado (BitLocker/FileVault). |
| **Retenci&oacute;n** | Datos activos mientras dure la relaci&oacute;n laboral. Archivado durante 4 a&ntilde;os tras la baja. Eliminaci&oacute;n definitiva despu&eacute;s. |
| **Incidentes** | Cualquier acceso no autorizado se reporta al DPO y a la AEPD en &le;72 horas si supone riesgo para los derechos del trabajador (Art. 33 RGPD). |

### 3.9 Checklist de cumplimiento antes de implementar

- [ ] Completar y documentar la Evaluaci&oacute;n de Inter&eacute;s Leg&iacute;timo (LIA)
- [ ] Redactar la nota informativa para los trabajadores
- [ ] Obtener acuse de recibo firmado de cada trabajador
- [ ] Verificar que equipo.md est&aacute; en .gitignore
- [ ] Designar qui&eacute;n tiene acceso a los datos (Tech Lead + PM)
- [ ] Establecer procedimiento para ejercicio de derechos ARCO-POL
- [ ] Incluir en el Registro de Actividades de Tratamiento (RAT) de la empresa
- [ ] Si hay comit&eacute; de empresa, informar a los representantes de los trabajadores
- [ ] Auditar trimestralmente que no hay datos excesivos
- [ ] Documentar que la asignaci&oacute;n de tareas es siempre decisi&oacute;n humana final

---

## 4. Resumen ejecutivo

### Onboarding
Proceso de 5 fases que reduce el ramp-up de 4-8 semanas a 5-10 d&iacute;as, usando Claude como acelerador y al mentor humano como validador. M&eacute;tricas verificables en cada fase. Compatible con el flujo SDD existente.

### Evaluaci&oacute;n de expertise
Cuestionario de autoevaluaci&oacute;n validada (19 competencias t&eacute;cnicas + 7 transversales + dominio por proyecto), con escala 1-5 y dimensi&oacute;n de inter&eacute;s. Se transforma directamente en el campo `expertise` del algoritmo de asignaci&oacute;n.

### Cumplimiento legal
Base legal: inter&eacute;s leg&iacute;timo (no consentimiento). Minimizaci&oacute;n estricta seg&uacute;n criterio AEPD. Transparencia obligatoria con nota informativa previa. Derechos ARCO-POL garantizados. Algoritmo determinista con decisi&oacute;n final humana. Datos en .gitignore, nunca en repo p&uacute;blico.

---

## 5. Fuentes consultadas

### Onboarding con IA
- Eesel Blog &mdash; "How to navigate any codebase with Claude Code" (2025)
- Stack Overflow Blog &mdash; "Developers with AI assistants need pair programming model" (2024)
- Marcel Moll &mdash; "Advice for Mentors: Teaching Juniors in the Age of AI" (2025)
- ShyftLabs &mdash; "AI Onboarding Chatbot reduces integration time by 80%" (2025)
- DEV Community &mdash; "AI-Assisted Development in 2026: Best Practices" (2026)
- Moxo &mdash; "How to measure AI onboarding success: ROI, key metrics & benchmarks" (2025)

### Evaluaci&oacute;n de competencias
- Management 3.0 &mdash; "Team Competency Matrix" (practice guide)
- Martin Fowler &mdash; "Shu Ha Ri" (Bliki)
- TeamMeter &mdash; "Skills Matrix Software" (2025)
- Vervoe &mdash; ".NET Developer Skills Assessment Test" (2025)
- Sujin Joseph &mdash; "Programmer Competency Matrix"
- Training Industry &mdash; "How to Create and Use a Skills Matrix in 5 Steps" (2024)

### Normativa de protecci&oacute;n de datos
- RGPD (Reglamento UE 2016/679) &mdash; Arts. 4, 5, 6, 13-17, 21, 33, 88
- LOPDGDD (Ley Org&aacute;nica 3/2018) &mdash; Arts. 87, 88, 89
- AEPD &mdash; "La protecci&oacute;n de datos en las relaciones laborales" (Gu&iacute;a 2021, actualizada 2023)
- GDPRhub &mdash; "Data Protection in Spain" (2025)
- ICO &mdash; "Legitimate Interests Assessment" (guidance)
- Reglamento UE 2024/1689 (Ley de Inteligencia Artificial) &mdash; Art. 6, Anexo III
