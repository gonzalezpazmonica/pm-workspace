# Extraction Commands per Language — AST Comprehension

## Estrategia por lenguaje

### Python — ast module (built-in, cero dependencias)

```bash
# Extracción estructural completa
python3 - <<'EOF' "$TARGET"
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
            methods = [m.name for m in node.body if isinstance(m, ast.FunctionDef)]
            classes.append({"name": node.name, "line": node.lineno, "methods": methods})
        elif isinstance(node, ast.FunctionDef) and not any(
            isinstance(p, ast.ClassDef) for p in ast.walk(tree)
            if hasattr(p, 'body') and node in ast.walk(p)
        ):
            functions.append({"name": node.name, "line": node.lineno})
        elif isinstance(node, (ast.Import, ast.ImportFrom)):
            imports.append(ast.dump(node))
    return {"classes": classes, "functions": functions, "imports": imports}

print(json.dumps(analyze(sys.argv[1])))
EOF
```

### TypeScript / JavaScript — ts-morph o typescript compiler

```bash
# Con ts-morph (npm install -g ts-morph)
node -e "
const { Project } = require('ts-morph');
const p = new Project({ addFilesFromTsConfig: false });
const sf = p.addSourceFileAtPath('$TARGET');
const result = {
  classes: sf.getClasses().map(c => ({
    name: c.getName(), line: c.getStartLineNumber(),
    methods: c.getMethods().map(m => ({name: m.getName(), isPublic: m.hasModifier('public')}))
  })),
  functions: sf.getFunctions().map(f => ({ name: f.getName(), line: f.getStartLineNumber() })),
  imports: sf.getImportDeclarations().map(i => i.getModuleSpecifierValue())
};
console.log(JSON.stringify(result));
"

# Fallback: eslint AST (siempre disponible)
eslint --print-ast --format json "$TARGET" 2>/dev/null | \
  jq '[.[] | select(.type == "ClassDeclaration" or .type == "FunctionDeclaration")]'
```

### C# / .NET — Roslyn SyntaxWalker via dotnet-script

```bash
# Con dotnet-script (dotnet tool install -g dotnet-script)
dotnet script - <<'CSHARP' -- "$TARGET"
#!/usr/bin/env dotnet-script
#r "nuget: Microsoft.CodeAnalysis.CSharp, 4.9.0"
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using System.Text.Json;

var code = File.ReadAllText(Args[0]);
var tree = CSharpSyntaxTree.ParseText(code);
var root = await tree.GetRootAsync();

var classes = root.DescendantNodes().OfType<ClassDeclarationSyntax>()
    .Select(c => new {
        name = c.Identifier.Text,
        line = tree.GetLineSpan(c.Span).StartLinePosition.Line + 1,
        methods = c.Members.OfType<MethodDeclarationSyntax>()
            .Select(m => m.Identifier.Text).ToList()
    });

var output = new { classes = classes.ToList() };
Console.WriteLine(JsonSerializer.Serialize(output));
CSHARP

# Fallback: dotnet build output (siempre disponible)
dotnet build --no-incremental "$TARGET_DIR" 2>&1 | grep -E "^.*\.cs\(" | head -100
```

### Go — go/doc + go list

```bash
# Extracción estructural Go
go doc -all -json "$PACKAGE" 2>/dev/null || \
go list -json "$PACKAGE_PATH" | jq '{
  package: .Name,
  imports: .Imports,
  go_files: .GoFiles
}'

# Con gopls (language server — más completo)
gopls symbols "$TARGET" 2>/dev/null | \
  jq -R 'split(":") | {name: .[0], kind: .[1], line: .[2]}'
```

### Java — javap + java-parser (opcional)

```bash
# Si compilado: javap para API surface
javap -p "$CLASS_FILE" 2>/dev/null | \
  grep -E "^(public|protected|private|class|interface)" | head -50

# Código fuente con regexes estructurales (fallback universal)
grep -nE "^(public|protected|private).*class |^.*def |^.*fun " "$TARGET" | \
  awk -F: '{print "{\"line\":"$1",\"signature\":\""$2"\"}"}'
```

### Rust — syn (via cargo-expand) + cargo check

```bash
# Cargo check para estructura
cargo check --message-format json 2>&1 | \
  jq 'select(.reason == "compiler-artifact") | {
    name: .target.name,
    kind: .target.kind,
    src: .target.src_path
  }'

# Extracción de items públicos
grep -nE "^pub (fn|struct|enum|trait|impl|mod) " "$TARGET" | \
  awk -F: '{print "{\"line\":"$1",\"item\":\""$2"\"}"}'
```

### Ruby — rubocop AST

```bash
# rubocop con AST output
rubocop --only Naming --format json "$TARGET" 2>/dev/null | \
  jq '[.files[].offenses[] | {name: .message, line: .location.line}]'

# Extracción estructural con ruby-parse (gem: parser)
ruby-parse --emit-json "$TARGET" 2>/dev/null | \
  python3 -c "import sys,json; tree=json.load(sys.stdin); print(tree)"

# Fallback: extracción por regex
grep -nE "^(class|def|module) " "$TARGET" | \
  awk -F: '{print "{\"line\":"$1",\"declaration\":\""$2"\"}"}'
```

### PHP — PHP-Parser CLI

```bash
# php-parser (composer global require nikic/php-parser)
php - <<'PHP' "$TARGET"
<?php
require_once($_SERVER['HOME'] . '/.composer/vendor/autoload.php');
use PhpParser\ParserFactory;
$code = file_get_contents($argv[1]);
$parser = (new ParserFactory)->createForHostVersion();
$stmts = $parser->parse($code);
$result = ['classes' => [], 'functions' => []];
foreach ($stmts as $stmt) {
    if ($stmt instanceof PhpParser\Node\Stmt\Class_)
        $result['classes'][] = ['name' => $stmt->name->toString(), 'line' => $stmt->getLine()];
    if ($stmt instanceof PhpParser\Node\Stmt\Function_)
        $result['functions'][] = ['name' => $stmt->name->toString(), 'line' => $stmt->getLine()];
}
echo json_encode($result);
PHP

# Fallback phpstan
phpstan analyse --error-format=json "$TARGET" 2>/dev/null
```

### Swift — SourceKitten (estructura + docs)

```bash
# sourcekitten (brew install sourcekitten)
sourcekitten structure --file "$TARGET" | \
  jq '[.key.substructure[]? | {
    name: .["key.name"],
    kind: .["key.kind"],
    line: .["key.line"]
  }]'
```

### Kotlin — detekt + Kotlin compiler

```bash
# Detekt con reglas de estructura
detekt --input "$TARGET" --report json:detekt-structure.json 2>/dev/null
cat detekt-structure.json | jq '[.issues[] | {name: .ruleId, line: .location.source.line}]'

# Fallback: kotlinc -script para análisis
grep -nE "^(class|fun|object|interface|data class) " "$TARGET" | \
  awk -F: '{print "{\"line\":"$1",\"declaration\":\""$2"\"}"}'
```

### Dart / Flutter — dart analyze + ast

```bash
dart analyze --format=json "$TARGET" 2>/dev/null | \
  jq '.diagnostics[] | {message: .message, line: .location.range.start.line}'

# Extracción estructural
grep -nE "^(class |abstract class |mixin |extension |void |Future<|Stream<)" "$TARGET" | \
  head -50 | awk -F: '{print "{\"line\":"$1",\"declaration\":\""$2"\"}"}'
```

### Terraform — terraform validate + tflint

```bash
# Estructura de recursos Terraform
tflint --format json "$DIR" 2>/dev/null | jq '.issues[]'

# Extracción de recursos y módulos
grep -nE "^(resource|module|data|variable|output) " "$TARGET.tf" | \
  awk '{print "{\"type\":\""$1"\",\"name\":\""$2"\",\"line\":NR}"}' | head -100
```

## Universal: Tree-sitter (todos los lenguajes)

```bash
# Instalar: npm install -g tree-sitter-cli
# + grammars por lenguaje: npm install tree-sitter-python tree-sitter-typescript ...

# Parse estructural
tree-sitter parse "$TARGET" --output json 2>/dev/null | \
  python3 - <<'EOF'
import sys, json

def extract_structure(node, result=None):
    if result is None:
        result = {"classes": [], "functions": [], "imports": []}

    if node.get("type") in ("class_definition", "class_declaration"):
        name_node = next((c for c in node.get("children", [])
                         if c.get("type") in ("identifier", "name")), None)
        if name_node:
            result["classes"].append({
                "name": name_node.get("text", ""),
                "line": node.get("startPosition", {}).get("row", 0) + 1
            })

    if node.get("type") in ("function_definition", "function_declaration", "method_definition"):
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
EOF
```

## Extracción por grep-estructural (fallback universal, 0 dependencias)

```bash
# Detecta clases y funciones en CUALQUIER lenguaje por patrones comunes
# Cobertura ~70% — suficiente para orientación

grep -nE \
  "(^(public|private|protected|async|export).*\s+(class|interface|function|def|fn|func)\s+\w+|\
^(class|def|func|fun|fn|function|interface|module|trait|impl)\s+\w+|\
^\s*(pub|private|protected)\s+(fn|func|function|def)\s+\w+)" \
  "$TARGET" | head -100 | \
  awk -F: '{
    gsub(/^[[:space:]]+/, "", $2);
    printf "{\"line\":%d,\"declaration\":\"%s\"}\n", $1, $2
  }'
```

## Análisis de imports (universal)

```bash
# Detecta imports en todos los lenguajes
grep -nE \
  "(^(import|from|require|use|using|include|#include|extern crate)\s+)" \
  "$TARGET" | head -50 | \
  awk -F: '{printf "{\"line\":%d,\"import\":\"%s\"}\n", $1, $2}'
```

## Métricas de complejidad ciclomática (aproximación universal)

```bash
# Cuenta puntos de decisión: if, for, while, case, &&, ||, ?:, catch
COMPLEXITY=$(grep -cE \
  "(if\s*\(|else if\s*\(|for\s*\(|while\s*\(|switch\s*\(|\bcase\b|\bcatch\b|\&\&|\|\||\?[^:])" \
  "$TARGET" 2>/dev/null || echo "0")
echo "{\"cyclomatic_approx\": $COMPLEXITY}"
```
