def find_user(cur, name: str):
    cur.execute("SELECT * FROM users WHERE name = %s", (name,))
    return cur.fetchone()
