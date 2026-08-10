---
version_bump: patch
section: Fixed
---

### Added

- SE-324 Tabular Intelligence — Excel + deteccion relacional:
  - `tabular-profile.py` lee `.xlsx` via openpyxl (dependencia opcional): un
    perfil por hoja con su nombre, formulas leidas como valores calculados
    (`data_only=True`), y degradacion explicita "Excel no soportado en este
    entorno" si openpyxl falta.
  - Deteccion relacional determinista: multiples tablas (hojas de un Excel o
    varios ficheros) detectan columnas candidatas a clave compartida por
    coincidencia de nombre + solape de valores, con tope de muestreo (AC-2.4).
    Salida `relations` junto a `tables`; formato plano retrocompatible para
    tabla unica.
  - Hook `pre-llm-tabular-detect.sh` detecta rutas `.xlsx` en el prompt y
    sustituye por perfil estadistico.

### Fixed

- SE-324 correccion documental: `DOMAIN.md` ahora cita los tres modelos del
  articulo origen — TabFM (Google, junio 2026, hibrido TabPFN+TabICL), TabICL
  (Inria/SODA) y KumoRFM (Kumo.AI, adquirida por Nvidia en 2026-06) — y
  corrige la atribucion previa a "Kumo.AI/Snowflake".
