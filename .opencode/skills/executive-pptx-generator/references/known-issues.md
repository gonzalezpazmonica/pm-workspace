# Known Issues — MCP PPT y entorno

## MCP `ppt_*`

### Connector curvo no existe
`ppt_add_connector(connector_type="curved")` → `AttributeError: MSO_CONNECTOR_TYPE.CURVED`.

**Workaround**: rectángulos finos para simular flecha:
```python
ppt_add_shape(shape_type="rectangle",
    left=X, top=Y, width=0.5, height=0.04,
    fill_color=[255, 89, 13])
```

### SVG no soportado en `ppt_manage_image`
`ppt_manage_image(image_source="icon.svg")` → falla silenciosa o crash.

**Workaround**: convertir SVG a PNG antes:
```bash
rsvg-convert -w 128 -h 128 icon.svg -o icon.png
# o
python3 -c "import cairosvg; cairosvg.svg2png(url='icon.svg', output_width=128, write_to='icon.png')"
```

### MCP server se cuelga tras ~50 llamadas
Síntoma: timeouts crecientes, eventualmente no responde.

**Workaround**:
- `ppt_save_presentation` cada 2-3 slides.
- Si cuelga: cerrar sesión MCP, `ppt_open_presentation`, continuar.
- Mantener `presentation_id` estable (`{slug}-v1`).

### Aptos cae a Calibri en equipo destino
Si el equipo del cliente no tiene Aptos instalado, PowerPoint sustituye por Calibri.

**Mitigación**:
- Verificar antes de la demo qué fuente tiene el cliente.
- Calibri tiene métrica similar, no rompe layout drásticamente.
- Alternativa: embebir fuente en PPTX (Archivo → Opciones → Guardar → Incrustar fuentes).

## Entorno WSL Ubuntu

### `unzip` no disponible
```bash
unzip file.pptx  # command not found
```

**Workaround**:
```bash
python3 -c "import zipfile; zipfile.ZipFile('file.pptx').extractall('out/')"
```

### `pip install` rechaza por PEP 668
```
error: externally-managed-environment
```

**Workaround**:
```bash
pip install --break-system-packages PACKAGE
# o mejor, venv
python3 -m venv .venv && source .venv/bin/activate && pip install PACKAGE
```

## SVG `currentColor`

Iconos Tabler usan `stroke="currentColor"` que solo se resuelve en HTML. En PPTX no se pinta.

**Workaround**:
```python
import re
def colorize_svg(svg_text, color):
    if 'stroke="currentColor"' in svg_text:
        return svg_text.replace('stroke="currentColor"', f'stroke="{color}"')
    # Inyectar stroke en root <svg> si no existe
    return re.sub(r'(<svg[^>]*?)(\s*/?>)',
                  rf'\1 stroke="{color}"\2', svg_text, count=1)
```

## Tool `question` requisitos

`question(questions=[{...}])` requiere clave `question` (texto completo) en cada item, no solo `header`+`options`.

**Workaround**:
```python
question(questions=[{
    "question": "¿Pregunta completa aquí?",  # OBLIGATORIO
    "header": "Etiqueta corta",
    "options": [...]
}])
```

## OCR con notas manuscritas

### Surya vs TrOCR
- Surya: mejor para texto impreso + manuscrito limpio. Lento (~30s/imagen).
- TrOCR: rápido pero falla en manuscrito enrevesado.

**Pipeline robusto**: Surya primero, TrOCR como fallback. Validación humana siempre.

## Render PPTX a PNG (para autocrítica)

```bash
# Si LibreOffice disponible
libreoffice --headless --convert-to png file.pptx --outdir preview/

# Si solo Python
python3 -c "
from pptx import Presentation  # python-pptx
# No renderiza imágenes directamente — solo XML.
# Para preview real: usar libreoffice o pasar por PDF.
"
```

## Checkpointing pesado

Si la sesión se interrumpe a mitad de renderizar 11 slides:

1. `CHECKPOINT.md` debe registrar último slide completado.
2. Al retomar: `ppt_open_presentation` con el path actual.
3. Continuar desde slide N+1.
4. Nunca regenerar slides ya completados (re-trabajo caro).
