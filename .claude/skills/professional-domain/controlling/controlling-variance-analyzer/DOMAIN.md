# controlling-variance-analyzer — Dominio

## Por qué existe esta skill

El análisis de desviaciones es la herramienta central del control de gestión. Sin metodología sistemática, las reuniones de seguimiento se convierten en debates sobre si los datos son correctos en lugar de debates sobre acciones. Esta skill aplica una metodología estándar con convenciones de signo claras y tipología de desviaciones para producir análisis accionables.

## Metodología de análisis de desviaciones

### Los 5 tipos de desviación

| Tipo | Definición | Fórmula | Ejemplo |
|---|---|---|---|
| **Volumen** | Más/menos unidades de las previstas | (Real uds - Budget uds) × Precio budget | Vendimos 10% más unidades |
| **Precio** | Precio unitario diferente al previsto | (Precio real - Precio budget) × Real uds | Descuento medio mayor al presupuestado |
| **Mix** | Cambio en la composición del negocio | Diferencia de margen por composición de ventas | Más ventas de producto bajo margen |
| **Eficiencia** | Productividad diferente a la prevista | (Coste unitario real - Coste unitario budget) × Output real | Mayor consumo de horas por unidad |
| **Calendario** | Diferencias por timing de ingresos/gastos | Efecto temporal puro (reversible en siguientes meses) | Facturación desplazada al mes siguiente |

### Convención de signo (crítica para no ambigüedad)

**INGRESOS**: desviación positiva = favorable (más ingresos de lo previsto)
**GASTOS**: desviación positiva = DESFAVORABLE (más gasto de lo previsto)
**MARGEN**: desviación positiva = favorable

Esta convención debe declararse siempre al inicio del informe. Si el usuario usa convención diferente, señalarlo y trabajar con la suya indicándolo.

## Umbrales de materialidad por tamaño de empresa

| Tamaño empresa (facturación) | Umbral € | Umbral % | Criterio a aplicar |
|---|---|---|---|
| Micro (<2M€) | 10.000€ | 5% | El mayor de los dos |
| Pequeña (2-10M€) | 50.000€ | 5% | El mayor de los dos |
| Mediana (10-50M€) | 200.000€ | 3% | El mayor de los dos |
| Grande (>50M€) | 500.000€ | 2% | El mayor de los dos |

Si el usuario no especifica tamaño, usa umbral de empresa pequeña y decláralo.

## Semáforo RAG para desviaciones

| Color | Criterio | Acción requerida |
|---|---|---|
| 🔴 Rojo | Desviación desfavorable >umbral Y tendencia negativa sostenida | Acción inmediata + escalado dirección |
| 🟡 Amarillo | Desviación desfavorable >umbral O desviación favorable con riesgo de reversión | Seguimiento reforzado + plan de acción |
| 🟢 Verde | Dentro de umbral en ambas direcciones | Monitoreo estándar |
| 🔵 Azul | Desviación favorable significativa | Analizar si sostenible o efecto calendario |

## Cómo presentar a dirección

### Estructura de narrativa para cada desviación material

```
PARTIDA: [nombre]
Real: [€] | Budget: [€] | Desviación: [€] ([%]) — [🔴/🟡/🟢/🔵]
Tipo de desviación: [volumen / precio / mix / eficiencia / calendario]
Causa principal: [descripción en 1-2 frases, sin tecnicismos innecesarios]
Impacto cuantificado: [€] [favorable/desfavorable] sobre el resultado
Acción correctora: [qué, quién, cuándo]
```

### Errores a evitar en la narrativa

- "Los costes han aumentado" → debe decir: "Los costes de personal aumentaron 180k€ (+8%) por [causa]"
- "Las ventas fueron menores" → debe decir: "Las ventas cayeron 250k€ (-12%) por reducción de volumen (-15%) parcialmente compensada por precio (+3%)"
- Presentar desviación sin causa → siempre debe haber una hipótesis de causa aunque sea provisional

## Análisis de desviaciones encadenadas (waterfall)

Para presentaciones al consejo, usa formato waterfall:
```
Budget EBITDA: [X€]
± Desviación volumen: [±€]
± Desviación precio: [±€]
± Desviación mix: [±€]
± Desviación eficiencia: [±€]
± Desviación calendario: [±€]
= EBITDA real: [Y€]
Desviación total: [Z€] ([%])
```
