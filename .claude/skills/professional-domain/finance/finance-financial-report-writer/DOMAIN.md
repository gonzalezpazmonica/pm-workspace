# finance-financial-report-writer — Dominio

## Por qué existe esta skill

El mismo conjunto de estados financieros requiere presentaciones radicalmente diferentes según la audiencia. Un banco busca cobertura de deuda y estabilidad; un inversor, retorno y escalabilidad; un regulador, cumplimiento y transparencia; la dirección, señales operativas y acciones. Esta skill domina las cuatro traducciones.

## Diferencias de tone y contenido por audiencia

### Inversores (equity)
- **Objetivo**: convencer de la solidez y el potencial de retorno
- **Qué priorizan**: crecimiento, márgenes, ROIC, posición competitiva, outlook
- **Qué evitan ver**: deterioro de márgenes sin explicación, concentración de clientes, deuda alta sin justificación
- **Tono**: confiado pero honesto; acknowledge risks y explain mitigations
- **Ratios prioritarios**: EV/EBITDA, P/E, crecimiento de ventas, margen EBITDA, FCF yield, ROIC
- **Red lines**: no proyectar sin base, no minimizar riesgos materiales

### Banco / Entidad financiera
- **Objetivo**: demostrar capacidad de repago y solidez del colateral
- **Qué priorizan**: cobertura de intereses, deuda neta/EBITDA, liquidez, CAPEX, estabilidad flujos
- **Qué evitan ver**: deterioro de cobertura, pérdida de clientes clave, deterioro de colateral
- **Tono**: conservador, estable, enfocado en downside protection
- **Ratios prioritarios**: Deuda neta/EBITDA, DSCR, liquidez corriente/ácida, cobertura intereses, LTV si hay colateral
- **Red lines**: nunca mostrar proyecciones optimistas sin base; usar escenario base y conservador

### Regulador (CNMV, Banco de España, AEPD...)
- **Objetivo**: demostrar cumplimiento normativo y transparencia
- **Qué priorizan**: completitud, exactitud, referencias normativas, trazabilidad
- **Qué evitan ver**: ambigüedad, omisiones, terminología imprecisa, proyecciones sin metodología explícita
- **Tono**: máxima formalidad, cero interpretaciones propias, referencia a normativa en cada afirmación
- **Ratios prioritarios**: los requeridos por la norma específica; no añadir otros sin indicar que son complementarios
- **Red lines**: NUNCA hacer interpretaciones propias; si hay duda, señalar que requiere criterio del organismo

### Dirección interna
- **Objetivo**: informar para la toma de decisiones operativas y estratégicas
- **Qué priorizan**: señales accionables, desviaciones vs plan, riesgos inminentes, próximas decisiones
- **Qué evitan ver**: información sin acción, exceso de detalle que oculta el mensaje
- **Tono**: directo, orientado a acción, sin adornos
- **Ratios prioritarios**: los KPIs del cuadro de mando de la empresa + desviaciones vs budget
- **Red lines**: cada cifra debe tener una acción o una conclusión asociada

## Ratios financieros clave con fórmulas exactas

### Rentabilidad
| Ratio | Fórmula | Audiencia principal |
|---|---|---|
| ROE | Resultado neto / Fondos propios medios | Inversores |
| ROIC | NOPAT / Capital invertido | Inversores, dirección |
| Margen EBITDA | EBITDA / Ventas netas | Todas |
| Margen neto | Resultado neto / Ventas netas | Inversores, dirección |
| FCF yield | FCF / Market cap (o FCF / EV) | Inversores |

### Endeudamiento y cobertura
| Ratio | Fórmula | Audiencia principal |
|---|---|---|
| Deuda neta / EBITDA | (Deuda fin. - Caja) / EBITDA | Banco, inversores |
| Cobertura intereses | EBIT / Gastos financieros | Banco |
| DSCR | (EBITDA - CAPEX mant.) / Servicio deuda total | Banco |
| LTV | Deuda / Valor activo colateral | Banco |

### Liquidez y circulante
| Ratio | Fórmula | Audiencia principal |
|---|---|---|
| Liquidez corriente | Activo corriente / Pasivo corriente | Banco |
| Liquidez ácida | (Ac. cte. - Inventarios) / Pasivo cte. | Banco |
| CCC | DSO + DIO - DPO | Dirección |
| NOF / Ventas | NOF / Ventas anualizadas | Dirección |

## Red flags por nivel de gravedad

### Nivel 1 — Monitorear (mencionar en el informe)
- Margen bruto cae >1pp vs año anterior sin causa identificada
- DSO aumenta >15 días vs año anterior
- Deuda neta / EBITDA supera 3x

### Nivel 2 — Riesgo significativo (destacar en executive summary)
- Resultado neto positivo con FCF operativo negativo (calidad del resultado cuestionable)
- Liquidez ácida < 0,8
- Cobertura de intereses < 2x
- Top 3 clientes > 60% de ventas (concentración)

### Nivel 3 — Alerta crítica (requiere disclosure prominente)
- Pérdidas recurrentes con deterioro de fondos propios
- Incumplimiento de covenants bancarios (o riesgo próximo de incumplimiento)
- ROIC < WACC durante 3+ trimestres (destrucción de valor)
- Going concern risk: caja < 3 meses de gastos fijos

## Gestión del circulante (perspectiva de informe financiero)

Al comentar el circulante en el informe:
1. Calcula y comenta NOF vs período anterior
2. Desglosa variación: ¿qué ha variado más, clientes, inventarios o proveedores?
3. Calcula CCC y su variación
4. Señala si la tendencia es estructural o puntual
5. Cuantifica el impacto en cash de la variación de NOF
