---
version_bump: patch
section: Security
---

### Security

- SE-414: Savia Files resiste bombas de descompresión (un DOCX de 1 MB que se expandía a 414 MB se rechaza en 3 ms), limita los workers de extracción a uno por proceso (4,5 GB → 1,15 GB con 4 subidas simultáneas), rechaza nombres con caracteres invisibles o bidi, liga el texto extraído a su revisión por digest y resuelve symlinks antes de comprobar que el almacén (y el índice RAG) no está dentro de git. Un manifiesto por documento, con migración automática, baja guardar + extraer de 49,6 a 2,2 ms por documento con 3000 en la cúpula y evita que uno corrupto inutilice la cúpula.
