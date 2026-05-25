import sqlite3, os
from collections import Counter

DB = os.path.join(os.environ['LOCALAPPDATA'], 'SCUM', 'Saved', 'SaveFiles', 'SCUM.db')
con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True, timeout=5)
cur = con.cursor()

TIERS = ('Twig','Wood','Metal','Brick','Cement')
def tier_of(a):
    for t in TIERS:
        if t in a: return t
    return '?'
def shape(a):
    return a.split('/')[-1].split('.')[0].replace('BP_Base_Modular_','').replace('BP_Base_','')

BID = 2
rows = cur.execute("SELECT element_id, asset FROM base_element WHERE base_id=? ORDER BY element_id", (BID,)).fetchall()
print(f"=== base {BID}: {len(rows)} elements ===")
print("tier histogram:", dict(Counter(tier_of(a) for _,a in rows)))

twig_ids = [eid for eid,a in rows if 'Twig' in a]
print(f"\nTWIG element_ids ({len(twig_ids)}):")
print(twig_ids)
print("\nTWIG detail:")
for eid,a in rows:
    if 'Twig' in a:
        print(f"   {eid:<5} {shape(a)}")

# sample one twig's full asset path (for reference / spawn route later)
for eid,a in rows:
    if 'Twig' in a:
        print("\nsample twig asset path:", a); break

con.close()
