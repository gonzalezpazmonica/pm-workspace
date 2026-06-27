# Traffic Light (Semáforo) — Lógica de Cálculo

## Parámetros de Entrada

```python
def calcular_semaforo(datos_sprint, velocity_media, bloqueados):
    sp_completados = datos_sprint['sp_completados']
    sp_planificados = datos_sprint['sp_planificados']
    dias_restantes = datos_sprint['dias_restantes']
```

## Cálculos Intermedios

```python
ratio_velocity = sp_completados / velocity_media if velocity_media > 0 else 0
riesgo_tiempo = (sp_planificados - sp_completados) / (sp_planificados + 1)
```

## Reglas de Decisión

- **🔴 Rojo — Sprint en riesgo:**
  - bloqueados ≥ 2 OR
  - ratio_velocity < 0.70 (menos del 70% de velocity media)

- **🟡 Amarillo — Vigilar de cerca:**
  - bloqueados ≥ 1 OR
  - ratio_velocity < 0.90 (menos del 90% de velocity media) OR
  - riesgo_tiempo > 0.6 (más del 60% de puntos sin completar)

- **🟢 Verde — En buen camino:**
  - Ninguna de las anteriores

## Umbrales Configurables

```bash
VELOCITY_GREEN_THRESHOLD=0.90
VELOCITY_YELLOW_THRESHOLD=0.70
BLOCKED_ITEMS_RED_THRESHOLD=2
```
