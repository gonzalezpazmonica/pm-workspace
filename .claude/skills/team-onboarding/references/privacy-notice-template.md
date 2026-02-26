# Nota Informativa sobre Protección de Datos — Evaluación de Competencias

> **Plantilla conforme al RGPD (Reglamento UE 2016/679) Arts. 13-14 y la LOPDGDD (Ley Orgánica 3/2018)**
>
> Rellenar los campos entre [corchetes] con los datos reales antes de entregar al trabajador.

---

## 1. Responsable del Tratamiento

**Empresa:** [NOMBRE_EMPRESA]
**Dirección:** [DIRECCIÓN_FISCAL]
**CIF:** [CIF]
**Contacto:** [EMAIL_CONTACTO]
**Delegado de Protección de Datos (DPO):** [NOMBRE_DPO] — [EMAIL_DPO]

*(Si la empresa no tiene DPO obligatorio, indicar: "La empresa no está obligada a designar DPO conforme al Art. 37 RGPD. El contacto para cuestiones de protección de datos es [EMAIL_CONTACTO].")*

---

## 2. Finalidad del Tratamiento

Sus datos de competencias profesionales serán tratados con las siguientes finalidades:

1. **Asignación óptima de tareas** — asignar las tareas del sprint a los miembros del equipo según sus competencias reales, maximizando la eficiencia y evitando sobrecarga.
2. **Identificación de necesidades formativas** — detectar áreas donde el trabajador podría beneficiarse de formación o mentoring para su desarrollo profesional.
3. **Planificación de mentoring** — facilitar la relación mentor-aprendiz asignando mentores con expertise complementario.

---

## 3. Base Legal del Tratamiento

El tratamiento se realiza al amparo del **interés legítimo del empleador** en la organización eficiente del trabajo, conforme al **Artículo 6.1.f) del RGPD**.

Se ha realizado una **Evaluación de Interés Legítimo (LIA)** que concluye que los derechos e intereses del trabajador no se ven significativamente afectados, dado que:
- Los datos no son de categoría especial (Art. 9 RGPD)
- El trabajador tiene derecho de acceso y rectificación en todo momento
- Los datos se usan exclusivamente para organización del trabajo
- Se aplica el principio de minimización estricta

---

## 4. Datos Recogidos

| Categoría | Datos específicos |
|-----------|------------------|
| Competencias técnicas | Nivel de dominio (escala 1-5) en 12 áreas técnicas .NET/C# |
| Competencias transversales | Nivel de dominio (escala 1-5) en 7 áreas (Git, Code Review, Documentación, Comunicación, Estimación, Mentoring, Trabajo con IA) |
| Conocimiento de dominio | Nivel de dominio (escala 1-5) en los módulos del proyecto |
| Interés de crecimiento | Indicación (Sí/No) de áreas donde desea desarrollarse |
| Fecha de evaluación | Fecha de la última evaluación de competencias |

**Datos que NO se recogen:** métricas de productividad individual (líneas de código, commits por día, velocidad de cierre de tareas), datos médicos, información financiera, resultados de tests de personalidad.

---

## 5. Destinatarios

Sus datos de competencias serán accesibles únicamente a:

- **Tech Lead del proyecto** — para calibración de la evaluación y asignación técnica
- **PM/Scrum Master del proyecto** — para planificación de sprint y asignación de tareas
- **Sistema pm-workspace** — herramienta interna de gestión que usa un algoritmo determinista (no inteligencia artificial) para proponer asignaciones de tareas

Sus datos de competencias **no se comunican** a terceros, clientes, ni a otros miembros del equipo. Los compañeros de equipo no tienen acceso a sus niveles individuales de competencia.

---

## 6. Uso de Algoritmo de Asignación

El sistema pm-workspace utiliza un **algoritmo de scoring determinista** (no basado en machine learning) para proponer asignaciones de tareas. La fórmula combina cuatro factores con pesos configurables:

- Expertise del trabajador en el módulo de la tarea (peso: 40%)
- Disponibilidad horaria en el sprint (peso: 30%)
- Balance de carga del equipo (peso: 20%)
- Interés de crecimiento profesional (peso: 10%)

**La decisión final de asignación es siempre del PM/Scrum Master.** El algoritmo genera una propuesta que el humano puede aceptar, modificar o rechazar.

---

## 7. Plazo de Conservación

- **Durante la relación laboral:** los datos se mantienen activos y se actualizan periódicamente (trimestral o anualmente).
- **Tras la finalización de la relación laboral:** los datos se conservan durante **4 años** conforme a las obligaciones de la legislación laboral española (Art. 4 del Estatuto de los Trabajadores en relación con plazos de prescripción). Transcurrido este plazo, se eliminan de forma definitiva.

---

## 8. Derechos del Trabajador

Usted tiene los siguientes derechos en relación con sus datos de competencias:

| Derecho | Descripción | Cómo ejercerlo |
|---------|-------------|----------------|
| **Acceso** (Art. 15 RGPD) | Obtener una copia de su perfil completo de competencias | Solicitar a [EMAIL_CONTACTO] |
| **Rectificación** (Art. 16 RGPD) | Corregir niveles de competencia que considere inexactos | Solicitar revisión al Tech Lead |
| **Supresión** (Art. 17 RGPD) | Eliminar sus datos cuando ya no sean necesarios | Solicitar a [EMAIL_CONTACTO] |
| **Oposición** (Art. 21 RGPD) | Oponerse al tratamiento de sus datos | Solicitar a [EMAIL_CONTACTO] |
| **Portabilidad** (Art. 20 RGPD) | Recibir sus datos en formato estructurado (YAML/JSON) | Solicitar a [EMAIL_CONTACTO] |
| **Reclamación** | Presentar reclamación ante la AEPD | www.aepd.es |

**Plazo de respuesta:** 30 días naturales desde la recepción de la solicitud.

---

## 9. Derecho a la Desconexión Digital

Conforme al **Artículo 88 de la LOPDGDD**, las evaluaciones de competencias y cualquier actividad relacionada con este tratamiento se realizan **exclusivamente en horario laboral**. No se enviarán cuestionarios ni se analizará actividad fuera de la jornada de trabajo.

---

## Acuse de Recibo

He leído y comprendo esta nota informativa sobre el tratamiento de mis datos de competencias profesionales. Conozco mis derechos y la forma de ejercerlos.

**Nombre del trabajador:** ___________________________________

**Firma:** ___________________________________

**Fecha:** ___________________________________

---

*Documento generado por pm-workspace — `/team:privacy-notice`*
*Este documento no constituye un contrato ni solicita consentimiento. Informa sobre un tratamiento basado en interés legítimo (Art. 6.1.f RGPD).*
