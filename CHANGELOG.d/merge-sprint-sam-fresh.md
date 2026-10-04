### Fixed
- merge-sprint: el resync regenera y commitea el SAM hasta que `sam.py check` da FRESH. Antes, cuando el mapa de capacidades cambiaba en el mismo commit, el SAM nacía desfasado y la CI caía (#1276).
