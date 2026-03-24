# Golden set: SQL injection vulnerability (CWE-89)
# Agent MUST detect the unsanitized user input in the query

import sqlite3

def get_user(username):
    conn = sqlite3.connect("users.db")
    cursor = conn.cursor()
    # VULNERABLE: string concatenation in SQL query
    query = "SELECT * FROM users WHERE name = '" + username + "'"
    cursor.execute(query)
    return cursor.fetchall()

def get_user_safe(username):
    conn = sqlite3.connect("users.db")
    cursor = conn.cursor()
    # SAFE: parameterized query
    cursor.execute("SELECT * FROM users WHERE name = ?", (username,))
    return cursor.fetchall()
