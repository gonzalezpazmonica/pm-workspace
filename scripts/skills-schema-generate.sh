#!/usr/bin/env bash
# skills-schema-generate.sh
#
# SE-238: Genera skills-schema.json (schema programático de todos los skills)
# y skills-schema.md (versión legible para .llms.txt).
#
# Lee todos los .opencode/skills/*/SKILL.md y extrae:
#   - skill_id: nombre del directorio
#   - description: campo "description" del frontmatter YAML o primera línea H1
#   - tags: campo "tags" del frontmatter si existe
#   - inputs_hint: primera línea de "## Inputs" / "## Parámetros" si existe
#   - outputs_hint: primera línea de "## Outputs" / "## Resultado" si existe
#   - example_trigger: primera línea de "## Cuándo usar" / "## Triggers"
#   - skill_path: path relativo al SKILL.md
#
# Uso:
#   skills-schema-generate.sh [--skills-dir DIR] [--output FILE]
#   skills-schema-generate.sh  # usa defaults: .opencode/skills/, skills-schema.json
#
# Variables de entorno:
#   SKILLS_DIR     — directorio de skills (default: .opencode/skills)
#   OUTPUT_JSON    — fichero JSON de salida (default: skills-schema.json)
#   OUTPUT_MD      — fichero MD de salida (default: skills-schema.md)
#
# El script es idempotente: mismo output para el mismo estado del repo.
#
# Ref: docs/propuestas/SE-238-skills-schema-discoverable.md

set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SKILLS_DIR="${SKILLS_DIR:-${REPO_ROOT}/.opencode/skills}"
OUTPUT_JSON="${OUTPUT_JSON:-${REPO_ROOT}/skills-schema.json}"
OUTPUT_MD="${OUTPUT_MD:-${REPO_ROOT}/skills-schema.md}"

# ── Parsear argumentos ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skills-dir) SKILLS_DIR="$2"; shift 2 ;;
    --output)     OUTPUT_JSON="$2"; shift 2 ;;
    --output-md)  OUTPUT_MD="$2"; shift 2 ;;
    *) echo "Uso: $0 [--skills-dir DIR] [--output FILE] [--output-md FILE]" >&2; exit 1 ;;
  esac
done

# ── Verificar directorio de skills ───────────────────────────────────────────
if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "ERROR: directorio de skills no encontrado: $SKILLS_DIR" >&2
  exit 1
fi

# ── Generar schema con Python ─────────────────────────────────────────────────
python3 - "$SKILLS_DIR" "$OUTPUT_JSON" "$OUTPUT_MD" <<'PYTHON_EOF'
import sys
import json
import os
import re

skills_dir = sys.argv[1]
output_json = sys.argv[2]
output_md = sys.argv[3]

def extract_frontmatter(content):
    """Extrae frontmatter YAML de un fichero Markdown."""
    if not content.startswith('---'):
        return {}, content
    
    end = content.find('\n---', 3)
    if end == -1:
        return {}, content
    
    fm_text = content[3:end].strip()
    rest = content[end+4:].strip()
    
    # Parseo básico de YAML (sin dependencias externas)
    fm = {}
    current_key = None
    current_list = None
    
    for line in fm_text.splitlines():
        if not line.strip():
            continue
        # Lista con guión
        if line.startswith('  - ') or (line.startswith('- ') and current_list is not None):
            val = line.strip()[2:].strip().strip('"\'')
            if current_list is not None:
                current_list.append(val)
            continue
        # Key: value
        if ':' in line and not line.startswith(' '):
            k, v = line.split(':', 1)
            k = k.strip()
            v = v.strip()
            # Detectar inline array: ["a", "b", "c"]
            if v.startswith('[') and v.endswith(']'):
                import re as _re
                items = _re.findall(r'"([^"]+)"|\'([^\']+)\'|([^\s,\[\]]+)', v[1:-1])
                parsed = [i[0] or i[1] or i[2] for i in items if any(i)]
                fm[k] = parsed
                current_key = None
                current_list = None
            elif v.strip('"\'') == '' or v == '':
                # Podría ser lista multilínea
                current_key = k
                current_list = []
                fm[k] = current_list
            else:
                fm[k] = v.strip('"\'')
                current_key = k
                current_list = None
    
    return fm, rest

def extract_section_first_line(content, section_headers):
    """Extrae la primera línea de texto de una sección Markdown."""
    for header in section_headers:
        pattern = rf'^##\s+{re.escape(header)}\s*$'
        match = re.search(pattern, content, re.MULTILINE | re.IGNORECASE)
        if match:
            # Buscar la primera línea no vacía después del header
            rest = content[match.end():]
            for line in rest.splitlines():
                line = line.strip()
                if line and not line.startswith('#'):
                    # Limpiar markdown básico
                    line = re.sub(r'\*\*|__|\*|_|`', '', line)
                    return line[:200]  # max 200 chars
    return ""

def extract_skill_info(skill_id, skill_path):
    """Extrae información de un SKILL.md."""
    try:
        with open(skill_path) as f:
            content = f.read()
    except Exception:
        return None
    
    fm, body = extract_frontmatter(content)
    
    # description: del frontmatter o primera línea no vacía del body
    description = fm.get('description', '')
    if not description:
        for line in body.splitlines():
            line = line.strip()
            if line and not line.startswith('#'):
                description = re.sub(r'\*\*|__|\*|_|`', '', line)[:300]
                break
        if not description:
            # Primera línea H1
            m = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
            if m:
                description = m.group(1).strip()
    
    # tags
    tags = fm.get('tags', [])
    if isinstance(tags, str):
        tags = [t.strip() for t in tags.split(',')]
    
    # inputs_hint
    inputs_hint = extract_section_first_line(body, ['Inputs', 'Parámetros', 'Parameters', 'Input'])
    
    # outputs_hint
    outputs_hint = extract_section_first_line(body, ['Outputs', 'Resultado', 'Output', 'Salida'])
    
    # example_trigger
    example_trigger = extract_section_first_line(body, ['Cuándo usar', 'Cuando usar', 'Triggers', 'Trigger', 'When to use', 'Uso'])
    
    entry = {
        "skill_id": skill_id,
        "description": description[:400] if description else f"Skill: {skill_id}",
        "skill_path": os.path.join(".opencode", "skills", skill_id, "SKILL.md").replace("\\", "/"),
    }
    
    if tags:
        entry["tags"] = tags
    if inputs_hint:
        entry["inputs_hint"] = inputs_hint
    if outputs_hint:
        entry["outputs_hint"] = outputs_hint
    if example_trigger:
        entry["example_trigger"] = example_trigger
    
    return entry

# ── Iterar sobre skills ───────────────────────────────────────────────────────
skills = []
skill_dirs = sorted(os.listdir(skills_dir))

for skill_id in skill_dirs:
    skill_dir = os.path.join(skills_dir, skill_id)
    skill_md = os.path.join(skill_dir, "SKILL.md")
    
    if not os.path.isdir(skill_dir):
        continue
    if not os.path.isfile(skill_md):
        continue
    # Ignorar directorio _template
    if skill_id.startswith('_'):
        continue
    
    entry = extract_skill_info(skill_id, skill_md)
    if entry:
        skills.append(entry)

# ── Escribir skills-schema.json ───────────────────────────────────────────────
schema = {
    "_meta": {
        "generated": "2026-06-28",
        "generator": "scripts/skills-schema-generate.sh",
        "spec": "SE-238",
        "total_skills": len(skills),
        "description": "Schema programático de todos los skills de Savia pm-workspace. Optimizado para consumo por LLMs y agentes externos."
    },
    "skills": skills
}

with open(output_json, 'w') as f:
    json.dump(schema, f, indent=2, ensure_ascii=False)

# ── Escribir skills-schema.md ─────────────────────────────────────────────────
with open(output_md, 'w') as f:
    f.write(f"# Skills Schema — Savia pm-workspace\n\n")
    f.write(f"> Generado automáticamente por `scripts/skills-schema-generate.sh` (SE-238).\n")
    f.write(f"> {len(skills)} skills indexados.\n\n")
    f.write(f"| skill_id | description | tags |\n")
    f.write(f"|----------|-------------|------|\n")
    for s in skills:
        tags_str = ", ".join(s.get("tags", [])) or "—"
        desc = s["description"][:80].replace("|", "\\|")
        f.write(f"| {s['skill_id']} | {desc} | {tags_str} |\n")

print(f"OK: {len(skills)} skills indexados → {output_json}", file=sys.stderr)
print(json.dumps({"ok": True, "total_skills": len(skills), "output_json": output_json, "output_md": output_md}))
PYTHON_EOF
