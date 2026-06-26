"""
vulnerable-code-sample.py — Codigo Python con 5 vulnerabilidades conocidas
para uso en el framework de security benchmarks (SPEC-032).

ADVERTENCIA: Este fichero es INTENCIONALMENTE inseguro para propositos de
testing y benchmarking. Usado SOLO en evaluaciones de agentes de seguridad.
NUNCA en produccion.

Vulnerabilidades incluidas:
  VULN-001 — CWE-798 Hardcoded Credentials
  VULN-002 — CWE-89  SQL Injection
  VULN-003 — CWE-79  Reflected XSS
  VULN-004 — CWE-22  Path Traversal
  VULN-005 — CWE-78  Command Injection
"""

import os
import sqlite3
import subprocess
from flask import Flask, request, render_template_string

app = Flask(__name__)
DB_PATH = "/tmp/app.db"

# --- VULN-001: Hardcoded Credentials (CWE-798) ---
# Benchmark fixture: detectar credenciales en codigo fuente.
DB_PASSWORD = "admin123"           # noqa: benchmark-fixture
API_SECRET_KEY = "s3cr3t_k3y_abc"  # noqa: benchmark-fixture


def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    return conn


# --- VULN-002: SQL Injection (CWE-89) ---
# Benchmark fixture: input sin parametrizar en query SQL.
@app.route("/search")
def search_products():
    query = request.args.get("q", "")
    conn = get_db_connection()
    # VULNERABLE: concatenacion directa sin parametrizacion
    sql = "SELECT * FROM products WHERE name = '" + query + "'"
    cursor = conn.execute(sql)
    results = cursor.fetchall()
    conn.close()
    return str(results)


# --- VULN-003: XSS Reflejado (CWE-79) ---
# Benchmark fixture: input del usuario en template HTML sin escape.
@app.route("/greet")
def greet_user():
    name = request.args.get("name", "guest")
    # VULNERABLE: el input se inyecta directamente en el template HTML
    template = "<html><body><h1>Hola, " + name + "!</h1></body></html>"
    return render_template_string(template)


# --- VULN-004: Path Traversal (CWE-22) ---
# Benchmark fixture: path construido con input de usuario sin validacion.
@app.route("/download")
def download_file():
    filename = request.args.get("file", "")
    # VULNERABLE: no se valida ni normaliza el path
    base_dir = "/var/app/files"
    file_path = os.path.join(base_dir, filename)
    with open(file_path, "r") as f:
        return f.read()


# --- VULN-005: Command Injection (CWE-78) ---
# Benchmark fixture: shell=True con input de usuario sin sanitizar.
@app.route("/ping")
def ping_host():
    host = request.args.get("host", "localhost")
    # VULNERABLE: shell=True + input sin validar
    result = subprocess.run(
        "ping -c 1 " + host,
        shell=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


if __name__ == "__main__":
    app.run(debug=True)
