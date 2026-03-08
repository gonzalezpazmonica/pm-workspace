---
description: Regla cross-cutting de separación de marcado y lógica
globs:
context: on-demand
---

# Separación de Marcado, Consultas y Estilos — Regla Transversal

> Aplica a **todos** los lenguajes. Complementa las reglas de arquitectura específicas de cada language pack.
> Última actualización: 2026-03-08

---

## Principio

El código de aplicación **NUNCA** debe contener marcado (HTML/XML), hojas de estilo (CSS) ni consultas (SQL/GraphQL) embebidos como cadenas literales. Cada capa vive en su propio fichero con su propia extensión.

**Motivación**: separar responsabilidades permite cachear assets, reutilizar plantillas, aplicar linting específico a cada capa y evitar errores de escaping.

---

## Reglas REJECT (bloquean PR / commit)

### SEP-01 — HTML embebido en código backend

**Severidad**: Critical · **Tags**: separation-of-concerns, maintainability

Código de servidor (Python, Java, C#, Go, Ruby, PHP, Rust) no debe construir HTML mediante concatenación de strings ni f-strings.

```python
# ❌ Noncompliant
def install_page():
    return f"<html><body><h1>{title}</h1></body></html>"

# ✅ Compliant — template externo
def install_page():
    template = load_template("install.html")
    return template.replace("{{title}}", title)
```

```csharp
// ❌ Noncompliant
return $"<div class='card'>{user.Name}</div>";

// ✅ Compliant — Razor view
return View("UserCard", user);
```

**Excepción**: snippets de ≤ 1 línea para respuestas de error simples (ej: `<h1>404</h1>`).

---

### SEP-02 — CSS embebido en código backend

**Severidad**: Major · **Tags**: separation-of-concerns

Estilos CSS no deben definirse como strings en código de servidor.

```python
# ❌ Noncompliant
style = "color: red; font-size: 14px;"
html = f"<div style='{style}'>{content}</div>"

# ✅ Compliant — fichero .css separado + clase
# styles.css → .error { color: red; font-size: 14px; }
# template.html → <div class="error">{{content}}</div>
```

**Excepción**: variables CSS generadas dinámicamente para temas (custom properties).

---

### SEP-03 — SQL como strings literales (sin parametrizar)

**Severidad**: Blocker · **Tags**: security, sql-injection

Consultas SQL deben usar parámetros vinculados, nunca interpolación de strings.

```python
# ❌ Noncompliant
query = f"SELECT * FROM users WHERE id = {user_id}"

# ✅ Compliant — parámetros vinculados
query = "SELECT * FROM users WHERE id = ?"
cursor.execute(query, (user_id,))
```

```java
// ❌ Noncompliant
String sql = "SELECT * FROM users WHERE name = '" + name + "'";

// ✅ Compliant — PreparedStatement
String sql = "SELECT * FROM users WHERE name = ?";
stmt.setString(1, name);
```

**Nota**: esto ya se cubre en las reglas de seguridad (SQL injection), pero se refuerza aquí como principio de separación.

---

### SEP-04 — Ficheros monolíticos con múltiples responsabilidades

**Severidad**: Major · **Tags**: srp, separation-of-concerns

Un fichero de código no debe mezclar:
- Lógica HTTP (handlers/controllers) + lógica de negocio + acceso a datos + presentación

Cada responsabilidad va en su propio módulo/fichero.

```python
# ❌ Noncompliant — un solo fichero con todo
class MyServer:
    def handle_request(self):
        data = db.query("SELECT ...")       # Acceso a datos
        result = complex_calculation(data)   # Lógica de negocio
        return f"<html>{result}</html>"      # Presentación

# ✅ Compliant — separado por capas
# repository.py  → def get_data(): ...
# service.py     → def calculate(data): ...
# handler.py     → def handle(): return render("template.html", service.calculate(...))
```

---

## Reglas PREFER (sugerencias)

### SEP-05 — Usar motores de templates del ecosistema

**Severidad**: Minor · **Tags**: best-practice

Cuando el proyecto necesite renderizar HTML, usar el motor de templates nativo del framework o ecosistema:

| Lenguaje/Framework | Motor recomendado |
|-------------------|-------------------|
| Python (FastAPI) | Jinja2 |
| Python (Django) | Django Templates |
| Python (stdlib) | `string.Template` o ficheros `.html` con `.replace()` |
| Java (Spring) | Thymeleaf |
| C# (ASP.NET) | Razor |
| Go | `html/template` |
| Ruby (Rails) | ERB / Slim |
| PHP (Laravel) | Blade |
| Rust (Actix/Axum) | Askama / Tera |
| Node.js (Express) | EJS / Handlebars / Pug |

### SEP-06 — GraphQL schemas en ficheros `.graphql`

**Severidad**: Minor

Definir schemas GraphQL en ficheros `.graphql` separados, no como strings multilínea en código.

---

## Aplicabilidad

Esta regla se aplica a:
- Todo código nuevo
- Código existente cuando se modifica (boy scout rule)
- Scripts de infraestructura (Bridge, CLI wrappers, etc.)

No se aplica a:
- Tests con HTML/SQL de fixture (contenido de prueba)
- DSLs explícitos (OpenAPI specs inline, migrations de DB)
- Ficheros de configuración (CSS variables en Python para temas)
- CLI tools con output formateado (`--format html` como feature)
