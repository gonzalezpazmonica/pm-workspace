#!/bin/bash
# ast-comprehend.sh — Extractor estructural multi-lenguaje (ast-comprehension skill)
# Uso: ast-comprehend.sh <target> [--surface-only] [--legacy-mode] [--output <path>]
# Salida: JSON unificado en stdout (o en --output si se especifica)
set -uo pipefail

TARGET="${1:-}"
SURFACE_ONLY=false
LEGACY_MODE=false
OUTPUT_FILE=""

# Parsear argumentos
shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --surface-only) SURFACE_ONLY=true ;;
    --legacy-mode)  LEGACY_MODE=true ;;
    --output)       OUTPUT_FILE="${2:-}"; shift ;;
  esac
  shift
done

if [[ -z "$TARGET" ]]; then
  echo '{"error":"No target specified. Usage: ast-comprehend.sh <file|dir>"}' >&2
  exit 1
fi

# ── Utilidades ────────────────────────────────────────────────────────────────

detect_language() {
  local file="$1"
  local ext="${file##*.}"
  case "$ext" in
    cs|csproj|sln) echo "csharp" ;;
    ts|mts|cts)    echo "typescript" ;;
    tsx)           echo "typescript" ;;
    js|jsx|mjs)    echo "javascript" ;;
    py)            echo "python" ;;
    go)            echo "go" ;;
    rs)            echo "rust" ;;
    java)          echo "java" ;;
    php)           echo "php" ;;
    rb)            echo "ruby" ;;
    swift)         echo "swift" ;;
    kt|kts)        echo "kotlin" ;;
    dart)          echo "dart" ;;
    tf|tfvars|hcl) echo "terraform" ;;
    *)             echo "unknown" ;;
  esac
}

count_lines() {
  wc -l < "$1" 2>/dev/null || echo "0"
}

count_complexity() {
  local file="$1"
  grep -cE \
    "(if[[:space:]]*\(|else if[[:space:]]*\(|for[[:space:]]*\(|while[[:space:]]*\(|switch[[:space:]]*\(|\bcase\b|\bcatch\b|\&\&|\|\||\?[^:])" \
    "$file" 2>/dev/null || echo "0"
}

# ── Extracción grep-structural (fallback universal 0 deps) ────────────────────

grep_structural_extract() {
  local file="$1"
  local lang="$2"

  # Clases
  local classes_json
  classes_json=$(grep -nE \
    "(^(public|private|protected|abstract|sealed|static|export).*[[:space:]]+(class|interface|struct|enum)[[:space:]]+[A-Za-z]|\
^[[:space:]]*(class|interface|struct|enum)[[:space:]]+[A-Za-z])" \
    "$file" 2>/dev/null | head -30 | \
    awk -F: '{gsub(/^[[:space:]]+/, "", $2); printf "{\"name\":\"%s\",\"line\":%d},", gensub(/.*[[:space:]]+(class|interface|struct|enum)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/, "\\2", "g", $2), $1}' | \
    sed 's/,$//')

  # Funciones/métodos
  local functions_json
  functions_json=$(grep -nE \
    "(^(public|private|protected|async|static|export)[[:space:]].*[[:space:]](function|def|fn|func)\s+[A-Za-z]|\
^[[:space:]]*(def|fn|func|function)[[:space:]]+[A-Za-z]|\
^[[:space:]]*(public|private|protected|async)[[:space:]]+.*[A-Za-z]+\s*\()" \
    "$file" 2>/dev/null | head -50 | \
    awk -F: '{gsub(/^[[:space:]]+/, "", $2); printf "{\"name\":\"%s\",\"line\":%d},", gensub(/.*(def|fn|func|function|)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/, "\\2", "g", $2), $1}' | \
    sed 's/,$//')

  # Imports
  local imports_json
  imports_json=$(grep -nE \
    "^(import|from|require|use|using|include|#include|extern crate)[[:space:]]+" \
    "$file" 2>/dev/null | head -20 | \
    awk -F: '{gsub(/^[[:space:]]+/, "", $2); printf "\"%s\",", $2}' | sed 's/,$//')

  local complexity
  complexity=$(count_complexity "$file")

  echo "{
    \"classes\": [${classes_json:-}],
    \"functions\": [${functions_json:-}],
    \"imports_raw\": [${imports_json:-}],
    \"complexity_approx\": ${complexity}
  }"
}

# ── Extracción Python (ast module nativo) ─────────────────────────────────────

python_extract() {
  local file="$1"
  python3 - "$file" 2>/dev/null <<'PYEOF'
import ast, json, sys

def analyze(path):
    with open(path) as f:
        src = f.read()
    try:
        tree = ast.parse(src)
    except SyntaxError as e:
        return {"error": str(e)}

    classes, functions, imports = [], [], []
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            methods = [
                {"name": m.name, "line": m.lineno}
                for m in node.body
                if isinstance(m, (ast.FunctionDef, ast.AsyncFunctionDef))
            ]
            classes.append({"name": node.name, "line": node.lineno, "methods": methods})
        elif isinstance(node, ast.FunctionDef) or isinstance(node, ast.AsyncFunctionDef):
            functions.append({"name": node.name, "line": node.lineno})
        elif isinstance(node, ast.Import):
            for alias in node.names:
                imports.append(alias.name)
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            imports.append(f"from {module}")
    return {"classes": classes, "functions": functions, "imports": imports}

print(json.dumps(analyze(sys.argv[1])))
PYEOF
}

# ── Extracción TypeScript via node (ts-morph si disponible) ───────────────────

typescript_extract() {
  local file="$1"
  # Intentar ts-morph si disponible
  if node -e "require('ts-morph')" 2>/dev/null; then
    node -e "
try {
  const { Project } = require('ts-morph');
  const p = new Project({ addFilesFromTsConfig: false, skipLoadingLibFiles: true });
  const sf = p.addSourceFileAtPath('$file');
  const result = {
    classes: sf.getClasses().map(c => ({
      name: c.getName() || 'anonymous',
      line: c.getStartLineNumber(),
      methods: c.getMethods().map(m => ({name: m.getName(), line: m.getStartLineNumber()}))
    })),
    functions: sf.getFunctions().map(f => ({name: f.getName() || 'anonymous', line: f.getStartLineNumber()})),
    imports: sf.getImportDeclarations().map(i => i.getModuleSpecifierValue())
  };
  console.log(JSON.stringify(result));
} catch(e) { console.log(JSON.stringify({error: e.message})); }
" 2>/dev/null
  else
    # fallback grep
    grep_structural_extract "$file" "typescript"
  fi
}

# ── Extracción Go ─────────────────────────────────────────────────────────────

go_extract() {
  local file="$1"
  local dir
  dir=$(dirname "$file")
  if command -v gopls &>/dev/null; then
    gopls symbols "$file" 2>/dev/null | \
      awk '{print "{\"name\":\""$1"\",\"kind\":\""$2"\",\"line\":"$3"},"}' | \
      sed 's/,$//' | python3 -c "import sys,json; lines=sys.stdin.read().strip(); print(json.dumps({'symbols': json.loads('['+lines+']')}))" 2>/dev/null || \
      grep_structural_extract "$file" "go"
  else
    grep_structural_extract "$file" "go"
  fi
}

# ── Tree-sitter universal ─────────────────────────────────────────────────────

treesitter_extract() {
  local file="$1"
  if ! command -v tree-sitter &>/dev/null; then
    return 1
  fi
  tree-sitter parse "$file" --output json 2>/dev/null | python3 - 2>/dev/null <<'TSEOF'
import sys, json

def extract_structure(node, result=None):
    if result is None:
        result = {"classes": [], "functions": []}
    node_type = node.get("type", "")
    if node_type in ("class_definition", "class_declaration", "class_specifier"):
        name_node = next((c for c in node.get("children", [])
                         if c.get("type") in ("identifier", "name", "type_identifier")), None)
        if name_node:
            result["classes"].append({
                "name": name_node.get("text", ""),
                "line": node.get("startPosition", {}).get("row", 0) + 1
            })
    if node_type in ("function_definition", "function_declaration",
                     "method_definition", "function_item", "method_declaration"):
        name_node = next((c for c in node.get("children", [])
                         if c.get("type") == "identifier"), None)
        if name_node:
            result["functions"].append({
                "name": name_node.get("text", ""),
                "line": node.get("startPosition", {}).get("row", 0) + 1
            })
    for child in node.get("children", []):
        extract_structure(child, result)
    return result

tree = json.load(sys.stdin)
print(json.dumps(extract_structure(tree)))
TSEOF
}

# ── Generar summary ────────────────────────────────────────────────────────────

generate_summary() {
  local file="$1"
  local lang="$2"
  local n_classes="$3"
  local n_functions="$4"
  local complexity="$5"
  local hotspot="${6:-ninguno}"

  local basename
  basename=$(basename "$file")
  echo "Fichero $basename ($lang). $n_classes clase(s), $n_functions función(es). Complejidad ciclomática aproximada: $complexity puntos de decisión. Hotspot más complejo: $hotspot."
}

# ── Análisis de hotspots ──────────────────────────────────────────────────────

find_hotspots() {
  local file="$1"
  # Aproximar por función: buscar funciones y contar puntos de decisión en su bloque
  # Simplificado: devuelve complejidad total del fichero
  local complexity
  complexity=$(count_complexity "$file")
  local warn=false
  if [[ "$complexity" -gt 15 ]]; then warn=true; fi
  echo "{\"total\": $complexity, \"warn\": $warn}"
}

# ── Procesar un fichero ───────────────────────────────────────────────────────

process_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "{\"error\": \"File not found: $file\"}"
    return
  fi

  local lang
  lang=$(detect_language "$file")
  local lines
  lines=$(count_lines "$file")
  local tool_used="grep-structural"

  # Extracción por capas
  local structure_json=""

  # Capa 1: Tree-sitter (si disponible y no solo superficie)
  if [[ "$SURFACE_ONLY" == "false" ]]; then
    local ts_result
    if ts_result=$(treesitter_extract "$file") && [[ -n "$ts_result" ]]; then
      structure_json="$ts_result"
      tool_used="tree-sitter"
    fi
  fi

  # Capa 2: herramienta nativa semántica
  if [[ "$SURFACE_ONLY" == "false" && -z "$structure_json" ]]; then
    case "$lang" in
      python)
        if command -v python3 &>/dev/null; then
          local py_result
          if py_result=$(python_extract "$file") && [[ -n "$py_result" ]]; then
            structure_json="$py_result"
            tool_used="python-ast"
          fi
        fi
        ;;
      typescript|javascript)
        local ts_result
        if ts_result=$(typescript_extract "$file") && [[ -n "$ts_result" ]]; then
          structure_json="$ts_result"
          tool_used="ts-morph"
        fi
        ;;
      go)
        local go_result
        if go_result=$(go_extract "$file") && [[ -n "$go_result" ]]; then
          structure_json="$go_result"
          tool_used="gopls"
        fi
        ;;
    esac
  fi

  # Capa 3: fallback grep-structural (siempre disponible)
  if [[ -z "$structure_json" ]]; then
    structure_json=$(grep_structural_extract "$file" "$lang")
    tool_used="grep-structural"
  fi

  # Complejidad
  local complexity_info
  complexity_info=$(find_hotspots "$file")
  local total_complexity
  total_complexity=$(echo "$complexity_info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('total',0))" 2>/dev/null || echo "0")

  # Extraer counts para summary
  local n_classes n_functions
  n_classes=$(echo "$structure_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('classes',[])))" 2>/dev/null || echo "0")
  n_functions=$(echo "$structure_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('functions',[])))" 2>/dev/null || echo "0")

  local summary
  summary=$(generate_summary "$file" "$lang" "$n_classes" "$n_functions" "$total_complexity")

  # Construir JSON unificado
  python3 - "$file" "$lang" "$lines" "$tool_used" "$total_complexity" "$summary" <<PYJSON
import sys, json

file_path = sys.argv[1]
lang = sys.argv[2]
lines = int(sys.argv[3])
tool_used = sys.argv[4]
complexity = int(sys.argv[5])
summary = sys.argv[6]

structure_raw = sys.stdin.read() if not sys.stdin.isatty() else "{}"

result = {
    "meta": {
        "file": file_path,
        "language": lang,
        "lines": lines,
        "tool": tool_used
    },
    "complexity": {
        "total_decision_points": complexity,
        "hotspots": [{"warn": complexity > 15, "total": complexity}]
    },
    "summary": summary
}

print(json.dumps(result, ensure_ascii=False, indent=2))
PYJSON
}

# ── Procesar directorio ───────────────────────────────────────────────────────

process_directory() {
  local dir="$1"
  local results=()
  local extensions="cs|ts|tsx|js|jsx|py|go|rs|java|php|rb|swift|kt|dart|tf"

  while IFS= read -r -d '' file; do
    local result
    result=$(process_file "$file")
    results+=("$result")
  done < <(find "$dir" -type f -regextype posix-extended \
    -regex ".*\.(${extensions})$" \
    ! -path "*/node_modules/*" \
    ! -path "*/.git/*" \
    ! -path "*/vendor/*" \
    ! -path "*/dist/*" \
    -print0 2>/dev/null)

  # Unir en array JSON
  local joined
  joined=$(IFS=','; echo "${results[*]:-}")
  echo "[${joined}]"
}

# ── Punto de entrada principal ────────────────────────────────────────────────

main() {
  local output
  if [[ -f "$TARGET" ]]; then
    output=$(process_file "$TARGET")
  elif [[ -d "$TARGET" ]]; then
    output=$(process_directory "$TARGET")
  else
    output="{\"error\": \"Target not found: $TARGET\"}"
  fi

  if [[ -n "$OUTPUT_FILE" ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    echo "$output" > "$OUTPUT_FILE"
    echo "Comprehension report saved: $OUTPUT_FILE" >&2
  else
    echo "$output"
  fi
}

main
