# Guía: Centro de Estudios (Savia School)

> Escenario: centro educativo (instituto, universidad, academia, bootcamp) que quiere gestionar proyectos de estudiantes, evaluaciones y seguimiento académico con Savia School.

---

## Tu centro

| Rol | Quién es | Qué usa |
|---|---|---|
| **Profesor/a** | Crea proyectos, evalúa, hace seguimiento | `/school-setup`, `/school-evaluate`, `/school-analytics` |
| **Estudiante** | Entrega proyectos, consulta progreso | `/school-submit`, `/school-progress`, `/school-portfolio` |
| **Coordinador/a** | Visión global del curso | `/school-analytics`, `/school-export` |

---

## Setup del centro (el profesor)

### 1. Instalar pm-workspace

```bash
git clone https://github.com/gonzalezpazmonica/pm-workspace.git ~/claude
```

### 2. Crear el aula

> "Savia, configura un aula para el curso de Desarrollo Web, 2º DAW"

```
/school-setup "IES Ejemplo" "2DAW-DesarrolloWeb"
```

Savia crea la estructura: carpetas por alumno, rúbricas, y plantillas de proyecto. Todo en Git, sin base de datos.

### 3. Matricular estudiantes

> "Savia, matricula a los alumnos del curso"

```
/school-enroll alumno01
/school-enroll alumno02
/school-enroll alumno03
```

Savia School usa **alias** en lugar de nombres reales. Los alias los elige el profesor y no contienen datos personales (cumplimiento RGPD). El mapeo alias ↔ identidad real se mantiene fuera del sistema, en los registros del centro.

### 4. Crear rúbricas de evaluación

> "Savia, crea una rúbrica para proyectos web"

```
/school-rubric create
```

Savia te guía para definir criterios (funcionalidad, diseño, código limpio, documentación, tests) con niveles y pesos.

---

## Día a día del profesor

### Asignar un proyecto

> "Savia, crea un proyecto de tienda online para alumno01"

```
/school-project alumno01 "tienda-online"
```

Savia crea la estructura del proyecto con: enunciado, criterios de evaluación, fecha de entrega, y espacio para la entrega del alumno.

### Recibir entregas

Los alumnos entregan con:

```
/school-submit alumno01 "tienda-online"
```

El profesor ve las entregas pendientes:

> "Savia, ¿quién ha entregado?"

### Evaluar

> "Savia, evalúa el proyecto tienda-online de alumno01"

```
/school-evaluate alumno01 "tienda-online"
```

Savia aplica la rúbrica definida. El profesor revisa, ajusta puntuaciones y añade comentarios. La evaluación se cifra con AES-256 (solo el profesor y el alumno pueden verla).

### Ver analíticas del curso

```
/school-analytics                    → Métricas globales del curso
/school-progress --class             → Progreso de todos los alumnos
```

---

## Día a día del estudiante

### Consultar proyectos asignados

> "Savia, ¿qué proyectos tengo?"

### Entregar un proyecto

> "Savia, entrego mi proyecto tienda-online"

```
/school-submit alumno01 "tienda-online"
```

### Ver mi progreso

```
/school-progress alumno01            → Notas y feedback
/school-portfolio alumno01           → Portfolio completo
```

### Consultar mi diario de aprendizaje

```
/school-diary alumno01               → Diario de progreso
```

---

## Privacidad y RGPD

Savia School cumple con RGPD para menores:

- **Art. 8**: Consentimiento parental para menores de 14 años (en España). El centro gestiona los consentimientos fuera del sistema.
- **Art. 15**: Derecho de acceso. `/school-portfolio` da acceso completo al alumno.
- **Art. 17**: Derecho al olvido. `/school-forget alumno01` borra todos los datos del alumno.
- **Evaluaciones cifradas**: AES-256-CBC, solo accesibles por profesor y alumno.
- **Sin PII en el repo**: solo alias, nunca nombres, DNIs ni emails.

---

## Exportación de datos

Al final del curso:

```
/school-export alumno01              → Exporta datos del alumno
/school-export --class               → Exporta todo el curso
```

Genera ficheros con evaluaciones, progreso y portfolio para los registros oficiales del centro.

---

## Casos de uso extendidos

### Bootcamp de programación

Savia School funciona especialmente bien para bootcamps:

- Proyectos cortos con entregas frecuentes
- Evaluación continua con rúbricas predefinidas
- Portfolio que el alumno puede mostrar a empleadores
- Analíticas de progreso para detectar alumnos en riesgo

### Universidad — TFG/TFM

Para trabajos de fin de grado/máster:

- Un solo proyecto por alumno, larga duración
- Hitos intermedios con `/school-project` por cada hito
- Diario de investigación con `/school-diary`
- Evaluación por tribunal aplicando rúbrica compartida

### Formación interna en empresa

Para cursos de formación corporativa:

- Alias = código de empleado (sin nombres)
- Proyectos prácticos evaluados con rúbrica
- Informe de competencias para RRHH con `/school-export`

---

## Tips

- Los alias deben ser consistentes y no revelar identidad (usa códigos, no iniciales)
- Haz `/school-analytics` semanalmente para detectar alumnos que se quedan atrás
- Las rúbricas se pueden reutilizar entre cursos con `/school-rubric edit`
- El repositorio Git actúa como registro histórico inmutable de evaluaciones
- Para grupos grandes (>30 alumnos), considera dividir en secciones con `/school-setup` separado
