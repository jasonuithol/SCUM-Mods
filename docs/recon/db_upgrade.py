import sqlite3, os, shutil, time

SF = os.path.join(os.environ['LOCALAPPDATA'], 'SCUM', 'Saved', 'SaveFiles')
DB = os.path.join(SF, 'SCUM.db')
BK = os.path.join(SF, 'SCUM.db.preupgrade-' + time.strftime('%Y%m%d%H%M%S'))

shutil.copy2(DB, BK)
print("backup created:", os.path.basename(BK))

con = sqlite3.connect(DB, timeout=10)
cur = con.cursor()
cur.execute("PRAGMA wal_checkpoint(TRUNCATE)")  # merge WAL into main db

# valid cement targets = cement assets that actually exist in this save
valid_cement = set(a for (a,) in cur.execute(
    "SELECT DISTINCT asset FROM base_element WHERE asset LIKE '%Cement%'"))

BID = 2
rows = cur.execute(
    "SELECT element_id, asset FROM base_element WHERE base_id=? AND asset LIKE '%Twig%'",
    (BID,)).fetchall()

changes, skipped = [], []
for eid, a in rows:
    if 'Ladder' in a or 'CamoNet' in a:
        skipped.append((eid, a.split('/')[-1].split('.')[0], 'no upgrade path')); continue
    cem = a.replace('BP_Base_Modular_', 'BPC_Base_Modular_').replace('_Twig', '_Cement')
    if cem in valid_cement:
        changes.append((eid, cem))
    else:
        skipped.append((eid, a.split('/')[-1].split('.')[0], 'no valid cement target: ' + cem.split('/')[-1].split('.')[0]))

for eid, cem in changes:
    cur.execute("UPDATE base_element SET asset=? WHERE element_id=? AND base_id=?", (cem, eid, BID))
con.commit()

print(f"\n=== UPGRADED {len(changes)} elements (base {BID}) Twig -> Cement ===")
for eid, cem in changes:
    print("   id", eid, "->", cem.split('/')[-1].split('.')[0])
print(f"\n=== skipped {len(skipped)} ===")
for eid, nm, why in skipped:
    print("   id", eid, nm, "--", why)

# verify
print("\n=== base 2 tier histogram AFTER ===")
from collections import Counter
TIERS=('Twig','Wood','Metal','Brick','Cement')
def tier(a):
    for t in TIERS:
        if t in a: return t
    return '?'
h = Counter(tier(a) for (a,) in cur.execute("SELECT asset FROM base_element WHERE base_id=2"))
print("  ", dict(h))
con.close()
