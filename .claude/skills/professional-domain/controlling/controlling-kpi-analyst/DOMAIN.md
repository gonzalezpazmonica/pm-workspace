# controlling-kpi-analyst — Dominio

## Por qué existe esta skill

Los KPIs son inútiles sin interpretación contextualizada. Un ROE del 12% puede ser excelente en un sector o catastrófico en otro. Esta skill aporta la capa de interpretación: fórmulas exactas, benchmarks por tipo de empresa, umbrales de alerta y detección de red flags en EEFF.

## KPIs por tipo de empresa

### Servicios profesionales (consultoría, asesoría, despachos)
| KPI | Fórmula | Umbral alerta | Benchmark orientativo |
|---|---|---|---|
| Margen bruto | (Ingresos - Costes directos) / Ingresos | <40% | 50-70% |
| Utilización (billable) | Horas facturables / Horas disponibles | <65% | 70-80% |
| Revenue per employee | Facturación / Nº empleados | <80k€/año | 100-150k€/año |
| EBITDA margin | EBITDA / Ventas | <10% | 15-25% |
| DSO | (Clientes / Ventas) × días | >90 días | 45-60 días |

### Industrial / Manufactura
| KPI | Fórmula | Umbral alerta | Benchmark orientativo |
|---|---|---|---|
| Margen bruto | (Ventas - COGS) / Ventas | <20% | 25-40% |
| OEE (Overall Equipment Effectiveness) | Disponibilidad × Rendimiento × Calidad | <60% | 75-85% |
| DIO | (Inventario / COGS) × días | >60 días | 30-45 días |
| EBITDA margin | EBITDA / Ventas | <8% | 12-20% |
| ROIC | NOPAT / Capital invertido | <WACC | >10% |

### SaaS / Software
| KPI | Fórmula | Umbral alerta | Benchmark orientativo |
|---|---|---|---|
| MRR Growth | (MRR mes - MRR mes-1) / MRR mes-1 | <5% mensual | 8-15% mensual |
| Churn rate | Clientes perdidos / Clientes inicio | >5% mensual | <2% mensual |
| CAC | Coste adquisición / Clientes nuevos | >12 meses LTV | LTV/CAC > 3x |
| NRR (Net Revenue Retention) | MRR fin / MRR inicio mismo cohorte | <90% | >110% |
| Gross margin | (MRR - Coste hosting/ops directo) / MRR | <60% | 70-85% |

## Ratios financieros con fórmulas exactas

### Rentabilidad
| Ratio | Fórmula exacta | Interpretación |
|---|---|---|
| **ROE** | Resultado neto / Fondos propios medios | Rentabilidad para el accionista |
| **ROA** | Resultado neto / Activo total medio | Eficiencia en uso de activos |
| **ROIC** | NOPAT / (Deuda financiera neta + Fondos propios) | Rentabilidad del capital invertido; comparar con WACC |
| **Margen EBITDA** | EBITDA / Ventas netas | Margen operativo antes de D&A |
| **Margen neto** | Resultado neto / Ventas netas | Rentabilidad después de todo |

### Liquidez
| Ratio | Fórmula exacta | Umbral crítico |
|---|---|---|
| **Liquidez general** | Activo corriente / Pasivo corriente | <1,0 → riesgo de insolvencia técnica |
| **Liquidez ácida** | (Activo corriente - Inventarios) / Pasivo corriente | <0,7 → alerta |
| **Liquidez inmediata** | Tesorería / Pasivo corriente | <0,1 → dependencia crítica de cobros |

### Endeudamiento
| Ratio | Fórmula exacta | Umbral de alerta |
|---|---|---|
| **Deuda neta / EBITDA** | (Deuda financiera - Caja) / EBITDA | >4x → dificultad de refinanciación |
| **Ratio de endeudamiento** | Deuda total / Fondos propios | >2x → apalancamiento elevado |
| **Cobertura de intereses** | EBIT / Gastos financieros | <2x → riesgo de covenant breach |

### Actividad y circulante
| Ratio | Fórmula exacta | Observación |
|---|---|---|
| **CCC** | DSO + DIO - DPO | Positivo = financiación necesaria; negativo = financiación de proveedores |
| **NOF / Ventas** | NOF / Ventas anualizadas | Mide intensidad de circulante; >25% es alto en servicios |
| **Rotación de activos** | Ventas / Activo total | Eficiencia en generación de ventas con activos |

## Umbrales de alerta y red flags en EEFF

### Señales de deterioro (nivel 1 — monitorear)
- DSO aumenta >5 días vs mes anterior
- Margen bruto cae >1 pp vs mes anterior sin causa identificada
- Caja neta decrece >20% en el mes
- DPO aumenta >10 días (posible stress de liquidez)

### Señales de riesgo (nivel 2 — acción)
- Deuda neta / EBITDA supera 3,5x
- Liquidez ácida < 0,8 por 2 meses consecutivos
- Churn rate > 3% mensual en SaaS
- NOF crecen >30% sin crecimiento de ventas equivalente

### Red flags estructurales (nivel 3 — alerta máxima)
- Resultado neto positivo con cash flow operativo negativo → posible problema de calidad del resultado
- Ventas crecen pero margen bruto cae → deterioro de mix o política de precios insostenible
- ROIC < WACC durante 3 trimestres → destrucción de valor
- Deuda neta / EBITDA > 5x → riesgo de incumplimiento de covenants bancarios
