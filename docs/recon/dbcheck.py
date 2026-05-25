import sqlite3, os
DB = os.path.join(os.environ['LOCALAPPDATA'], 'SCUM', 'Saved', 'SaveFiles', 'SCUM.db')
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=5)
cur = con.cursor()
print("=== ALL distinct assets in base 2 (with count) ===")
for a, n in cur.execute(
    "SELECT asset, COUNT(*) FROM base_element WHERE base_id=2 GROUP BY asset ORDER BY asset"):
    print(f"  x{n}  {a}")
con.close()
