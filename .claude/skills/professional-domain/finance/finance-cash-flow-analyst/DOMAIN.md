# finance-cash-flow-analyst — Dominio

## Por qué existe esta skill

La tesorería es el oxígeno de la empresa. Una compañía rentable puede quebrar por problemas de liquidez. Esta skill aplica metodología de forecast de tesorería y análisis de ratios de liquidez para identificar períodos de riesgo con antelación suficiente para actuar.

## Metodología de cash flow forecast

### Horizonte por tamaño de empresa

| Tamaño | Horizonte mínimo | Frecuencia de actualización | Formato |
|---|---|---|---|
| Micro / Startup | 13 semanas (rolling) | Semanal | Semana a semana |
| PYME | 6 meses | Mensual | Mensual con detalle próximas 4 sem |
| Mediana | 12 meses | Mensual | Mensual + rolling 13 sem |
| Grande | 24 meses | Mensual | Anual con detalle mensual |

### Estructura de forecast 13 semanas

```
Semana:          S1    S2    S3    S4   ... S13
Saldo inicial:   [€]   [€]   ...
COBROS:
  Clientes pago inmediato   [€]
  Clientes 30 días          [€]
  Clientes 60 días          [€]
  Otros cobros              [€]
Total cobros:    [€]
PAGOS:
  Nóminas y SS              [€]   (días X de cada mes)
  Proveedores 30 días       [€]
  Proveedores 60 días       [€]
  IVA / IRPF / IS           [€]   (fechas exactas)
  Cuotas de préstamos       [€]
  Gastos fijos (alquiler, suministros) [€]
  CAPEX comprometido        [€]
Total pagos:     [€]
Flujo neto:      [€]
Saldo final:     [€]   ← comparar con mínimo operativo
Alerta:          [🔴/🟡/🟢]
```

**Mínimo operativo**: 2-4 semanas de gastos fijos como colchón de seguridad. Si el saldo cae por debajo: 🔴.

## Ratios de liquidez con fórmulas y umbrales

| Ratio | Fórmula exacta | Umbral crítico | Umbral de alerta | Referencia |
|---|---|---|---|---|
| **Liquidez corriente** | Activo corriente / Pasivo corriente | <1,0 | 1,0-1,2 | 1,5-2,0 saludable |
| **Liquidez ácida** | (Act. corriente - Inventarios) / Pasivo corriente | <0,7 | 0,7-0,9 | >1,0 buena |
| **Liquidez inmediata** | Tesorería / Pasivo corriente | <0,1 | 0,1-0,2 | >0,3 cómoda |
| **Cobertura de intereses** | EBIT / Gastos financieros | <1,5 | 1,5-2,5 | >3,0 sólida |
| **Ratio de cobertura deuda** | (EBITDA - CAPEX mant.) / Servicio deuda | <1,0 | 1,0-1,2 | >1,3 |

## Gestión del circulante (NOF)

### NOF (Necesidades Operativas de Fondos)
```
NOF = Clientes + Inventarios - Proveedores (operativos, sin financieros)
```
- NOF positivo: la empresa financia su circulante (necesita capital)
- NOF negativo: los proveedores financian a la empresa (ventaja competitiva de modelo)

### CCC (Cash Conversion Cycle)
```
CCC = DSO + DIO - DPO
```
Donde:
- DSO = (Saldo clientes / Ventas anuales) × 365
- DPO = (Saldo proveedores / Compras anuales) × 365
- DIO = (Inventario / Coste ventas) × 365

Reducir CCC 10 días en empresa con 10M€ ventas → libera ~270k€ de cash.

## Palancas de optimización de liquidez

| Palanca | Efecto | Complejidad | Plazo impacto |
|---|---|---|---|
| Anticipar cobros (factoring/confirming clientes) | Reduce DSO | Media | <30 días |
| Ampliar plazos de pago a proveedores | Aumenta DPO | Media | 30-60 días |
| Reducir inventario (gestión just-in-time) | Reduce DIO | Alta | 3-6 meses |
| Descuento pronto pago a clientes | Reduce DSO a coste | Baja | Inmediato |
| Línea de crédito revolving | Cubre picos sin vender activos | Baja | 2-4 semanas |
| Lease-back de activos | Libera cash de activos propios | Alta | 2-3 meses |
| Aplazar inversiones CAPEX no comprometidas | Evita salida de cash | Baja | Inmediato |

## Plazos legales de pago (Ley 3/2004, modificada por Ley 15/2010)

| Tipo de transacción | Plazo máximo legal | Penalización por morosidad |
|---|---|---|
| Empresa a empresa (general) | 60 días desde recepción factura | Interés legal del dinero + 8pp + costes cobro |
| Empresa a empresa (alimentación) | 30 días (perecederos) / 60 días (resto) | Ídem |
| AA.PP. a empresa | 30 días | Ídem |
| Empresa a empresa (acuerdo escrito) | Hasta 60 días (no ampliable salvo excepciones) | Pacto en contrario es nulo |

**Cláusula clave**: los pactos de aplazamiento superiores al máximo legal son nulos de pleno derecho. Señalar si el cliente tiene acuerdos de pago que excedan estos plazos.
