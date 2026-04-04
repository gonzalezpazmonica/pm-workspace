# Executive Reporting -- Dominio

## Por que existe esta skill

La direccion necesita visibilidad de progreso sin sumergirse en detalles tecnicos. Los informes manuales consumen horas y pierden consistencia. Esta skill genera PowerPoint y Word con formato corporativo, semaforos de estado y datos reales de Azure DevOps.

## Conceptos de dominio

- **Semaforo de estado**: logica tricolor (verde/amarillo/rojo) basada en ratio de velocity y bloqueos activos.
- **Informe multi-proyecto**: agregacion de sprints, velocity y riesgos de todos los proyectos activos.
- **Formato corporativo**: colores (#0078D4 azul, Calibri), estructura de diapositivas estandarizada.
- **KPIs ejecutivos**: velocity, completion rate, bloqueos, riesgos y roadmap consolidado.

## Reglas de negocio que implementa

- Velocity >=90% = verde, 70-89% = amarillo, <70% = rojo.
- Bloqueos >=2 fuerzan semaforo rojo independientemente de velocity.
- Confirmar destinatarios con el usuario antes de enviar por email (Graph API).
- Output en output/executive/ con formato YYYYMMDD-executive-report.{pptx|docx}.

## Relacion con otras skills

- **Upstream**: azure-devops-queries (datos de work items), sprint-management (estado del sprint).
- **Downstream**: envio por email (Graph API), publicacion en SharePoint.
- **Paralelo**: enterprise-analytics (metricas SPACE para dashboards internos vs informes ejecutivos).

## Decisiones clave

- PPTX + DOCX sobre PDF: editables por direccion si necesitan ajustar antes de presentar.
- Semaforo simple sobre scoring complejo: ejecutivos necesitan decision rapida, no numeros.
- Datos reales de Azure DevOps sobre estimaciones manuales: elimina sesgo de reporte.
