# SE-385 Feasibility Probe — LinkedIn Member Data Portability (2026-09-05)

Fuente primaria verificada HOY: learn.microsoft.com view=li-dma-data-portability-2026-08 (ms.date 2026-04-07).

## Verificado contra documentación vigente
- Producto **Member Data Portability API (Member)** por DMA; acceso vía developer portal solicitando el producto.
- La app debe usar la **Default Company page** específica del producto (no crear Company Page nueva).
- **Token**: OAuth Token Generator Tool del portal (NO flujo OAuth programático para este producto); scope `r_dma_portability_self_serve`; consentimiento del miembro.
- **Restricción geográfica**: solo miembros en **EEA + Suiza** pueden consentir/generar token. Operadora en España → elegible ✓.
- Datos: **Member Changelog API** (eventos, ventana 28 días) + **Member Snapshot API** (Account History, Articles, Posts históricos, point-in-time).

## Veredicto
**GO-PARTIAL para MVP1**: import manual (SUPPORTED ya implementado) + Snapshot/Changelog APIs viables tras crear app + token manual (MVP2). Publish: **NOT_GRANTED** — este producto no concede write; MVP3 requiere otro producto y gate L4.

## Compliance
Términos del producto DMA aceptados al solicitar acceso; conditions de almacenamiento/uso propias de esta familia — NO extrapolables a Marketing/Profile/Community Management (§23/24 SE-385). Documentation pin registrado (checked 2026-09-05).

## Próximos pasos (MVP2)
1. Crear app en developer portal con Default Company del producto.
2. Solicitar producto + aceptar T&C.
3. Generar token manual (scope r_dma_portability_self_serve).
4. Snapshot API fetch mínimo → mapear a SocialArtifact (mismo modelo del import).
