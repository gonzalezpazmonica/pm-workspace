#!/usr/bin/env python3
"""SE-413 F2 — worker de extracción de Savia Files.

Uso: extract.py <pdf|docx|pptx|xlsx> <ruta>
Salida (stdout, un objeto JSON):
  {"method": str, "units": [{"locator": {...}, "kind": str, "text": str, "formula"?: str}],
   "skipped": [{"reason": str, "count": int}]}
Error: exit 1 y {"error": str} en stdout.

El contenido es dato no confiable: no se ejecutan macros, no se recalculan
fórmulas y no se hace OCR. Sin red: los modelos de Docling deben estar en caché.
"""
import io
import json
import logging
import os
import sys
import warnings
from collections import Counter

MAX_UNITS = int(os.environ.get("SAVIA_FILES_MAX_UNITS", "50000"))
MAX_UNIT_CHARS = 20000

warnings.filterwarnings("ignore")
logging.disable(logging.WARNING)


class Out:
    def __init__(self, method):
        self.method = method
        self.units = []
        self.skipped = Counter()

    def add(self, locator, kind, text, formula=None):
        text = (text or "").strip()
        if not text:
            return
        if len(self.units) >= MAX_UNITS:
            self.skipped["max-units"] += 1
            return
        if len(text) > MAX_UNIT_CHARS:
            text = text[:MAX_UNIT_CHARS]
            self.skipped["truncated"] += 1
        unit = {"locator": locator, "kind": kind, "text": text}
        if formula:
            unit["formula"] = formula
        self.units.append(unit)

    def dump(self):
        return {
            "method": self.method,
            "units": self.units,
            "skipped": [{"reason": r, "count": c} for r, c in sorted(self.skipped.items())],
        }


def docling_version():
    try:
        from importlib.metadata import version
        return version("docling")
    except Exception:
        return "unknown"


def docling_extract(kind, path):
    from docling.datamodel.base_models import InputFormat
    from docling.datamodel.pipeline_options import PdfPipelineOptions
    from docling.document_converter import DocumentConverter, PdfFormatOption

    opts = PdfPipelineOptions(do_ocr=False)
    conv = DocumentConverter(format_options={InputFormat.PDF: PdfFormatOption(pipeline_options=opts)})
    doc = conv.convert(path).document
    out = Out(f"docling-{docling_version()}")
    for index, (item, _level) in enumerate(doc.iterate_items()):
        label = str(getattr(item, "label", "") or type(item).__name__).split(".")[-1].lower()
        text = getattr(item, "text", None)
        if text is None and label == "table":
            text = item.export_to_markdown(doc)
        if text is None:
            out.skipped["image-no-ocr" if label == "picture" else f"no-text-{label}"] += 1
            continue
        prov = getattr(item, "prov", None) or []
        page = prov[0].page_no if prov else None
        if kind == "pdf":
            locator = {"type": "page", "page": page or 1}
        elif kind == "pptx":
            locator = {"type": "slide", "slide": page or 1}
        else:
            locator = {"type": "element", "index": index}
        out.add(locator, label, text)
    return out


def xlsx_extract(path):
    import openpyxl

    # Los blobs se nombran por SHA-256, sin extensión: openpyxl valida la extensión
    # de una ruta, así que se le pasa un stream binario.
    with open(path, "rb") as fh:
        data = fh.read()
    formulas = openpyxl.load_workbook(io.BytesIO(data), data_only=False, read_only=True, keep_vba=False)
    values = openpyxl.load_workbook(io.BytesIO(data), data_only=True, read_only=True, keep_vba=False)
    out = Out(f"openpyxl-{openpyxl.__version__}")
    for ws in formulas.worksheets:
        vs = values[ws.title]
        for row, vrow in zip(ws.iter_rows(), vs.iter_rows()):
            for cell, vcell in zip(row, vrow):
                raw = cell.value
                coord = getattr(cell, "coordinate", None)
                if raw is None or coord is None:
                    continue
                formula = raw if isinstance(raw, str) and raw.startswith("=") else None
                value = vcell.value if formula else raw
                if formula and value is None:
                    out.skipped["formula-without-cached-value"] += 1
                shown = "" if value is None else str(value)
                text = f"{ws.title}!{coord}: {shown}" + (f" ({formula})" if formula else "")
                out.add({"type": "cell", "sheet": ws.title, "cell": coord}, "cell", text, formula)
    formulas.close()
    values.close()
    return out


def main(argv):
    if len(argv) != 3 or argv[1] not in ("pdf", "docx", "pptx", "xlsx"):
        print(json.dumps({"error": "uso: extract.py <pdf|docx|pptx|xlsx> <ruta>"}))
        return 2
    kind, path = argv[1], argv[2]
    try:
        out = xlsx_extract(path) if kind == "xlsx" else docling_extract(kind, path)
    except Exception as e:  # el llamador marca FAILED con este mensaje
        print(json.dumps({"error": f"{type(e).__name__}: {str(e)[:500]}"}))
        return 1
    sys.stdout.write(json.dumps(out.dump(), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
