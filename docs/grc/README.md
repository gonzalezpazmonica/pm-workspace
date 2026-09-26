# GRC Auditor — uso local

El agente `grc-auditor` prepara evaluaciones preliminares. El evaluador determinista lee un paquete JSON y evidencia local; no consulta sistemas externos ni emite certificados. Guarda los datos reales del cliente fuera del repositorio público.

## Preparar y ejecutar

1. Define alcance, propietario, sistemas, marcos y versión consultada en la fuente oficial.
2. Registra requisitos puntuales verificados y controles internos. Un mismo control puede asociarse a varios requisitos; comprueba cada equivalencia.
3. Guarda evidencia en ficheros locales y calcula SHA-256. Registra prueba de eficacia, verificador humano, alcance y vigencia. El campo `VERIFIED` debe reflejar una verificación real independiente del modelo.
4. Ejecuta `python3 scripts/grc-audit.py /ruta/privada/assessment.json --output /ruta/privada/result.json`.
5. Revisa personalmente el resultado y decide severidad, aplicabilidad, tratamiento, aceptación y cierre.

Ejemplo de paquete mínimo (el fichero y el hash son ilustrativos; hay que sustituirlos):

```json
{
  "scope": {"id": "test-project", "systems": ["app"], "owner": "control-owner"},
  "frameworks": [{"id": "ENS", "version": "RD 311/2022", "status": "current", "official_source": "https://www.boe.es/eli/es/rd/2022/05/03/311/con", "last_verified": "2026-09-26"}],
  "controls": [{"id": "GRC-IAM-001", "title": "Revisión de accesos", "system_scope": "app"}],
  "requirements": [{"id": "REQ-1", "framework": "ENS", "control": "GRC-IAM-001", "source_ref": "referencia exacta revisada por auditor", "applicability": "IN_SCOPE"}],
  "evidence": [{"id": "E-1", "title": "Prueba de acceso", "source": "proof.txt", "source_type": "test", "owner": "control-owner", "collected_at": "2026-09-20", "valid_from": "2026-09-01", "valid_until": "2026-12-31", "hash": "SHA256_REAL_DEL_ARCHIVO", "classification": "internal", "frameworks": ["ENS"], "controls": ["GRC-IAM-001"], "system_scope": ["app"], "trust_level": "HIGH", "verification_status": "VERIFIED", "test_result": "PASS"}]
}
```

## Fuentes oficiales para iniciar la verificación

Estas URL identifican fuentes, no constituyen un catálogo de requisitos ni garantizan vigencia futura:

- [ENS — RD 311/2022, BOE](https://www.boe.es/eli/es/rd/2022/05/03/311/con)
- [RGPD — Reglamento (UE) 2016/679, EUR-Lex](https://eur-lex.europa.eu/eli/reg/2016/679/oj)
- [NIS2 — Directiva (UE) 2022/2555, EUR-Lex](https://eur-lex.europa.eu/eli/dir/2022/2555/oj)
- [CRA — Reglamento (UE) 2024/2847, EUR-Lex](https://eur-lex.europa.eu/eli/reg/2024/2847/oj)
- [AI Act — Reglamento (UE) 2024/1689, EUR-Lex](https://eur-lex.europa.eu/eli/reg/2024/1689/oj)
- [ISO/IEC 27701:2025, ISO](https://www.iso.org/standard/27701)
- [ISO 22301:2019 y modificación 2024, ISO](https://www.iso.org/standard/75106.html)
- [NIST SSDF SP 800-218, NIST](https://csrc.nist.gov/pubs/sp/800/218/final)
- [CIS Controls v8.1, CIS](https://www.cisecurity.org/controls/v8-1)

Las normas ISO protegidas no se copian al repositorio. El estado de NIS2 en cada país, las guías CCN-STIC y las ediciones futuras se verifican en sus portales oficiales antes de concluir.
