# Fórmulas de Capacidad — Cálculos Detallados

## Función: calcular_horas_disponibles

```python
def calcular_horas_disponibles(fecha_inicio, fecha_fin, 
                              dias_off_persona, dias_off_equipo, 
                              horas_dia, factor_foco):
    """
    Calcula las horas disponibles de una persona en un sprint.
    
    Args:
        fecha_inicio, fecha_fin: datetime
        dias_off_persona: list[(start, end)] vacaciones personales
        dias_off_equipo: list[(start, end)] festivos/vacaciones colectivas
        horas_dia: float (capacidad configurada en AzDO o TEAM_HOURS_PER_DAY)
        factor_foco: float (TEAM_FOCUS_FACTOR, típicamente 0.75)
    
    Returns:
        float: horas disponibles (máximo 0)
    """
    # Contar días hábiles (excluye sábados y domingos)
    dias_sprint = dias_habiles_entre(fecha_inicio, fecha_fin)
    
    # Unir y contar días off
    dias_off = union(dias_off_persona, dias_off_equipo)
    dias_disponibles = dias_sprint - len(dias_off)
    
    # Aplicar factor de foco
    horas_disponibles = dias_disponibles * horas_dia * factor_foco
    return max(0, horas_disponibles)
```

## Fórmula Resumida

```
horas_disponibles = (dias_habiles_sprint - dias_off) * horas_dia * factor_foco
```

## Ejemplo Numérico

Sprint de 2 semanas (10 días hábiles):
- Persona sin días off: 10 * 8 * 0.75 = 60 horas
- Persona con 1 día vacaciones: 9 * 8 * 0.75 = 54 horas
- Equipo con festivo (1 día): todos pierden 8 * 0.75 = 6 horas

## Función: calcular_utilizacion

```python
def calcular_utilizacion(remaining_work_persona, horas_disponibles):
    """
    Calcula el porcentaje de utilización.
    """
    if horas_disponibles == 0:
        return None  # Sin datos
    return (remaining_work_persona / horas_disponibles) * 100
```

## Umbrales de Alerta

```python
if utilizacion > 100:
    estado = "🔴 SOBRE-CARGADO — redistribuir trabajo"
elif utilizacion >= 85:
    estado = "🟡 AL LÍMITE — vigilar de cerca"
elif utilizacion >= 0:
    estado = "🟢 OK"
else:
    estado = "⚪ SIN DATOS — configurar en AzDO"
```

## Configuración

```bash
TEAM_HOURS_PER_DAY=8          # Ajustar por persona si varía
TEAM_FOCUS_FACTOR=0.75        # Factor foco (típico: 0.70-0.80)
WARNING_THRESHOLD=0.85        # Umbral amarillo
OVERLOAD_THRESHOLD=1.0        # Umbral rojo
```
