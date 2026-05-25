import sqlite3, os
DB = os.path.join(os.environ['LOCALAPPDATA'], 'SCUM', 'Saved', 'SaveFiles', 'SCUM.db')
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=5)
cur = con.cursor()

tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
kw = ('prisoner','character','user','player','account','profile')
rel = [t for t in tables if any(k in t.lower() for k in kw)]
print("candidate player tables:", rel)

for t in rel:
    cols = [c[1] for c in cur.execute(f"PRAGMA table_info('{t}')").fetchall()]
    # only show tables that have a location-ish column
    loc_cols = [c for c in cols if 'location' in c.lower() or c.lower() in ('x','y','z','pos_x')]
    has_id = [c for c in cols if 'profile' in c.lower() or c.lower()=='id' or 'user' in c.lower()]
    try:
        n = cur.execute(f"SELECT COUNT(*) FROM '{t}'").fetchone()[0]
    except Exception:
        n = '?'
    print(f"\n## {t}  rows={n}")
    print("   cols:", cols)
    if loc_cols:
        print("   LOCATION cols:", loc_cols, " ID-ish:", has_id)
        # sample a couple rows with id + location
        sel = ", ".join(has_id[:2] + loc_cols[:3])
        try:
            for row in cur.execute(f"SELECT {sel} FROM '{t}' LIMIT 3"):
                print("     ", row)
        except Exception as e:
            print("     (err:", e, ")")
con.close()
