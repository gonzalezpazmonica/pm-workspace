### Fixed
- `sam.py check` juzga la frescura del SAM por contenido (sha256 de cada fuente y grafo derivado), no por el commit de origen. `source_commit` queda como dato informativo: un squash merge ya no deja main STALE sin cambio de contenido (#1278, #1297). `model_revision` pasa a calcularse solo sobre contenido.
