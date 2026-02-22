# Reglas de Negocio — Proyecto Beta

> Reglas específicas de Proyecto Beta. Complementan las globales de `docs/reglas-negocio.md`.

## Constantes Específicas

```
TIPO_CONTRATO           = "Precio fijo"
PRESUPUESTO_TOTAL_H     = 1200
ALERTA_PRESUPUESTO_H    = 150          # alertar cuando queden menos de 150h
CAMBIO_ALCANCE_REQUIERE = "Change Request firmado por cliente + PM + Dirección"
```

---

## 1. Reglas del Dominio

> Añadir reglas de negocio del sistema en desarrollo.

### 1.1 [Módulo principal]
- [Regla de negocio 1]
- [Regla de negocio 2]

---

## 2. Reglas Especiales por Tipo de Contrato (Precio Fijo)

- **Scope freeze:** El alcance se considera cerrado. Todo cambio genera un Change Request
- **Monitorización semanal:** Revisar horas consumidas cada viernes. Si se proyecta superar el presupuesto → escalar inmediatamente
- **Fórmula de riesgo:**
  ```
  horas_restantes_presupuesto = PRESUPUESTO_TOTAL_H - HORAS_CONSUMIDAS
  horas_restantes_estimadas = SP_PENDIENTES × SP_RATIO_HORAS
  margen = horas_restantes_presupuesto - horas_restantes_estimadas
  # Si margen < ALERTA_PRESUPUESTO_H → alerta roja
  ```
- **Sin overtime:** Las horas extra no se facturan al cliente; impactan al margen del proyecto

---

## 3. Hitos y Entregables

| Hito | Fecha | Descripción | % Pago |
|------|-------|-------------|--------|
| Arranque | 2026-02-02 | Firma contrato + kick-off | 20% |
| Entrega 1 | 2026-04-15 | [Entregable 1] | 30% |
| Entrega 2 | 2026-06-15 | [Entregable 2] | 30% |
| Cierre | 2026-07-31 | Entrega final + aceptación | 20% |

---

## 4. Criterios de Aceptación del Cliente

- El cliente tiene 5 días hábiles para validar cada entregable
- Si no hay respuesta en 5 días → se considera aceptado (según contrato)
- Los bugs encontrados en el período de aceptación son gratuitos; los posteriores, no
- Documentar siempre el proceso de aceptación con email firmado o acta
