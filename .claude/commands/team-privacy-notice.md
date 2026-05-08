---
name: team-privacy-notice
description: >
  Genera la nota informativa de protección de datos (Art. 13-14 RGPD) que debe
  entregarse al trabajador ANTES de recoger datos de competencias. Rellena la
  plantilla con los datos de la empresa y del trabajador.
---

# Generar Nota Informativa RGPD

**Trabajador:** $ARGUMENTS

> Uso: `/team-privacy-notice "Laura Sánchez" --project GestiónClínica`
>
> Este comando debe ejecutarse ANTES de `/team-evaluate`. La nota es obligatoria
> conforme al Art. 13 del RGPD.

---

## Protocolo

### 1. Leer la plantilla

Leer `.opencode/skills/team-onboarding/references/privacy-notice-template.md`.

### 2. Obtener datos de la empresa

Leer `CLAUDE.md` (raíz) para obtener:
- `AZURE_DEVOPS_ORG_URL` → nombre de la organización
- Cualquier constante de empresa definida

Si no hay datos suficientes de la empresa en CLAUDE.md, preguntar al usuario:
- Nombre de la empresa (razón social)
- CIF
- Dirección fiscal
- Email de contacto para protección de datos
- Nombre del DPO (si aplica)

**Guardar estos datos** en `CLAUDE.md` o `CLAUDE.local.md` para no volver a preguntar.

### 3. Rellenar la plantilla

Sustituir los placeholders de la plantilla:
- `[NOMBRE_EMPRESA]` → datos de la empresa
- `[DIRECCIÓN_FISCAL]` → dirección
- `[CIF]` → CIF
- `[EMAIL_CONTACTO]` → email de contacto
- `[NOMBRE_DPO]` / `[EMAIL_DPO]` → DPO o texto alternativo
- Nombre del trabajador y fecha actual

### 4. Guardar la nota

```bash
mkdir -p projects/{proyecto}/privacy
```

Guardar en: `projects/{proyecto}/privacy/{nombre}-nota-informativa-{fecha}.md`

Donde `{nombre}` es el nombre en kebab-case (ej: "laura-sanchez") y `{fecha}` es YYYY-MM-DD.

### 5. Presentar al usuario

Mostrar la nota generada y el checklist de entrega:

```
═══ NOTA INFORMATIVA RGPD GENERADA ═══

  📄 Archivo: projects/{proyecto}/privacy/{nombre}-nota-informativa-{fecha}.md

  Checklist de entrega:
  [ ] Imprimir la nota o enviarla por email al trabajador
  [ ] El trabajador lee y comprende el contenido
  [ ] El trabajador firma el acuse de recibo (sección 9 del documento)
  [ ] Archivar la copia firmada (física o digital con firma electrónica)

  ⚠️  IMPORTANTE: No ejecutar /team-evaluate hasta que el acuse
     de recibo esté firmado. Es un requisito legal (Art. 13 RGPD).

═══════════════════════════════════════
```

---

## Restricciones

- **Solo genera la nota** — no recoge datos de competencias (eso es `/team-evaluate`)
- **No solicita consentimiento** — la base legal es interés legítimo, no consentimiento. La nota INFORMA, no pide permiso
- **Si faltan datos de empresa**, preguntar al usuario antes de generar (no inventar)
- **Un archivo por trabajador** — no reutilizar notas entre trabajadores
- **Idioma:** español por defecto. Si se pasa `--lang en`, generar en inglés
