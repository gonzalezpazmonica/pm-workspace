# Guía de Adopción — Skills de Dominio Profesional

> Para: equipos no técnicos que quieren usar Savia en su trabajo diario.
> Ref: SE-233 | Familias: professional-domain, org-intelligence

---

## Director Comercial / Jefe de Ventas

**Skills disponibles**: `sales-account-research`, `sales-objection-analyzer`, `sales-pipeline-analyst`, `sales-proposal-writer`

**Qué puedes pedirle a Savia en lenguaje natural**:

- Investigar una empresa antes de una reunión: quién compra, qué les preocupa, qué tienen
- Analizar por qué se están perdiendo oportunidades en el pipeline
- Preparar respuestas a objeciones frecuentes de un sector
- Redactar una propuesta comercial estructurada con valor diferencial

**Ejemplos de prompts reales**:
```
"Investiga a [Empresa X], sector retail, 200 empleados.
Necesito saber quién toma decisiones en compras de software,
cuáles son sus pain points actuales y si tiene competidores."

"Tenemos un 35% de cierre en propuestas. Analiza el pipeline de
los últimos 6 meses [pega el CSV] y dime dónde se pierden las oportunidades."

"Escríbeme una propuesta para [Empresa Y] que vende ropa online.
Nuestro producto es [descripción breve]. Presupuesto estimado: 15.000 €/año."
```

**Limitaciones**: Los datos de mercado son orientativos. Las propuestas requieren revisión antes de enviar. Savia no conoce tu CRM ni tus precios reales — dáselos en el prompt.

**Requiere revisión profesional**: Antes de enviar cualquier propuesta a cliente.

---

## Asesor Legal / Director Jurídico

**Skills disponibles**: `legal-compliance-checker`, `legal-contract-reviewer`, `legal-document-drafter`

**Qué puedes pedirle a Savia**:

- Revisar un contrato e identificar cláusulas de riesgo
- Verificar si un proceso cumple con el RGPD o la LOPD
- Redactar un borrador de contrato con artículos del CCom o ET

**Ejemplos de prompts reales**:
```
"Revisa este contrato de prestación de servicios [pega el texto].
Identifica cláusulas abusivas, lagunas en responsabilidad y plazos poco claros."

"¿Este procedimiento de videovigilancia cumple con el RGPD?
[describe el procedimiento: cámaras, retención, acceso, aviso a trabajadores]"

"Redacta un NDA para compartir información con un proveedor de IA.
Vigencia 2 años. Empresa española, derecho español aplicable."
```

**Limitaciones**: Los borradores son orientativos. Savia puede equivocarse en artículos o jurisprudencia reciente. Los outputs tienen disclaimers legales explícitos.

**Requiere revisión profesional**: SIEMPRE — todo output legal requiere validación por abogado colegiado antes de usar.

---

## Controller / Director de Control de Gestión

**Skills disponibles**: `controlling-kpi-analyst`, `controlling-management-report`, `controlling-variance-analyzer`

**Qué puedes pedirle a Savia**:

- Analizar KPIs y detectar anomalías o patrones preocupantes
- Generar un borrador del informe mensual de gestión
- Explicar desviaciones presupuestarias y proponer acciones

**Ejemplos de prompts reales**:
```
"Analiza estos KPIs del Q2 [pega la tabla].
¿Cuál es la métrica más preocupante? ¿Qué benchmark del sector aplica?"

"Genera el borrador del informe de gestión de mayo.
Datos: [pega resumen financiero]. Público: Consejo de Administración."

"Tenemos una desviación de +120.000 € en costes de personal vs presupuesto.
Causas conocidas: 2 contrataciones no previstas + horas extra Q1.
¿Qué análisis adicional necesito y qué acciones propones?"
```

**Limitaciones**: Savia no accede a tu ERP. Los datos deben proporcionarse en el prompt. Los informes requieren validación antes de distribuir.

**Requiere revisión profesional**: Antes de cualquier distribución externa del informe.

---

## Director Financiero / CFO

**Skills disponibles**: `finance-cash-flow-analyst`, `finance-financial-report-writer`, `finance-investment-analyst`

**Qué puedes pedirle a Savia**:

- Proyectar el flujo de caja con diferentes escenarios
- Redactar la memoria anual o notas a los estados financieros
- Calcular VAN, TIR y payback de una inversión

**Ejemplos de prompts reales**:
```
"Proyecta el flujo de caja para los próximos 6 meses.
Datos base: [ingresos medios, gastos fijos, pagos pendientes].
Escenarios: optimista (+15% ingresos), base, pesimista (-20%)."

"Calcula el VAN y TIR de esta inversión: desembolso inicial 200.000 €,
flujos anuales proyectados [lista de 5 años], tasa de descuento 8%."

"Redacta la nota de deudores de la memoria anual. Datos:
[saldo de clientes por antigüedad, provisiones constituidas, política de cobro]."
```

**Limitaciones**: Los modelos financieros contienen supuestos — Savia los explicitará. Los cálculos de TIR/VAN requieren validación de supuestos con el equipo.

**Requiere revisión profesional**: Toda memoria o informe financiero externo requiere revisión por auditor o economista.

---

## Responsable de RRHH / Director de Personas

**Skills disponibles**: `labour-document-drafter`, `labour-convention-analyzer`, `labour-conflict-resolver`, `labour-onboarding-offboarding`

**Qué puedes pedirle a Savia**:

- Redactar una carta de despido disciplinario con base en el ET
- Consultar qué dice el convenio sobre permisos o categorías
- Analizar un conflicto laboral y las opciones de resolución
- Generar el checklist de onboarding o el finiquito de una baja

**Ejemplos de prompts reales**:
```
"Redacta una carta de despido disciplinario.
Empleado: Juan García, Técnico Nivel 3, 5 años de antigüedad.
Hechos: falta injustificada el 15/06/2026, turno mañana, centro Madrid.
Convenio: Hostelería Madrid 2024."

"¿Cuántos días de permiso por matrimonio tiene un Administrativo Nivel 2
según el Convenio de Oficinas y Despachos de Madrid? [pega el artículo del convenio]"

"Un trabajador impugna su despido. Lleva 7 años, salario 28.000 €/año.
Tenemos papeleta SMAC para el 15/07. ¿Qué opciones tenemos y cuánto cuesta cada una?"

"Genera el checklist de onboarding para una incorporación el 01/07/2026.
Categoría: Comercial Junior. Contrato indefinido. Jornada completa."
```

**Limitaciones**: Savia puede equivocarse en artículos del ET o plazos específicos del convenio. Los borradores de cartas de despido son orientativos y deben ser validados antes de entregar al trabajador.

**Requiere revisión profesional**: SIEMPRE en documentos laborales — graduado social o abogado laboralista antes de cualquier uso.

---

## Notas comunes a todos los perfiles

1. **[DATO PENDIENTE]**: cuando Savia pone este marcador, necesita ese dato para completar el output. No lo inventa.
2. **Disclaimers**: los avisos al final de cada output son obligatorios y no pueden desactivarse para los dominios de alto riesgo.
3. **Fuentes autoritativas**: para legal y laboral, verifica siempre contra el BOE. Para financiero, contra los estados auditados.
4. **Datos sensibles**: no incluyas datos personales de empleados o clientes en los prompts más de lo estrictamente necesario.
