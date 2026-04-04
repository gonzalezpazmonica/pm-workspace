# Cost Management — Dominio

## Por que existe esta skill

Los proyectos necesitan visibilidad financiera: cuanto se gasta, donde, y si el
presupuesto aguantara. Esta skill gestiona timesheets, presupuestos, forecasting
e invoicing con datos versionados en git y rates protegidos por gitignore.

## Conceptos de dominio

- **Timesheet JSONL**: registro inmutable de horas por usuario/tarea/proyecto con coste calculado
- **Ledger append-only**: libro contable por proyecto sin modificaciones retroactivas (solo adjustments)
- **EAC (Estimate at Completion)**: proyeccion del coste final basada en burn rate actual
- **Cost-per-SP**: coste total dividido por story points completados; metrica de eficiencia
- **Burn rate**: velocidad de gasto (coste/dia) para detectar desviaciones tempranas

## Reglas de negocio que implementa

- Billing Model (billing-model.md): esquema de rates, timesheets, budgets e invoices
- Cost Tracking (cost-tracking.md): ledger inmutable, alertas por umbral (50/75/90%)
- PII Sanitization (pii-sanitization.md): invoices sin datos personales, solo @handles

## Relacion con otras skills

- **Upstream**: sprint-management (proporciona SP completados para cost-per-SP)
- **Downstream**: executive-reporting (consume KPIs financieros para informes directivos)
- **Paralelo**: capacity-planning (ambas usan horas disponibles pero para fines distintos)

## Decisiones clave

- Rates gitignored: la informacion salarial nunca debe estar en repositorio publico
- Ledger inmutable: errores se corrigen con adjustments hacia adelante, no editando historial
- Forecasting basado en burn rate lineal: simple y predecible; suficiente para sprints de 2 semanas
