---
version_bump: patch
section: Changed
---

### Changed (Shield NER — calibración de falsos positivos)

- `scripts/shield-ner-allowlist.txt` ampliado (+31 términos): palabras comunes y
  términos del workspace que `es_core_news_md` marcaba como PERSON/LOC/ORG sin
  serlo (Savia, I+D, ASIs, Valida, criterio, frónesis, Gartner, Deloitte,
  LeRobot, Unitree, MuJoCo, ROS2, sim2real, VLA…).
- Efecto: en destinos N1/N2 ya no bloquean textos técnicos/research legítimos.
  **Credenciales y personas reales siguen bloqueadas en N1/N2** (los nombres
  reales no van al allowlist; las citas de autor se escriben en N3/N4 local,
  donde el override n3n4_names las permite).
- 2 tests de integración nuevos (palabras comunes ALLOW + credencial BLOCK en
  N1/N2).
