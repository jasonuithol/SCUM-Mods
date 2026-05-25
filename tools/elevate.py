#!/usr/bin/env python3
"""
elevate.py - grant/revoke SCUM "Elevated User" (developer-command) status by
editing the `elevated_users` table in a SCUM dedicated server's SCUM.db.

An elevated user gets ALL developer commands AND admin commands in-game
(e.g. #UpgradeBaseBuildingElementsWithinRadius) -- the legitimate, server-side
unlock for the dev-gated commands. (Connection/whitelist priority still comes
from AdminUser.ini; this only handles the dev-command grant.)

SAFETY (same pattern as tools/db_tier.py):
  - Dry-run by default; --apply is required to write.
  - Refuses to write if the DB is locked (i.e. the server is still running).
    ALWAYS stop the server first and wait for SCUM.db-wal / SCUM.db-shm to vanish.
  - Backs up SCUM.db to SCUM.db.bak-<timestamp> before any write.
  - Checkpoints the WAL into the main DB before editing.

Usage:
  python elevate.py --list
  python elevate.py 76561198000000000 [more ids ...]      # dry-run preview
  python elevate.py 76561198000000000 --apply             # add (writes)
  python elevate.py 76561198000000000 --remove --apply    # revoke (writes)
  python elevate.py --db "D:\\path\\SCUM.db" 765... --apply
"""
import argparse
import os
import shutil
import sqlite3
import time

DEFAULT_DB = r"C:\scumserver\SCUM\Saved\SaveFiles\SCUM.db"
TABLE = "elevated_users"
COL = "user_id"
STEAM64_MIN = 76561197960265728  # base of the individual SteamID64 range


def valid_steam64(s):
    return s.isdigit() and len(s) == 17 and int(s) >= STEAM64_MIN


def connect_ro(db):
    return sqlite3.connect(f"file:{db}?mode=ro", uri=True)


def table_exists(conn):
    return conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?", (TABLE,)
    ).fetchone() is not None


def current_ids(conn):
    return {r[0] for r in conn.execute(f"SELECT {COL} FROM {TABLE}")}


def schema_lines(conn):
    """Return PRAGMA table_info rows so we can sanity-check the column layout."""
    cols = conn.execute(f"PRAGMA table_info({TABLE})").fetchall()
    # cid, name, type, notnull, dflt_value, pk
    out = []
    for _, name, ctype, notnull, dflt, pk in cols:
        flags = []
        if pk:
            flags.append("pk")
        if notnull:
            flags.append("not-null")
        if dflt is not None:
            flags.append(f"default={dflt!r}")
        out.append(f"    {name} {ctype or ''} {'(' + ', '.join(flags) + ')' if flags else ''}".rstrip())
    return out


def cmd_list(db):
    with connect_ro(db) as conn:
        if not table_exists(conn):
            print(f"! Table '{TABLE}' not found in {db}")
            print("  Has the server booted at least once to generate the DB?")
            return 1
        print(f"'{TABLE}' columns:")
        for line in schema_lines(conn):
            print(line)
        ids = sorted(current_ids(conn))
    print(f"\nElevated users ({len(ids)}):")
    for i in (ids or ["  (none)"]):
        print(f"  {i}" if i.strip().isdigit() else i)
    return 0


def cmd_change(db, ids, remove, apply):
    bad = [i for i in ids if not valid_steam64(i)]
    if bad:
        for b in bad:
            print(f"! '{b}' is not a valid Steam64 ID (need 17 digits, >= {STEAM64_MIN}).")
        return 2

    with connect_ro(db) as conn:
        if not table_exists(conn):
            print(f"! Table '{TABLE}' not found in {db}")
            return 1
        existing = current_ids(conn)
        extra_required = [
            name for _, name, _, notnull, dflt, pk in
            conn.execute(f"PRAGMA table_info({TABLE})").fetchall()
            if notnull and dflt is None and not pk and name != COL
        ]

    action = "REMOVE" if remove else "ADD"
    if remove:
        targets = [i for i in ids if i in existing]
        skip = [i for i in ids if i not in existing]
    else:
        targets = [i for i in ids if i not in existing]
        skip = [i for i in ids if i in existing]

    print(f"DB: {db}")
    print(f"Currently {len(existing)} elevated user(s).")
    for i in skip:
        print(f"  - {i}: already {'absent' if remove else 'present'} -> skip")
    for i in targets:
        print(f"  * {i}: will {action}")

    if extra_required and not remove:
        print(f"\n! Heads up: '{TABLE}' has other NOT NULL column(s) with no default: "
              f"{', '.join(extra_required)}. A user_id-only INSERT may fail; if it does, "
              f"tell me the schema and I'll adjust.")

    if not targets:
        print("\nNothing to do.")
        return 0
    if not apply:
        print(f"\nDRY-RUN. Re-run with --apply to {action.lower()} {len(targets)} id(s).")
        return 0

    # ---- write path ----
    try:  # lock check: server must be stopped
        probe = sqlite3.connect(db, timeout=1.0)
        probe.execute("BEGIN IMMEDIATE")
        probe.execute("ROLLBACK")
        probe.close()
    except sqlite3.OperationalError as e:
        print(f"\n! Database is locked ({e}). Is the server still running?")
        print("  Stop it fully (wait for SCUM.db-wal / SCUM.db-shm to disappear) and retry.")
        return 1

    ts = time.strftime("%Y%m%d-%H%M%S")
    bak = f"{db}.bak-{ts}"
    shutil.copy2(db, bak)
    print(f"\nBacked up -> {bak}")

    conn = sqlite3.connect(db)
    conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    try:
        if remove:
            conn.executemany(f"DELETE FROM {TABLE} WHERE {COL}=?", [(i,) for i in targets])
        else:
            conn.executemany(f"INSERT OR IGNORE INTO {TABLE} ({COL}) VALUES (?)",
                             [(i,) for i in targets])
        conn.commit()
    except sqlite3.Error as e:
        conn.rollback()
        conn.close()
        print(f"! Write failed: {e}")
        print(f"  No harm done -- your backup is at {bak}.")
        return 1
    conn.close()
    print(f"{action}ED {len(targets)} id(s). Restart the server for it to take effect.")
    return 0


def main():
    p = argparse.ArgumentParser(
        description="Grant/revoke SCUM Elevated User (developer-command) status "
                    "via the elevated_users table in SCUM.db.")
    p.add_argument("ids", nargs="*", help="Steam64 ID(s) to add (or remove with --remove).")
    p.add_argument("--db", default=DEFAULT_DB, help=f"Path to SCUM.db (default: {DEFAULT_DB}).")
    p.add_argument("--remove", action="store_true", help="Remove the given IDs instead of adding.")
    p.add_argument("--apply", action="store_true", help="Actually write. Without it, dry-run.")
    p.add_argument("--list", action="store_true", help="List current elevated users and exit.")
    args = p.parse_args()

    if not os.path.exists(args.db):
        print(f"! DB not found: {args.db}")
        print("  Pass --db with the path to your server's SCUM.db "
              "(e.g. <install>\\SCUM\\Saved\\SaveFiles\\SCUM.db).")
        return 1

    if args.list or not args.ids:
        return cmd_list(args.db)
    return cmd_change(args.db, args.ids, args.remove, args.apply)


if __name__ == "__main__":
    raise SystemExit(main())
