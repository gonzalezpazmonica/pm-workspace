---
name: compliance-matrix
description: >
  Gestiona matriz de conformidad con estándares regulatorios (CE, FCC, UL, RoHS,
  ISO). Permite definir estándares, trackear estado de requisitos, vincular
  evidencia, identificar gaps y generar reportes de cumplimiento.
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Task
---

## Descripción

Comando para gestionar matrices de conformidad regulatoria del hardware. Almacena datos en `projects/{proyecto}/hardware/compliance/` y registra requerimientos, estado de cumplimiento y evidencia de certificación.

## Subcomandos

### standard
Define un estándar de conformidad regulatoria.

```bash
compliance-matrix standard <proyecto> --name=CE --description="Marcado CE Directiva 2014/30/UE" \
  --scope="EMC electromagnetic compatibility" --deadline=2026-06-30
```

Estándares soportados:
- CE (Comunidad Europea)
- FCC (USA)
- UL (Seguridad USA/Canadá)
- RoHS (Sustancias restringidas)
- ISO (normas internacionales)

### status
Muestra estado de conformidad por requisito.

```bash
compliance-matrix status <proyecto> --standard=CE
compliance-matrix status <proyecto> --filter=pending
```

Estados: pass, fail, pending, NA (no aplica).

### export
Genera reporte de matriz de conformidad.

```bash
compliance-matrix export <proyecto> --format=markdown
compliance-matrix export <proyecto> --format=docx --output=compliance.docx
```

### gap
Identifica requisitos sin evidencia o incumplidos.

```bash
compliance-matrix gap <proyecto> --standard=FCC
```

Retorna lista de gaps con acción recomendada.

### evidence
Vincula documento de evidencia a requisito de conformidad.

```bash
compliance-matrix evidence <proyecto> --req=CE-001 --file=test-report.pdf \
  --description="Prueba EMC realizada por laboratorio certificado"
```

## Estructura de almacenamiento

```json
{
  "proyecto": "smart-meter",
  "standards": [
    {
      "id": "CE",
      "name": "Marcado CE",
      "requirements": [
        {
          "id": "CE-001",
          "description": "Compatibilidad electromagnética",
          "status": "pending",
          "evidence_ref": null,
          "responsible": "maria@empresa.com",
          "deadline": "2026-06-30"
        }
      ]
    }
  ]
}
```

## Matriz de requisitos típicos

### CE Mark
- EMC (Electromagnetic Compatibility)
- Seguridad eléctrica (Low Voltage Directive)
- Eficiencia energética
- Restricción de sustancias (RoHS)

### FCC
- FCC Part 15B (radio emissions)
- EMI/EMC testing

### RoHS
- Prohibición de Pb, Cd, Hg, Cr(VI), PBB, PBDE
- Documentación de conformidad por componente

### ISO
- ISO 9001 (Quality)
- ISO 14001 (Environment)
- ISO 45001 (Occupational Health & Safety)

## Ejemplo de uso

Definir estándar CE: `compliance-matrix standard proyecto --name=CE`

Ver requisitos CE: `compliance-matrix status proyecto --standard=CE`

Vincular evidencia: `compliance-matrix evidence proyecto --req=CE-001 --file=test.pdf`

Generar reporte: `compliance-matrix export proyecto --format=markdown`

Identificar gaps: `compliance-matrix gap proyecto`
