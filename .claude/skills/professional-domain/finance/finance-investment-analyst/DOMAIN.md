# finance-investment-analyst — Dominio

## Por qué existe esta skill

El análisis de inversiones requiere metodología consistente y supuestos explícitos. El error más frecuente es producir valoraciones que parecen precisas pero esconden supuestos implícitos que nadie ha validado. Esta skill fuerza la explicitación de todos los supuestos y la marcación de datos pendientes.

## Estructura Investment Memo (9 secciones)

| Sección | Contenido | Longitud orientativa |
|---|---|---|
| 1. Resumen ejecutivo | Oportunidad, importe, TIR, recomendación | 1 página |
| 2. Descripción de la inversión | Qué es, quién, dónde, por qué ahora | 1-2 páginas |
| 3. Análisis de mercado | TAM/SAM/SOM, competencia, tendencias | 1-2 páginas |
| 4. Modelo financiero | P&L proyectado, FCF, supuestos explícitos | 2-3 páginas |
| 5. Valoración | DCF, múltiplos, sensibilidades | 1-2 páginas |
| 6. Estructura de la operación | Precio, forma de pago, earn-out, garantías | 1 página |
| 7. Análisis de riesgos | Por categoría con probabilidad e impacto | 1-2 páginas |
| 8. Plan de salida / monetización | Horizonte, opciones, condiciones | 0,5-1 página |
| 9. Próximos pasos | DD pendiente, hitos, decisiones requeridas | 0,5 páginas |

## Metodología DCF

### Supuestos que SIEMPRE deben declararse explícitamente

```
WACC: [X%] — descomposición:
  - Ke (coste de fondos propios): [X%] — base: CAPM o dato de mercado
  - Kd (coste de deuda): [X%] — coste efectivo deuda financiera
  - E/(E+D): [X%] — ratio fondos propios sobre total capital
  - D/(E+D): [X%] — ratio deuda sobre total capital

g (tasa de crecimiento terminal): [X%]
  - Justificación: [inflación + crecimiento real esperado del sector]
  - Máximo razonable: WACC - 2% (si g > WACC, el modelo estalla)

Horizonte de proyección explícita: [n] años
Valor terminal: calculado como perpetuidad [FCF_n+1 / (WACC - g)]
```

### Señales de error en el DCF
- Valor terminal > 80% del valor total → proyección explícita insuficiente o g demasiado alta
- WACC < g → modelo matemáticamente inválido (valor terminal negativo o infinito)
- FCF proyectados crecen cada año sin explicación → supuesto implícito no validado

## Métricas de valoración: cuándo usar cada una

| Métrica | Fórmula | Cuándo usar | Rango "normal" orientativo |
|---|---|---|---|
| **VAN** | Σ(FCFt/(1+WACC)^t) - Inversión inicial | Siempre como métrica base | >0 = inversión crea valor |
| **IRR / TIR** | Tasa que hace VAN=0 | Comparar con coste de capital y otras inversiones | TIR > WACC = inversión válida |
| **Payback simple** | Inversión / FCF medio anual | Cuando liquidez es constraint clave | Depende de sector; <5 años típico |
| **Payback descontado** | Años hasta VAN acumulado = 0 | Versión más rigurosa del payback | Siempre mayor que payback simple |
| **MoM (Multiple on Money)** | Total distribuido / Total invertido | PE/VC y operaciones de capital | >2x en 5 años = buena inversión PE |
| **EV/EBITDA** | Enterprise Value / EBITDA | Adquisiciones; comparar con múltiplos sectoriales | 5-12x según sector |

## Tablas de sensibilidad

Para el DCF, siempre produce tabla 2D con:
- Eje X: WACC (base ±1pp, ±2pp → 5 columnas)
- Eje Y: g terminal (base ±0,5pp, ±1pp → 5 filas)

```
       WACC:    8%      9%      10%     11%     12%
g: 1%   |  [VAN] | [VAN] | [VAN] | [VAN] | [VAN] |
g: 2%   |  [VAN] | [VAN] | [VAN] | [VAN] | [VAN] |
g: 3%   |  [VAN] | [VAN] | [VAN] | [VAN] | [VAN] |
g: 4%   |  [VAN] | [VAN] | [VAN] | [VAN] | [VAN] |
g: 5%   |  [VAN] | [VAN] | [VAN] | [VAN] | [VAN] |
```

Adicionalmente: tabla de sensibilidad IRR vs crecimiento de ventas y margen EBITDA.

## Estructura de la operación

Elementos a cubrir en la sección 6:
- Precio total y forma de pago (upfront / earn-out / deuda asumida)
- Earn-out: base de cálculo, período, cap y floor, mecanismo de cálculo
- Garantías: declaraciones y garantías estándar, cap, basket, periodo
- Condiciones precedentes (CPs) al cierre
- Mecanismo de precio: locked-box vs completion accounts
- Ajustes de working capital al cierre

## Análisis de riesgos

Para cada riesgo identificado, estructura:
```
| Categoría | Riesgo | Probabilidad | Impacto | Score | Mitigación |
| Mercado | Pérdida cliente principal | Alta | Muy alto | 9 | Earn-out vinculado a retención |
```

Categorías estándar: mercado / operacional / financiero / legal-regulatorio / tecnológico / ESG / ejecución
