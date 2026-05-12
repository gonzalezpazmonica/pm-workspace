# Assets Pipeline — Paleta, logos, iconos, imágenes

## 1. Extraer paleta del PPTX cliente

```bash
python3 -c "
import zipfile, re, sys
z = zipfile.ZipFile('CLIENT.pptx')
theme = z.read('ppt/theme/theme1.xml').decode('utf-8','replace')
colors = re.findall(r'<a:srgbClr val=\"([0-9A-F]{6})\"', theme)
for c in colors[:12]: print(c)
"
```

Resultado típico: `#001C34` (dk1), `#FF590D` (dk2/accent), `#FDEFEA` (lt2), etc.

Persistir en `estetica-{cliente}.md` (tabla rol → hex).

## 2. Logo cliente

- Buscar SVG oficial (web cliente, Wikipedia, brand kit).
- Generar variantes: navy `#001C34`, white `#FFFFFF` (para fondos oscuros).
- Render PNG 400px con `rsvg-convert -w 400 logo.svg -o logo-navy.png` o `cairosvg`.
- **Nunca usar logo principal del cliente como logo de portada** (usurpación de marca). Solo esquina superior derecha como "presentado a [cliente]".

## 3. Iconos Tabler

Catálogo necesario (caso acme-corp):
`shield-lock, brain, database, plug-connected, file-text, gavel, refresh, scale, book-2, warning, users, building, bulb, chart-bar, check-circle, circle-check, layout-grid, network`

Pipeline:
1. Descargar SVG de `tabler-icons` (MIT).
2. Para cada color objetivo (navy/orange/white):
   - Reemplazar `stroke="currentColor"` con color literal.
   - Si no existe `stroke=`, inyectar en el primer `<svg>`.
3. Render PNG 128px.

```bash
# Ejemplo color injection (regex-safe)
python3 -c "
import re, sys
svg = open(sys.argv[1]).read()
color = sys.argv[2]
if 'stroke=\"currentColor\"' in svg:
    svg = svg.replace('stroke=\"currentColor\"', f'stroke=\"{color}\"')
elif 'stroke=' not in svg.split('>',1)[0]:
    svg = re.sub(r'(<svg[^>]*)', rf'\1 stroke=\"{color}\"', svg, count=1)
open(sys.argv[3], 'w').write(svg)
" icon.svg "#FF590D" icon-orange.svg
```

## 4. Imágenes stock

- Resolución mínima 1600px lado largo.
- Buscar en Unsplash, Pexels (licencia clara).
- Convención de nombre: `{tema}.jpg` — `datos-red.jpg`, `reunion-directiva.jpg`, etc.
- Para portada: foto con espacio negativo a la derecha (texto encaja ahí).

## 5. Fondo degradado opcional

```bash
# Generar gradiente marfil sutil 1920x1080
python3 -c "
from PIL import Image, ImageDraw
img = Image.new('RGB', (1920, 1080), '#FFFFFF')
draw = ImageDraw.Draw(img)
for y in range(1080):
    alpha = int(255 * (1 - y/1080) * 0.05)
    draw.line([(0,y),(1920,y)], fill=(253, 239, 234, alpha))
img.save('bg-gradient-marfil.png')
"
```

## 6. Estructura final de assets

```
meetings/{tema}/assets/
  logos/
    {cliente}-logo-navy.{svg,png}
    {cliente}-logo-white.{svg,png}
  icons/
    {nombre}.svg
    {nombre}-{color}.png   # navy, orange, white
  images/
    portada-{tema}.jpg
    {slide-narrativo}.jpg
    bg-gradient-marfil.png
```

## 7. Verificación pre-render

Antes de F2, verificar:
- [ ] Todos los iconos del guion existen en PNG.
- [ ] Logo cliente en navy y white.
- [ ] Imágenes stock con dimensiones >1600px.
- [ ] Paleta documentada en `estetica-{cliente}.md`.
