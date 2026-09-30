---
version_bump: patch
section: Fixed
---

### Fixed

- SE-420: una nota cuyo nivel de confidencialidad supera el de su cúpula ya no se sirve por ninguna herramienta de SaviaVaults: lectura, lista, búsqueda, etiquetas, grafo, consultas, enlaces, A2A y RAG. Antes solo RAG la ocultaba y un lector de la cúpula podía leerla entera con `vault_read`. `vault_write` rechaza crear o pisar notas así, y `vault_stats` avisa de cuántas hay (`outOfLevel`). Coste medido con 1.000 notas: listar pasa de ~1 a ~4 ms.
