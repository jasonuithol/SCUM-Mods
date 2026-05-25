#!/usr/bin/env python3
"""
SCUM base tier tool -- offline edit of SCUM.db base_element.asset (= tier).

Scope: the target player's OWN flag(s).
  sandbox: base.is_owned_by_player = 1   (no --playerid)
  server : base.owner_user_profile_id = --playerid

Target (pick ONE):
  --tier NAME   absolute: set every element to NAME (twig/wood/metal/brick/cement),
                clamped to each shape's cap (e.g. doors stop at Metal).
  --levels N    relative: raise N tiers (negative = downgrade), clamped per shape.

Valid (shape,tier) classes are learned from the live DB UNION every SCUM*.db backup
in SaveFiles -- so the tool still knows the full tier chain even after a downgrade
wiped the higher-tier asset strings out of the live DB (chain-sound: if a tier is
valid, all lower tiers are too).

  python db_tier.py --tier brick [--playerid ID] [--apply]
  python db_tier.py --levels -5  [--playerid ID] [--apply]

SCUM must be fully CLOSED before --apply (backs up first; reload world to see it).
"""
import sqlite3, os, shutil, time, argparse, glob, sys

HELP = r"""
SCUM base tier tool -- offline edit of base element tiers in SCUM.db

  python db_tier.py (--tier NAME | --levels N) [--playerid ID] [--apply] [--db PATH]

TARGET TIER -- pick exactly one (required):
  --tier NAME   Absolute. Set every element to NAME:
                  twig | wood | metal | brick | cement
                Clamped to each shape's cap (e.g. doors stop at metal).
                Use this when the base is a mix of tiers.
  --levels N    Relative. Raise each element N tiers; NEGATIVE downgrades
                (e.g. 5 = up 5, -5 = down 5). Clamped per shape [Twig .. shape max].

OPTIONAL:
  --playerid ID  Server mode: target bases owned by user_profile_id ID.
                 Omit  -> sandbox mode (your is_owned_by_player flag).
  --apply        Actually write. WITHOUT it = dry-run (preview only, read-only,
                 safe even while SCUM is running).
  --db PATH      Use a different SCUM.db (default: your local save).

SAFETY (with --apply): refuses if SCUM is open, backs up first
(SCUM.db.bak-<timestamp>), then writes. Reload the world to see changes.
Scope is always ONE player's own flag(s).

EXAMPLES:
  python db_tier.py --tier cement                       preview upgrade to cement
  python db_tier.py --tier cement --apply               do it (SCUM closed)
  python db_tier.py --levels -5 --apply                 strip base back to twig
  python db_tier.py --tier brick --playerid 9 --apply   server: player 9 -> brick
"""

TIERS = ['Twig', 'Wood', 'Metal', 'Brick', 'Cement']
TIDX = {t: i for i, t in enumerate(TIERS)}
SAVEDIR = os.path.join(os.environ['LOCALAPPDATA'], 'SCUM', 'Saved', 'SaveFiles')

def parse_asset(asset):
    if '/Modular/' not in asset:
        return None
    d, fname = asset.rsplit('/', 1)
    cn = fname.split('.', 1)[0]
    for pref in ('BPC_Base_Modular_', 'BP_Base_Modular_'):
        if cn.startswith(pref):
            rest = cn[len(pref):]
            if '_' not in rest:
                return None
            shape, tier = rest.rsplit('_', 1)
            if tier not in TIDX:
                return None
            return (d, shape, TIDX[tier])
    return None

def build_asset(d, shape, tidx):
    pref = 'BP_Base_Modular_' if tidx == 0 else 'BPC_Base_Modular_'
    cn = f"{pref}{shape}_{TIERS[tidx]}"
    return f"{d}/{cn}.{cn}_C"

def collect_valid_assets(live_db):
    """Union of base_element.asset across the live DB and every backup in SaveFiles."""
    paths = [live_db]
    for pat in ('SCUM.db.bak-*', 'SCUM.db.preupgrade-*', 'SCUM_*.db-backup'):
        paths += glob.glob(os.path.join(SAVEDIR, pat))
    valid, used = set(), 0
    for p in paths:
        try:
            c = sqlite3.connect(f"file:{p}?mode=ro", uri=True, timeout=3)
            for (a,) in c.execute("SELECT DISTINCT asset FROM base_element"):
                valid.add(a)
            c.close(); used += 1
        except Exception:
            pass
    return valid, used

def main():
    if len(sys.argv) == 1:          # no parameters -> print the help table and exit
        print(HELP)
        return
    ap = argparse.ArgumentParser(add_help=True)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--tier', choices=[t.lower() for t in TIERS])
    g.add_argument('--levels', type=int)
    ap.add_argument('--playerid', type=int, default=None)
    ap.add_argument('--apply', action='store_true')
    ap.add_argument('--db', default=os.path.join(SAVEDIR, 'SCUM.db'))
    a = ap.parse_args()

    if a.apply:
        try:
            t = sqlite3.connect(a.db, timeout=2); t.execute('BEGIN IMMEDIATE'); t.rollback(); t.close()
        except sqlite3.OperationalError as e:
            print(f"ABORT: DB is locked -- close SCUM fully before --apply.  ({e})"); return

    VALID, nsrc = collect_valid_assets(a.db)
    print(f"valid-asset catalog: {len(VALID)} classes from {nsrc} DB source(s)")

    if a.apply:
        con = sqlite3.connect(a.db, timeout=10); cur = con.cursor()
        cur.execute('PRAGMA wal_checkpoint(TRUNCATE)')
    else:
        con = sqlite3.connect(f"file:{a.db}?mode=ro", uri=True, timeout=5); cur = con.cursor()

    if a.playerid is not None:
        bases = [(r[0], r[1]) for r in cur.execute("SELECT id,name FROM base WHERE owner_user_profile_id=?", (a.playerid,))]
        mode = f"SERVER playerid={a.playerid}"
    else:
        bases = [(r[0], r[1]) for r in cur.execute("SELECT id,name FROM base WHERE is_owned_by_player=1")]
        mode = "SANDBOX (is_owned_by_player=1)"

    tgt = f"tier={a.tier}" if a.tier else f"levels={a.levels:+d}"
    print(f"mode: {mode}   {tgt}   [{'APPLY' if a.apply else 'DRY-RUN'}]")
    print(f"target flags: {[f'{n}(id {i})' for i,n in bases]}")
    if not bases:
        print("no target flags found."); con.close(); return

    if a.apply:
        bk = a.db + '.bak-' + time.strftime('%Y%m%d%H%M%S')
        shutil.copy2(a.db, bk); print("backup:", os.path.basename(bk))

    total = 0
    for bid, bname in bases:
        rows = cur.execute("SELECT element_id, asset FROM base_element WHERE base_id=?", (bid,)).fetchall()
        changes = []
        for eid, asset in rows:
            p = parse_asset(asset)
            if not p:
                continue
            d, shape, cur_t = p
            maxt = 0
            for T in range(1, 5):
                if build_asset(d, shape, T) in VALID:
                    maxt = T
            if a.tier is not None:
                desired = min(TIDX[a.tier.capitalize()], maxt)
            else:
                desired = max(0, min(cur_t + a.levels, maxt))
            if desired != cur_t:
                changes.append((eid, shape, cur_t, desired, build_asset(d, shape, desired)))
        print(f"\n  flag '{bname}' (id {bid}): {len(changes)} element(s) change")
        for eid, shape, t0, t1, na in changes:
            print(f"     id={eid:<5} {shape:34s} {TIERS[t0]:6s} -> {TIERS[t1]}")
            if a.apply:
                cur.execute("UPDATE base_element SET asset=? WHERE element_id=? AND base_id=?", (na, eid, bid))
        total += len(changes)

    if a.apply:
        con.commit()
    print(f"\n{'APPLIED' if a.apply else 'WOULD CHANGE'} {total} element(s).", "" if a.apply else "(use --apply to write)")
    con.close()

main()
