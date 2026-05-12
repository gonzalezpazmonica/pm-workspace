# Visual Pattern — Anatomía detallada

> Patrones extraídos del caso acme-corp (score ≥95). Cada layout descrito como receta MCP reproducible.

## Slide base 10×7.5"

```
Posiciones canónicas (inches):
  Título:        left=0.4  top=0.4  width=8.5  height=0.7
  Barra naranja: left=0.4  top=1.15 width=1.5  height=0.06
  Subtítulo:     left=0.4  top=1.25 width=8.5  height=0.5
  Logo cliente:  left=8.6  top=0.35 width=1.0  height=0.45
  Footer pag:    left=0.4  top=7.1  width=1.0  height=0.25
```

## Layout A — 3 cajas fila (pilares)

```
top=2.4  height=4.2  width=2.96
  Caja 1: left=0.5
  Caja 2: left=3.52
  Caja 3: left=6.54
  Gap: 0.06"

Interior caja:
  Icono naranja 0.8×0.8 centrado top
  Título 20pt navy bold centrado
  Cuerpo 12pt gris centrado, 3-5 líneas
  Fondo: #FDEFEA, borde: none
```

Usado en: slide 7 (3 frentes), slide 10 (3 principios).

## Layout B — 4 cajas 2×2

```
top=2.0  height=2.3  width=4.5
  Fila 1: left=0.5 / 5.0  top=2.0
  Fila 2: left=0.5 / 5.0  top=4.5
  Gap horizontal=0.0  Gap vertical=0.2
```

Usado en: slide 8 (caso acme-project 4 dimensiones).

## Layout C — 4 cajas fila + resumen

```
4 cajas:
  top=2.2  height=2.4  width=2.16
  left=0.5 / 2.78 / 5.06 / 7.34

Caja resumen abajo:
  top=4.9  height=1.3  width=9.0  left=0.5
  Fondo: #FDEFEA  Texto centrado bold 14pt navy
```

Usado en: slide 9 (4 piezas + cierre).

## Layout D — 7 cajas (Shield)

```
Fila 1 (4 cajas): top=2.0  height=2.0  width=2.16
  left=0.5 / 2.78 / 5.06 / 7.34
Fila 2 (3 cajas, centrada): top=4.3  height=2.0  width=2.16
  left=1.64 / 3.92 / 6.2
```

Usado en: slide 4 (7 capas Savia Shield).

## Layout E — Imagen + texto (portada/cierre)

```
Imagen: left=0  top=0  width=4.0  height=7.5
Texto:  left=4.4  top=0.6  width=5.4  height=6.5
```

Usado en: slide 1 (portada), slide 11 (cierre).

## Layout F — 2 columnas (comparativa)

```
Columna izq: left=0.4  width=4.5  top=1.8
Separador:   left=4.95 width=0.02 top=1.8  height=4.5  color=#E6EBF0
Columna der: left=5.05 width=4.5  top=1.8
```

Usado en: slide 5 (dos tribunales).

## Layout G — Pipeline (4 pasos)

```
4 cajas: top=2.4  height=1.7  width=2.1
  left=0.4 / 2.6 / 4.8 / 7.0
Flechas naranja entre cajas (workaround: rectángulo 0.1×0.1)

Caja resumen:
  top=4.4  height=0.9  width=9.16  left=0.4
```

Usado en: slide 6 (SDD pipeline).

## Espaciado interior cajas

- Padding interior: 0.15" todos lados
- Línea entre icono y título: gap 0.1"
- Línea entre título y cuerpo: gap 0.15"
- Texto siempre con `vertical_alignment=top` + padding superior 0.2"

## Reglas tipográficas

| Elemento | Tamaño | Estilo | Color |
|---|---|---|---|
| Título slide | 28pt | Aptos Display bold | navy `#001C34` |
| Subtítulo | 15pt | Aptos italic | gris `#3C5064` |
| Título caja | 20pt | Aptos Display bold | navy |
| Body caja | 12-14pt | Aptos regular | gris `#3C5064` |
| Callout | 15pt | Aptos italic bold | navy |
| Pie/numeración | 10pt | Aptos | gris `#788291` |

## Anti-patterns observados (v1 RECHAZADO)

- Título sin barra naranja → "flota", pierde anclaje visual.
- Cajas con borde → ensucia. Usar solo fondo marfil.
- Body 16pt+ → sensación de PPT de instituto. Bajar a 12-14pt.
- 5+ bullets por caja → ilegible. Máx 3.
- Icono mismo color que fondo → invisible.
