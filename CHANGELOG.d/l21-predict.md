---
version_bump: patch
section: Added
---

### Added

- **L21 Predicción asistida local (SE-342 S5)** — `tabular-profile.py predict`:
  - Modo `predict --target COL [--categorical] FILE`: entrena un modelo local
    clásico (GradientBoosting de scikit-learn, dependencia opcional) con
    semilla fija determinista, valida con cross-validation (KFold/Stratified)
    y reporta métricas JSON (accuracy / RMSE+R²) y top-5 features por
    importancia.
  - Validaciones previas deterministas: `--target` requerido, columna
    inexistente, dataset <50 filas, y degradación explícita si scikit-learn no
    está instalado (sin crasheo, sin egress).
  - Registra el artefacto en el catálogo L17 (best-effort) con lineage
    `trained_on` al dataset de origen.
  - Decisión de la hypothesis l21: se extiende la capa determinista SE-296 con
    sklearn clásico local (no se instalan TFMs), alineado con CRIT-001.
  - 5 tests BATS (validaciones + degradación).