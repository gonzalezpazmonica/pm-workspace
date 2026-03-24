# Adversarial: obfuscated SQL injection via format string
# Harder to detect than simple concatenation

import sqlite3

def search_users(conn, filters: dict):
    """Search users with dynamic filters."""
    base = "SELECT id, name, email FROM users WHERE 1=1"
    params = []

    if "name" in filters:
        # VULNERABLE: f-string injection disguised as "safe" pattern
        base += f" AND name LIKE '%{filters['name']}%'"

    if "role" in filters:
        # SAFE: proper parameterization
        base += " AND role = ?"
        params.append(filters["role"])

    if "active" in filters:
        # SAFE: boolean, not user input
        base += " AND active = 1"

    cursor = conn.cursor()
    cursor.execute(base, params)
    return cursor.fetchall()
