#!/usr/bin/env python3
"""
import_sprint_story.py — Extrae el historial completo de uno o varios sprints
desde Azure DevOps, incluyendo revisiones (cambios de estado, tags) y
relaciones (commits, PRs) de cada work item.

Para cada PBI, Bug y Feature del sprint obtiene:
  - Campos: Effort, State, Tags, AssignedTo, IterationPath, fechas.
  - Historial de revisiones: permite reconstruir cuándo entró en cada estado
    y qué tags se fueron añadiendo (QA, PRE, PRO, etc.).
  - Commits y PRs enlazados al work item.

Output:
  ~/.savia/sprint-history/sprint_{N}_full.json   — items + revisiones + relaciones
  ~/.savia/sprint-history/summary.json            — métricas agregadas por sprint

Uso:
  python import_sprint_story.py \\
    --org "MiOrg" --project "MiProyecto" \\
    --iteration-root "MiProyecto\\Desarrollo" \\
    --pat-file ~/.azure/mi-pat \\
    --sprints 22 23 24 25 26 \\
    [--output-dir ~/.savia/sprint-history] \\
    [--tags-qa "qa,testing_qa"] \\
    [--tags-pre "pre,pre-nb"] \\
    [--tags-pro "subido a pro,desplegar a pro"]
"""

import argparse
import base64
import json
import os
import sys
import time
import urllib.request
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuración por defecto
# ---------------------------------------------------------------------------

TIMEOUT = 60          # segundos por petición HTTP
SLEEP = 0.15          # pausa entre peticiones para no saturar la API
BATCH_SIZE = 200      # items por lote al consultar work items

# Estados que cuentan como "desarrollo completado" a efectos de reporting.
STATES_COMPLETED = {"Done"}

# Tags en DevOps que evidencian despliegue a cada entorno.
# Se comparan sin distinguir mayúsculas/minúsculas.
TAGS_QA_DEFAULT = ["qa", "testing_qa", "reportado_qa", "devuelto-qa"]
TAGS_PRE_DEFAULT = ["pre", "pre-nb"]
TAGS_PRO_DEFAULT = ["subido a pro", "desplegar a pro", "pendiente de subida pro"]

# Tipos de work item que se incluyen en el escaneo.
WORK_ITEM_TYPES = "('Product Backlog Item','Bug','Feature')"

# Campos que se solicitan a la API para cada work item.
ITEM_FIELDS = [
    "System.Id", "System.WorkItemType", "System.Title", "System.State",
    "System.AssignedTo", "System.IterationPath", "System.AreaPath", "System.Tags",
    "Microsoft.VSTS.Scheduling.Effort",
    "Microsoft.VSTS.Scheduling.StoryPoints",
    "Microsoft.VSTS.Scheduling.OriginalEstimate",
    "Microsoft.VSTS.Scheduling.RemainingWork",
    "Microsoft.VSTS.Scheduling.CompletedWork",
    "System.CreatedDate", "System.ChangedDate",
    "Microsoft.VSTS.Common.ClosedDate",
    "Microsoft.VSTS.Common.ResolvedDate",
    "Microsoft.VSTS.Common.ActivatedDate",
    "Microsoft.VSTS.Common.StateChangeDate",
]


# ===================================================================
# Autenticación
# ===================================================================

def cargar_pat(pat_file: Path) -> str:
    """Lee el PAT desde un fichero local (una sola línea, sin saltos)."""
    if not pat_file.exists():
        sys.exit(f"ERROR: PAT no encontrado en {pat_file}.\n"
                 f"  Genera uno en dev.azure.com > User Settings > PATs\n"
                 f"  y guárdalo en ese fichero (una línea, sin salto).")
    token = pat_file.read_text(encoding="utf-8").strip()
    if not token:
        sys.exit(f"ERROR: El fichero {pat_file} está vacío.")
    return token


def cabecera_auth(pat: str) -> dict:
    """Construye la cabecera HTTP Basic Auth para Azure DevOps."""
    token_b64 = base64.b64encode((":" + pat).encode()).decode()
    return {"Authorization": "Basic " + token_b64, "Accept": "application/json"}


# ===================================================================
# Peticiones HTTP (solo GET y POST, operaciones de solo lectura)
# ===================================================================

def http_get(url: str, pat: str) -> dict:
    """GET contra Azure DevOps REST API."""
    req = urllib.request.Request(url, headers=cabecera_auth(pat))
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read())


def http_post(url: str, pat: str, body: dict) -> dict:
    """POST contra Azure DevOps REST API (usado para WIQL)."""
    headers = cabecera_auth(pat)
    headers["Content-Type"] = "application/json"
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read())


# ===================================================================
# Consultas a Azure DevOps
# ===================================================================

def consultar_ids_sprint(pat: str, org: str, proyecto: str,
                         iter_root: str, sprint_n: int) -> list:
    """Ejecuta WIQL para obtener los IDs de todos los PBIs, Bugs y Features
    de un sprint concreto."""
    iter_path = f"{iter_root}\\Sprint {sprint_n}"
    iter_esc = iter_path.replace("\\", "\\\\")
    proj_enc = urllib.parse.quote(proyecto)
    url = f"https://dev.azure.com/{org}/{proj_enc}/_apis/wit/wiql?api-version=7.1"

    consulta = (
        "SELECT [System.Id] FROM workitems "
        f"WHERE [System.IterationPath] UNDER '{iter_esc}' "
        f"AND [System.WorkItemType] IN {WORK_ITEM_TYPES} "
        "AND [System.State] <> 'Removed' "
        "ORDER BY [System.Id]"
    )
    resultado = http_post(url, pat, {"query": consulta})
    return [w["id"] for w in resultado.get("workItems", [])]


def obtener_items_lote(pat: str, org: str, ids: list) -> list:
    """Obtiene los campos de una lista de work items por su ID,
    en lotes de BATCH_SIZE items."""
    if not ids:
        return []
    campos = ",".join(ITEM_FIELDS)
    items = []
    for i in range(0, len(ids), BATCH_SIZE):
        lote = ids[i:i + BATCH_SIZE]
        ids_csv = ",".join(str(x) for x in lote)
        url = (f"https://dev.azure.com/{org}/_apis/wit/workitems?ids={ids_csv}"
               f"&fields={campos}&api-version=7.1")
        try:
            datos = http_get(url, pat)
            items.extend(datos.get("value", []))
        except Exception as err:
            sys.stderr.write(f"  [items lote {i}] ERROR: {str(err)[:200]}\n")
        time.sleep(SLEEP)
    return items


def obtener_revisiones(pat: str, org: str, proyecto: str, wid: int) -> list:
    """Obtiene el historial completo de revisiones de un work item.
    Devuelve solo State, Tags, ChangedDate y ChangedBy para cada revisión."""
    proj_enc = urllib.parse.quote(proyecto)
    url = (f"https://dev.azure.com/{org}/{proj_enc}"
           f"/_apis/wit/workitems/{wid}/revisions?$expand=fields&api-version=7.1")
    try:
        datos = http_get(url, pat)
        revisiones = datos.get("value", [])
        return [{
            "rev": r.get("rev"),
            "state": r.get("fields", {}).get("System.State"),
            "tags": r.get("fields", {}).get("System.Tags"),
            "changedDate": r.get("fields", {}).get("System.ChangedDate"),
            "changedBy": (
                r.get("fields", {}).get("System.ChangedBy") or {}
            ).get("displayName") if isinstance(
                r.get("fields", {}).get("System.ChangedBy"), dict
            ) else None,
        } for r in revisiones]
    except Exception as err:
        sys.stderr.write(f"  [rev {wid}] ERROR: {str(err)[:200]}\n")
        return []


def obtener_relaciones(pat: str, org: str, proyecto: str, wid: int) -> list:
    """Obtiene las relaciones de un work item (commits, PRs, padre/hijo)."""
    proj_enc = urllib.parse.quote(proyecto)
    url = (f"https://dev.azure.com/{org}/{proj_enc}"
           f"/_apis/wit/workitems/{wid}?$expand=relations&api-version=7.1")
    try:
        datos = http_get(url, pat)
        return [{
            "rel": r.get("rel"),
            "url": r.get("url"),
            "attributes": r.get("attributes"),
        } for r in datos.get("relations", [])]
    except Exception:
        return []


# ===================================================================
# Análisis de historial de revisiones
# ===================================================================

def primera_transicion(revisiones: list, estado_objetivo: str):
    """Devuelve (fecha, rev) de la primera transición AL estado_objetivo,
    o (None, None) si nunca entró en ese estado."""
    anterior = None
    for r in revisiones:
        if r["state"] == estado_objetivo and anterior != estado_objetivo:
            return r["changedDate"], r["rev"]
        anterior = r["state"]
    return None, None


def primera_aparicion_tag(revisiones: list, tag: str):
    """Devuelve (fecha, rev) de la primera revisión donde aparece el tag
    (búsqueda case-insensitive como subcadena), o (None, None)."""
    tag_lower = tag.lower()
    tenia_tag = False
    for r in revisiones:
        tags_actuales = (r.get("tags") or "").lower()
        tiene_tag = tag_lower in tags_actuales
        if tiene_tag and not tenia_tag:
            return r["changedDate"], r["rev"]
        tenia_tag = tiene_tag
    return None, None


def primera_fecha_tag(revisiones: list, tags_buscar: list):
    """Busca la primera fecha en que apareció CUALQUIERA de los tags dados.
    Devuelve la fecha más temprana, o None si ninguno apareció."""
    mejor = None
    for tag in tags_buscar:
        fecha, _ = primera_aparicion_tag(revisiones, tag)
        if fecha and (mejor is None or fecha < mejor):
            mejor = fecha
    return mejor


# ===================================================================
# Análisis de un item individual
# ===================================================================

def analizar_item(item: dict, revisiones: list,
                  tags_qa: list, tags_pre: list, tags_pro: list) -> dict:
    """Extrae métricas clave de un work item a partir de sus campos
    actuales y su historial de revisiones."""
    campos = item.get("fields", {})
    esfuerzo = campos.get("Microsoft.VSTS.Scheduling.Effort", 0) or 0
    estado_actual = campos.get("System.State", "")
    tags_actuales = (campos.get("System.Tags") or "").lower()

    # Primera vez que entró en Done
    fecha_done, _ = primera_transicion(revisiones, "Done")

    # Primera vez que apareció cada tipo de tag
    fecha_qa = primera_fecha_tag(revisiones, tags_qa)
    fecha_pre = primera_fecha_tag(revisiones, tags_pre)
    fecha_pro = primera_fecha_tag(revisiones, tags_pro)

    # ¿Tiene alguno de estos tags AHORA?
    tiene_tag_qa = any(t in tags_actuales for t in tags_qa)
    tiene_tag_pre = any(t in tags_actuales for t in tags_pre)
    tiene_tag_pro = any(t in tags_actuales for t in tags_pro)

    # Regla: "Desarrollo Completado" = Done O tiene algún tag de entorno
    completado = (
        estado_actual == "Done"
        or tiene_tag_qa or tiene_tag_pre or tiene_tag_pro
        or bool(fecha_qa or fecha_pre or fecha_pro)
    )

    return {
        "id": campos.get("System.Id"),
        "tipo": campos.get("System.WorkItemType"),
        "titulo": (campos.get("System.Title") or "")[:80],
        "estado_actual": estado_actual,
        "tags_actuales": campos.get("System.Tags") or "",
        "esfuerzo": esfuerzo,
        "asignado": (
            (campos.get("System.AssignedTo") or {}).get("displayName")
            if isinstance(campos.get("System.AssignedTo"), dict) else None
        ),
        "iteracion": campos.get("System.IterationPath"),
        "fecha_done": fecha_done,
        "fecha_qa": fecha_qa,
        "fecha_pre": fecha_pre,
        "fecha_pro": fecha_pro,
        "desarrollo_completado": completado,
    }


# ===================================================================
# Procesamiento de un sprint completo
# ===================================================================

def procesar_sprint(pat: str, org: str, proyecto: str,
                    iter_root: str, sprint_n: int,
                    out_dir: Path,
                    tags_qa: list, tags_pre: list, tags_pro: list) -> dict:
    """Escanea un sprint completo: obtiene items, revisiones,
    relaciones y calcula métricas agregadas."""
    sys.stderr.write(f"\n=== Sprint {sprint_n} ===\n")

    ids = consultar_ids_sprint(pat, org, proyecto, iter_root, sprint_n)
    sys.stderr.write(f"  IDs obtenidos: {len(ids)}\n")

    items = obtener_items_lote(pat, org, ids)
    sys.stderr.write(f"  Items con campos: {len(items)}\n")

    enriquecidos = []
    for i, it in enumerate(items, 1):
        wid = it["fields"]["System.Id"]
        revisiones = obtener_revisiones(pat, org, proyecto, wid)
        resumen = analizar_item(it, revisiones, tags_qa, tags_pre, tags_pro)
        enriquecidos.append({
            "item": it,
            "revisiones": revisiones,
            "relaciones": obtener_relaciones(pat, org, proyecto, wid),
            "resumen": resumen,
        })
        if i % 20 == 0 or i == len(items):
            sys.stderr.write(f"    progreso revisiones: {i}/{len(items)}\n")
        time.sleep(SLEEP)

    # Métricas agregadas del sprint
    total_esfuerzo = sum(r["resumen"]["esfuerzo"] for r in enriquecidos)
    esfuerzo_completado = sum(
        r["resumen"]["esfuerzo"] for r in enriquecidos
        if r["resumen"]["desarrollo_completado"]
    )
    por_estado = {}
    for r in enriquecidos:
        estado = r["resumen"]["estado_actual"]
        por_estado[estado] = por_estado.get(estado, 0) + r["resumen"]["esfuerzo"]

    resumen_sprint = {
        "sprint": sprint_n,
        "total_items": len(enriquecidos),
        "esfuerzo_total": total_esfuerzo,
        "esfuerzo_completado": esfuerzo_completado,
        "porcentaje_completado": round(
            esfuerzo_completado / total_esfuerzo * 100
            if total_esfuerzo else 0, 1
        ),
        "esfuerzo_por_estado": por_estado,
    }

    # Guardar fichero JSON por sprint
    out_file = out_dir / f"sprint_{sprint_n}_full.json"
    out_file.write_text(json.dumps(
        {"resumen": resumen_sprint, "items": enriquecidos},
        ensure_ascii=False, indent=2
    ), encoding="utf-8")
    sys.stderr.write(f"  -> guardado en {out_file}\n")
    return resumen_sprint


# ===================================================================
# Punto de entrada
# ===================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Extrae historial completo de sprints desde Azure DevOps "
                    "(items + revisiones + relaciones)."
    )
    parser.add_argument("--org", required=True,
                        help="Organización de Azure DevOps (ej. 'MiOrg')")
    parser.add_argument("--project", required=True,
                        help="Nombre del proyecto en Azure DevOps (ej. 'MiProyecto')")
    parser.add_argument("--iteration-root", required=True,
                        help="Raíz de iteraciones (ej. 'MiProyecto\\\\Desarrollo'). "
                             "El script añade '\\\\Sprint N' automáticamente.")
    parser.add_argument("--pat-file", required=True,
                        help="Ruta al fichero con el PAT (una línea, sin salto)")
    parser.add_argument("--sprints", nargs="+", type=int, required=True,
                        help="Números de sprint a procesar (ej. 22 23 24 25 26)")
    parser.add_argument("--output-dir", default=None,
                        help="Directorio de salida (default: ~/.savia/sprint-history)")
    parser.add_argument("--tags-qa", default=",".join(TAGS_QA_DEFAULT),
                        help="Tags que indican subida a QA, separados por comas")
    parser.add_argument("--tags-pre", default=",".join(TAGS_PRE_DEFAULT),
                        help="Tags que indican subida a PRE, separados por comas")
    parser.add_argument("--tags-pro", default=",".join(TAGS_PRO_DEFAULT),
                        help="Tags que indican subida a PRO, separados por comas")
    args = parser.parse_args()

    # Resolver rutas y tags
    pat_file = Path(args.pat_file).expanduser().resolve()
    pat = cargar_pat(pat_file)

    out_dir = Path(args.output_dir).expanduser().resolve() if args.output_dir \
        else Path.home() / ".savia" / "sprint-history"
    out_dir.mkdir(parents=True, exist_ok=True)

    tags_qa = [t.strip().lower() for t in args.tags_qa.split(",") if t.strip()]
    tags_pre = [t.strip().lower() for t in args.tags_pre.split(",") if t.strip()]
    tags_pro = [t.strip().lower() for t in args.tags_pro.split(",") if t.strip()]

    sys.stderr.write(f"Organización : {args.org}\n")
    sys.stderr.write(f"Proyecto     : {args.project}\n")
    sys.stderr.write(f"Raíz iter.   : {args.iteration_root}\n")
    sys.stderr.write(f"PAT          : {pat_file}\n")
    sys.stderr.write(f"Sprints      : {args.sprints}\n")
    sys.stderr.write(f"Salida       : {out_dir}\n")
    sys.stderr.write(f"Tags QA      : {tags_qa}\n")
    sys.stderr.write(f"Tags PRE     : {tags_pre}\n")
    sys.stderr.write(f"Tags PRO     : {tags_pro}\n")
    sys.stderr.write("---\n")

    resumenes = []
    for s in args.sprints:
        try:
            resumenes.append(procesar_sprint(
                pat, args.org, args.project, args.iteration_root,
                s, out_dir, tags_qa, tags_pre, tags_pro
            ))
        except Exception as err:
            sys.stderr.write(f"ERROR Sprint {s}: {err}\n")

    # Guardar resumen global
    summary_file = out_dir / "summary.json"
    summary_file.write_text(json.dumps({
        "generado": datetime.now(timezone.utc).isoformat(),
        "org": args.org,
        "proyecto": args.project,
        "sprints": resumenes,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    sys.stderr.write(f"\nResumen global guardado en {summary_file}\n")

    # Mostrar tabla resumen en stdout
    print(json.dumps({
        "org": args.org,
        "proyecto": args.project,
        "sprints": resumenes,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
