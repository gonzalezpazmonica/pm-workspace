# Sales Account Research — Dominio y Conocimiento

## Por qué existe este skill

El 70% de los comerciales entran a una primera reunión sin haber investigado
suficientemente al cliente. El resultado: preguntas que demuestran que no han
hecho los deberes, propuesta de valor genérica, y pérdida de credibilidad en
los primeros 10 minutos. Este skill elimina ese problema con un protocolo
de research sistemático.

---

## Estructura del Account Brief

Un Account Brief completo tiene 6 secciones:

### 1. Snapshot de cuenta

| Campo | Descripción | Fuente típica |
|---|---|---|
| Nombre legal | Razón social oficial | Registro Mercantil, web |
| Sector CNAE | Clasificación de actividad | SABI, Axesor, web |
| Tamaño | Empleados estimados (rango) | LinkedIn, informes |
| Facturación | Rango si disponible | SABI, memoria anual |
| Presencia geográfica | Oficinas, plantas, mercados | Web corporativa |
| Estructura de capital | Familiar, fondo, cotizada... | Registro, prensa |
| Fase de negocio | Crecimiento, consolidación, reestructuración | Noticias recientes |

**REGLA**: Si no hay dato verificable, usar `[DATO PENDIENTE]`. Nunca inventar.

### 2. Situación tecnológica visible

Inferida de señales públicas:
- Ofertas de empleo activas → qué tecnologías buscan
- Stack mencionado en web o blog técnico
- Tecnologías detectables (BuiltWith, Wappalyzer para web)
- Menciones a proveedores en comunicados de prensa

### 3. Pain probable

Derivado de:
- Sector + tamaño → problemas estructurales típicos del segmento
- Fase de negocio → necesidades propias de ese momento
- Señales de cambio → nuevas contrataciones, expansión, cambio de liderazgo

Formato de pain: `[Categoría]: [Descripción específica del problema]`
Con `probabilidad: ALTA / MEDIA / BAJA` basada en las señales disponibles.

### 4. Stakeholders iniciales para esta tipología de compra

Roles típicos por tipo de compra (adaptar al contexto):

| Tipo de compra | Economic Buyer | Champion | Technical Buyer |
|---|---|---|---|
| Software B2B | CEO / CFO | Head of Operations | CTO / IT Manager |
| Consultoría | Gerente General | Director afectado | — |
| Infraestructura IT | CFO | IT Director | Arquitecto / SysAdmin |
| RRHH / Formación | CHRO | HR Manager | — |
| Marketing tech | CMO | Digital Marketing Manager | IT |

### 5. Contexto competitivo

Competidores probables: basarse en el sector y la tipología del cliente, no inventar.
Si no se sabe quién compite, documentarlo como `[COMPETIDORES DESCONOCIDOS — preguntar en reunión]`.

Preguntas a formular en reunión para descubrir el contexto competitivo:
- "¿Con qué solución están trabajando ahora?"
- "¿Han evaluado alternativas recientemente?"
- "¿Qué os hizo querer buscar algo diferente?"

---

## Metodología MEDDIC en el contexto del research

MEDDIC es un framework de calificación de oportunidades. En el Account Brief,
se usa para identificar qué información falta antes de la primera reunión:

| Criterio | Descripción | ¿Disponible pre-reunión? |
|---|---|---|
| **M**etrics | Métricas de éxito del cliente | Rara vez |
| **E**conomic Buyer | Quién firma el presupuesto | Parcialmente (LinkedIn) |
| **D**ecision Criteria | Qué evalúan para elegir | No hasta calificación |
| **D**ecision Process | Cómo toman la decisión | No hasta calificación |
| **I**dentify Pain | Problema concreto que se resuelve | Parcialmente (inferido) |
| **C**hampion | Quién nos defiende internamente | No hasta primera reunión |

El Account Brief pre-reunión cubre parcialmente **E** e **I**. El resto se
completa durante el proceso de calificación.

---

## Errores frecuentes de IA en research de ventas

### Error 1: Inventar datos financieros

La IA puede generar cifras de facturación o empleados que suenan plausibles
pero son incorrectas. Regla: si no hay fuente verificable, usar `[DATO PENDIENTE]`.

### Error 2: Confundir empresas con nombre similar

Especialmente en grupos empresariales. Verificar siempre la razón social exacta
y el CIF/NIF antes de cualquier cifra.

### Error 3: Señales de cargo desactualizadas

LinkedIn muestra cargos que pueden tener 6-12 meses de antigüedad. Verificar
con la web corporativa antes de asumir que alguien sigue en ese rol.

### Error 4: Generalizar el sector sin adaptar al tamaño

Una empresa de 20 empleados en logística tiene problemas completamente diferentes
a una de 2.000 en el mismo sector. El tamaño y la fase importan más que el sector.

### Error 5: Pain genérico de catálogo

"Necesitan mejorar la eficiencia operativa" aplica a todas las empresas.
Un pain útil es específico: "Gestión manual de albaranes en almacén → errores
de facturación 2-3% → conflictos con clientes 40h/mes de gestión".

---

## Fuentes recomendadas por tipo de información

| Tipo de info | Fuentes recomendadas |
|---|---|
| Datos financieros ES | SABI, Axesor, Registro Mercantil, CNMV (si cotiza) |
| Estructura organización | LinkedIn, web corporativa (equipo directivo) |
| Tecnología | BuiltWith, LinkedIn (ofertas empleo), press releases |
| Noticias recientes | Google Noticias, Expansión, El Economista, web propia |
| Competidores | G2, Capterra, búsqueda "[sector] software España" |
| Contexto de deal | Notas CRM, emails previos, presentaciones del cliente |
