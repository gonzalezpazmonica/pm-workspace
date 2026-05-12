# MCP PPT Recipes — Slide por slide

> Funciones MCP usadas: `ppt_create_presentation`, `ppt_add_slide`, `ppt_add_shape`, `ppt_manage_text`, `ppt_manage_image`, `ppt_save_presentation`.

## Setup inicial

```
ppt_create_presentation(id="{slug}-v1")
ppt_save_presentation(file_path="...")  # Para crear el fichero base
```

## Receta: header de cualquier slide

```python
# 1. Slide en blanco
ppt_add_slide(layout_index=6)  # blank layout

# 2. Título
ppt_manage_text(operation="add", slide_index=N,
    left=0.4, top=0.4, width=8.5, height=0.7,
    text="Título afirmativo aquí.",
    font_name="Aptos Display", font_size=28, bold=True,
    color=[0, 28, 52])

# 3. Barra naranja debajo del título
ppt_add_shape(slide_index=N, shape_type="rectangle",
    left=0.4, top=1.15, width=1.5, height=0.06,
    fill_color=[255, 89, 13], line_color=[255, 89, 13])

# 4. Subtítulo italic
ppt_manage_text(operation="add", slide_index=N,
    left=0.4, top=1.25, width=8.5, height=0.5,
    text="Subtítulo en italic.",
    font_name="Aptos", font_size=15, italic=True,
    color=[60, 80, 100])

# 5. Logo cliente esquina sup-derecha
ppt_manage_image(slide_index=N, operation="add",
    image_source="assets/logos/cliente-logo-navy.png",
    left=8.6, top=0.35, width=1.0, height=0.45)
```

## Receta: caja marfil con icono+texto

```python
def add_pillar_box(slide_idx, left, top, width, height,
                   icon_path, title, body):
    # Fondo marfil
    ppt_add_shape(slide_index=slide_idx, shape_type="rectangle",
        left=left, top=top, width=width, height=height,
        fill_color=[253, 239, 234], line_color=[253, 239, 234])

    # Icono naranja centrado top
    icon_left = left + (width - 0.8) / 2
    ppt_manage_image(slide_index=slide_idx, operation="add",
        image_source=icon_path,
        left=icon_left, top=top+0.25, width=0.8, height=0.8)

    # Título caja
    ppt_manage_text(operation="add", slide_index=slide_idx,
        left=left+0.15, top=top+1.2, width=width-0.3, height=0.5,
        text=title, font_name="Aptos Display", font_size=20,
        bold=True, alignment="center", color=[0, 28, 52])

    # Body caja
    ppt_manage_text(operation="add", slide_index=slide_idx,
        left=left+0.2, top=top+1.85, width=width-0.4, height=height-2.0,
        text=body, font_name="Aptos", font_size=12,
        alignment="center", color=[60, 80, 100])
```

## Receta: callout marfil ancho

```python
ppt_add_shape(slide_index=N, shape_type="rectangle",
    left=0.4, top=6.4, width=9.16, height=0.9,
    fill_color=[253, 239, 234], line_color=[253, 239, 234])

ppt_manage_text(operation="add", slide_index=N,
    left=0.4, top=6.4, width=9.16, height=0.9,
    text="Frase de cierre afirmativa.",
    font_name="Aptos", font_size=15, italic=True, bold=True,
    alignment="center", vertical_alignment="middle",
    color=[0, 28, 52])
```

## Receta: pie de página (numeración)

```python
ppt_manage_text(operation="add", slide_index=N,
    left=0.4, top=7.15, width=1.0, height=0.25,
    text=f"{N+1} / {TOTAL}",
    font_name="Aptos", font_size=10,
    color=[120, 130, 145])
```

## Checkpoints

Cada 2-3 slides:
```python
ppt_save_presentation(file_path="...pptx")
```

Si el MCP server cae a mitad, se reabre con `ppt_open_presentation` y se continúa.

## Estimación de llamadas

| Slide tipo | Llamadas MCP |
|---|---:|
| Portada (imagen + texto) | 8-10 |
| Header + 3 cajas | 14-16 |
| Header + 4 cajas + callout | 18-20 |
| Slide pipeline | 20-22 |
| Cierre con firma | 10-12 |

**11 slides ≈ 170-200 llamadas MCP**. Planificar tiempo (1.5-3 h).

## Verificación post-render

```python
# Leer XML del PPTX y verificar shapes/textos
import zipfile, re
z = zipfile.ZipFile("output.pptx")
for slide in sorted(n for n in z.namelist() if "slides/slide" in n and n.endswith(".xml")):
    xml = z.read(slide).decode()
    texts = re.findall(r"<a:t>([^<]+)</a:t>", xml)
    print(slide, texts[:3])
```
