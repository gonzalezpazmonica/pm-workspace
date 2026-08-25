---
version_bump: minor
section: Security
---
- **SE-345 Mind Virus Defense**: nueva capa de protección contra instrucciones maliciosas que se persisten en memoria y se propagan entre agentes. Detector determinista local (`scripts/mind-virus/detect.py`), gates de escritura/carga (`mind-virus-write-gate.sh`, `mind-virus-load-gate.sh`), escaneo de superficies de memoria (`scan-memory.sh`) y cuarentena explícita (`quarantine.sh`). Advertencia canónica incorporada a los principios éticos. Corpus red-team con TP=100% / FP=0 y BATS 17/17.
- **Cross-audit `.opencode/` vs `.claude/`**: los agentes se comparan semánticamente (espejo de esquema convertido) y los nativos de `.opencode/` se tratan como legítimos (SE-220) — el audit pasa limpio sobre el workspace real.