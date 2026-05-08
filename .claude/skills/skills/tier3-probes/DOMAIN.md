# Domain: Tier 3 Probes

> Feasibility-first engineering para champions Tier 3.
> Spec group: SE-028, SE-032, SE-033, SE-041, SE-061, SPEC-102/103/104

## Problema

Evaluar si un stack ML pesado (BERTopic, cross-encoder, memvid, Oumi training) cabe en el entorno antes de ejecutar `pip install` de ~200MB-2GB. Sin probe:
- Install falla a mitad y deja entorno inconsistente
- Disco se llena sin aviso
- Usuario descubre incompatibilidad Python tras descargar 500MB de modelos
- CI se bloquea en entornos con deps faltantes

## Solucion

Probe pre-install de 3 niveles:
1. **BLOCKED**: fallo critico, no usable ni instalando (Python < 3.10)
2. **NEEDS_INSTALL**: falta la dep pero es instalable (pip install X)
3. **VIABLE**: todo listo, proceder con Slice 2+

## Pattern establecido (6 probes Tier 3)

```
probe:
  1. check runtime (python3, pip3)
  2. check deps (import X 2>/dev/null)
  3. check disk
  4. optionally check heavy deps (browser, GPU)
  5. emit JSON with verdict + reasons
  6. exit 0|1|2 consistent
```

## Integracion con otros sistemas

| Consumer | Cuando usa probe |
|---|---|
| MCP opt-in template | Antes de activar MCP scrapling (SE-061 Slice 4) |
| `tier3-probes` CLI | Inventario rapido del entorno |
| Pre-CI check | Antes de ejecutar tests que requieren ML stack |
| `travel-pack` restore | Post-travel validation que entorno destino funciona |

## Tradeoffs del patron

**Pros**:
- Fail-fast antes de gastar tiempo/disco
- JSON estable para automatizacion
- Zero-install (probe funciona sin deps)
- Documentacion ejecutable (--json expone qué se chequea)

**Contras**:
- Cada champion necesita su probe (boilerplate repetido)
- No reemplaza `pip install --dry-run` (otro tipo de validacion)
- Puede dar falsos OK si dep instalada pero rota

## Roadmap probes futuros

- SE-042 voice training: probe CUDA/GPU availability
- SPEC-107 cognitive debt: probe spaCy + wordnet models
- Futuros champions Tier 3 deberian seguir este patron

## No reemplaza

- `pip install --dry-run` (resuelve dependency graph)
- `scripts/readiness-check.sh` (workspace broader health)
- `scripts/drift-check.sh` (documentation drift)
- SBOM generation (SE-056 python-sbom.sh)

## Metrica de exito

Adopcion: todos los Slice 1 de champions futuros siguen el patron.
Cobertura: al menos 90% de deps criticas cubiertas por algun probe.
Falso positivos: probe VIABLE pero install falla = <5% en muestreo trimestral.
