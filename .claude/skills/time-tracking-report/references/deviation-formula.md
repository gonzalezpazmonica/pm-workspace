# Fórmula de Desviaciones — Cálculo y Análisis

## Función: calcular_desviacion

```python
def calcular_desviacion(estimado, completado, restante):
    """
    Calcula la desviación respecto a la estimación original.
    
    Args:
        estimado: float — horas estimadas originales
        completado: float — horas completadas
        restante: float — horas restantes
    
    Returns:
        (desviacion_h, desviacion_pct) — tupla con desviación absoluta y porcentaje
    """
    total_real = completado + restante
    
    if estimado == 0:
        return None, None  # Sin estimación
    
    desviacion_h = total_real - estimado
    desviacion_pct = (desviacion_h / estimado) * 100
    
    return desviacion_h, desviacion_pct
```

## Interpretación de Resultados

- **Positivo** — Excede estimación (se invirtieron más horas de lo estimado)
  - Ejemplo: estimado=8, real=10 → desviación=+2h (+25%)
  - Indicador: 🔴 Red — revisar por qué se tardó más

- **Negativo** — Va mejor que estimado (se completó en menos tiempo)
  - Ejemplo: estimado=8, real=6 → desviación=-2h (-25%)
  - Indicador: 🟢 Green — buena estimación o mejor eficiencia

- **Cero** — Estimación exacta
  - Indicador: 🟡 Yellow — estimación acertada

## Cálculo por Item vs Agregado

Aplicar la fórmula para cada item individual y para los agregados por persona/actividad:

```python
# Para cada item
for item in items:
    dev_h, dev_pct = calcular_desviacion(
        item['estimado'], 
        item['completado'], 
        item['restante']
    )
    item['desviacion_h'] = dev_h
    item['desviacion_pct'] = dev_pct

# Para agregados por persona
for persona in report:
    total_est = sum(...)
    total_real = sum(...)
    dev_h, dev_pct = calcular_desviacion(total_est, total_completed, total_remaining)
```

## Casos Especiales

1. **Sin estimación (estimado=0)**
   - Devolver None para ambos valores
   - Marcar en reporte como "Sin estimar"
   - No incluir en análisis de desviaciones

2. **Completado > estimado pero restante=0**
   - Desviación positiva es normal (se invirtió más de lo estimado)
   - Indicador de riesgo bajo (al menos está completado)

3. **Restante > 0 y estimado < completado+restante**
   - Desviación significativa
   - Revisar si task necesita reestimación
