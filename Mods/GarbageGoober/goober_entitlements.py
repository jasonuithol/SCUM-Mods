#!/usr/bin/env python3
"""GarbageGoober entitlement resolver.

The loot-sorter is gated PER PLAYER (and, as a fallback, per flag). A flag's
owner is not readable from the live actor, only from SCUM.db, and UE4SS Lua has
no SQLite -- so the mod shells out to THIS script to:

  * maintain the operator's entitlement store (entitlements.json),
  * read SCUM.db read-only (WAL-safe; works while the server runs),
  * resolve a player name / Steam64 -> Steam64 (the stable entitlement key),
  * compute the set of base IDs whose loot should be sorted, applying:
        per-flag override  >  player-entitled  >  global default
  * write goober_resolved.lua  (a `return {...}` table the mod load()s), and
  * write goober_reply.txt      (human lines the mod echoes to the admin's chat).

The base table's `id` equals the runtime ConZBaseManager._bases key, so the mod
gates each live flag by looking up resolved.enabled[baseId].

Untrusted free text (a player name typed in chat) is passed via --argfile, never
on the command line, so there is no shell-injection surface. Fixed sub-commands
and numeric base IDs are validated by the caller and here.

CLI:
  python goober_entitlements.py --db <SCUM.db> --dir <storedir> <command> [...]
    sync                         recompute resolved.lua only (no store change)
    status                       one-line summary
    list                         full listing of players / overrides / result
    add     --argfile <file>     entitle the player named/IDed in <file>
    remove  --argfile <file>     un-entitle that player
    flag    on|off|clear <id>    per-flag override (the fallback knob)
    default on|off               set the global default
"""

import sys
import os
import re
import json
import sqlite3
import datetime

STORE_NAME = "entitlements.json"
RESOLVED_NAME = "goober_resolved.lua"
REPLY_NAME = "goober_reply.txt"

STEAM64_RE = re.compile(r"^\d{17}$")


# ---- store -----------------------------------------------------------------

def store_path(d):
    return os.path.join(d, STORE_NAME)


def load_store(d):
    p = store_path(d)
    if os.path.exists(p):
        try:
            with open(p, "r", encoding="utf-8") as f:
                s = json.load(f)
        except Exception:
            s = {}
    else:
        s = {}
    s.setdefault("defaultEnabled", False)
    s.setdefault("players", [])          # list of Steam64 strings
    s.setdefault("flagOverrides", {})    # { "<baseId>": bool }
    # normalise
    s["players"] = [str(x) for x in s["players"]]
    s["flagOverrides"] = {str(k): bool(v) for k, v in s["flagOverrides"].items()}
    return s


def save_store(d, s):
    with open(store_path(d), "w", encoding="utf-8") as f:
        json.dump(s, f, indent=2)


# ---- DB --------------------------------------------------------------------

def db_connect(db):
    uri = "file:%s?mode=ro" % db.replace("\\", "/")
    return sqlite3.connect(uri, uri=True)


def fetch_owned_bases(db):
    """[(base_id, steam64|None, profile_name|None, account_name|None)] for player bases."""
    con = db_connect(db)
    try:
        cur = con.execute(
            """
            SELECT b.id, up.user_id, up.name, u.name
            FROM base b
            LEFT JOIN user_profile up ON up.id = b.owner_user_profile_id
            LEFT JOIN user u ON u.id = up.user_id
            WHERE b.is_owned_by_player = 1
            ORDER BY b.id
            """
        )
        return [(r[0], (str(r[1]) if r[1] is not None else None), r[2], r[3]) for r in cur.fetchall()]
    finally:
        con.close()


def resolve_player(db, arg):
    """Resolve a typed identity -> (steam64, display_name, found_in_db).

    Returns ('AMBIGUOUS', [(steam64,name),...], False) if a name matches several
    players, or (None, None, False) if nothing matched.
    """
    arg = arg.strip()
    if not arg:
        return (None, None, False)
    con = db_connect(db)
    try:
        if STEAM64_RE.match(arg):
            row = con.execute(
                "SELECT u.id, COALESCE(up.name, u.name) FROM user u "
                "LEFT JOIN user_profile up ON up.user_id = u.id WHERE u.id = ?",
                (arg,),
            ).fetchone()
            if row:
                return (str(row[0]), row[1], True)
            return (arg, None, False)  # valid-looking id, not in DB yet (pre-grant OK)
        # name match: in-game profile name OR steam account name, case-insensitive
        rows = con.execute(
            """
            SELECT DISTINCT u.id, COALESCE(up.name, u.name)
            FROM user u
            LEFT JOIN user_profile up ON up.user_id = u.id
            WHERE lower(up.name) = lower(?) OR lower(u.name) = lower(?)
            """,
            (arg, arg),
        ).fetchall()
        uniq = {}
        for sid, nm in rows:
            uniq[str(sid)] = nm
        if len(uniq) == 1:
            sid = next(iter(uniq))
            return (sid, uniq[sid], True)
        if len(uniq) > 1:
            return ("AMBIGUOUS", [(k, v) for k, v in uniq.items()], False)
        return (None, None, False)
    finally:
        con.close()


# ---- resolution + emit -----------------------------------------------------

def compute(store, bases):
    """-> (enabled_ids:set[int], rows:[(id,steam64,name,enabled,reason)])."""
    players = set(store["players"])
    overrides = store["flagOverrides"]
    default = bool(store["defaultEnabled"])
    enabled, rows = set(), []
    for bid, sid, pname, aname in bases:
        name = pname or aname or "?"
        key = str(bid)
        if key in overrides:
            en, reason = overrides[key], ("flag-override:%s" % ("on" if overrides[key] else "off"))
        elif sid is not None and sid in players:
            en, reason = True, "player-entitled"
        else:
            en, reason = default, ("default:%s" % ("on" if default else "off"))
        if en:
            enabled.add(int(bid))
        rows.append((bid, sid, name, en, reason))
    return enabled, rows


def _luastr(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_resolved_lua(d, store, enabled, rows, err=None):
    L = ["return {"]
    L.append("  generatedAt = %s," % _luastr(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")))
    L.append("  defaultEnabled = %s," % ("true" if store["defaultEnabled"] else "false"))
    L.append("  ok = %s," % ("false" if err else "true"))
    if err:
        L.append("  error = %s," % _luastr(err))
    L.append("  enabled = {")
    for bid in sorted(enabled):
        L.append("    [%d] = true," % int(bid))
    L.append("  },")
    L.append("  counts = { bases = %d, enabled = %d, players = %d, overrides = %d }," %
             (len(rows), len(enabled), len(store["players"]), len(store["flagOverrides"])))
    L.append("}")
    with open(os.path.join(d, RESOLVED_NAME), "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")


def write_reply(d, lines):
    with open(os.path.join(d, REPLY_NAME), "w", encoding="utf-8") as f:
        f.write("\n".join(str(x) for x in lines) + "\n")


def refresh(d, db, store):
    """Recompute + write resolved.lua. Returns (enabled, rows). Fail-closed on DB error."""
    try:
        bases = fetch_owned_bases(db)
        enabled, rows = compute(store, bases)
        write_resolved_lua(d, store, enabled, rows)
        return enabled, rows, None
    except Exception as e:
        write_resolved_lua(d, store, set(), [], err=str(e))
        return set(), [], str(e)


# ---- commands --------------------------------------------------------------

def name_for(rows, sid):
    for bid, s, name, en, reason in rows:
        if s == sid:
            return name
    return None


def cmd_list(d, db, store):
    enabled, rows, err = refresh(d, db, store)
    out = []
    out.append("GarbageGoober entitlements  (default: %s)" % ("ON" if store["defaultEnabled"] else "OFF"))
    if err:
        out.append("DB ERROR: %s" % err)
    # players
    players = store["players"]
    out.append("entitled players (%d):" % len(players))
    if not players:
        out.append("  (none)")
    for sid in players:
        nm = name_for(rows, sid) or "?"
        bids = sorted(int(r[0]) for r in rows if r[1] == sid)
        where = ("base " + ", ".join(str(b) for b in bids)) if bids else "no base yet"
        out.append("  %s  %s  -> %s" % (sid, nm, where))
    # overrides
    ov = store["flagOverrides"]
    out.append("flag overrides (%d):" % len(ov))
    if not ov:
        out.append("  (none)")
    for k in sorted(ov, key=lambda x: int(x)):
        out.append("  base %s -> %s" % (k, "ON" if ov[k] else "OFF"))
    out.append("result: %d of %d player-owned base(s) will be sorted" % (len(enabled), len(rows)))
    write_reply(d, out)


def cmd_status(d, db, store):
    enabled, rows, err = refresh(d, db, store)
    write_reply(d, [
        "default=%s  players=%d  overrides=%d  -> %d/%d base(s) sorted%s" % (
            "ON" if store["defaultEnabled"] else "OFF",
            len(store["players"]), len(store["flagOverrides"]),
            len(enabled), len(rows), ("  (DB ERROR)" if err else ""))
    ])


def cmd_add(d, db, store, arg):
    sid, name, found = resolve_player(db, arg)
    if sid == "AMBIGUOUS":
        lines = ["'%s' matches several players — add by Steam64:" % arg]
        for s, n in name:
            lines.append("  %s  %s" % (s, n))
        write_reply(d, lines)
        refresh(d, db, store)
        return
    if sid is None:
        write_reply(d, ["no player matched '%s' (try their Steam64 ID)" % arg])
        refresh(d, db, store)
        return
    if sid in store["players"]:
        write_reply(d, ["%s (%s) is already entitled" % (name or "?", sid)])
        refresh(d, db, store)
        return
    store["players"].append(sid)
    save_store(d, store)
    enabled, rows, err = refresh(d, db, store)
    bids = sorted(int(r[0]) for r in rows if r[1] == sid)
    tail = ("now sorting base " + ", ".join(str(b) for b in bids)) if bids else \
           ("no base owned yet" if found else "not seen on this server yet — will apply when they build")
    write_reply(d, ["entitled %s (%s) — %s" % (name or "?", sid, tail)])


def cmd_remove(d, db, store, arg):
    arg = arg.strip()
    # allow removing by exact Steam64 even if not in DB
    target = None
    if arg in store["players"]:
        target = arg
    else:
        sid, name, found = resolve_player(db, arg)
        if sid == "AMBIGUOUS":
            lines = ["'%s' matches several players — remove by Steam64:" % arg]
            for s, n in name:
                lines.append("  %s  %s" % (s, n))
            write_reply(d, lines)
            refresh(d, db, store)
            return
        if sid in store["players"]:
            target = sid
    if not target:
        write_reply(d, ["'%s' is not in the entitled list" % arg])
        refresh(d, db, store)
        return
    store["players"] = [p for p in store["players"] if p != target]
    save_store(d, store)
    refresh(d, db, store)
    write_reply(d, ["removed %s from entitled players" % target])


def cmd_flag(d, db, store, mode, base_id):
    key = str(int(base_id))
    if mode == "clear":
        if key in store["flagOverrides"]:
            del store["flagOverrides"][key]
            msg = "cleared override on base %s (back to player/default)" % key
        else:
            msg = "base %s had no override" % key
    else:
        store["flagOverrides"][key] = (mode == "on")
        msg = "base %s override set to %s" % (key, mode.upper())
    save_store(d, store)
    refresh(d, db, store)
    write_reply(d, [msg])


def cmd_default(d, db, store, mode):
    store["defaultEnabled"] = (mode == "on")
    save_store(d, store)
    enabled, rows, err = refresh(d, db, store)
    write_reply(d, ["global default set to %s — %d/%d base(s) now sorted" %
                    (mode.upper(), len(enabled), len(rows))])


# ---- arg parsing -----------------------------------------------------------

def get_opt(argv, name):
    if name in argv:
        i = argv.index(name)
        if i + 1 < len(argv):
            return argv[i + 1]
    return None


def read_argfile(p):
    try:
        with open(p, "r", encoding="utf-8") as f:
            return f.read().strip()
    except Exception:
        return ""


def main(argv):
    db = get_opt(argv, "--db")
    d = get_opt(argv, "--dir")
    if not db or not d:
        print("usage: --db <SCUM.db> --dir <storedir> <command> ...", file=sys.stderr)
        return 2
    # positional command = first arg not starting with '-' and not an opt value
    opt_vals = set()
    for o in ("--db", "--dir", "--argfile"):
        v = get_opt(argv, o)
        if v is not None:
            opt_vals.add(v)
    pos = [a for a in argv if not a.startswith("--") and a not in opt_vals]
    cmd = pos[0] if pos else "sync"

    store = load_store(d)

    if cmd == "sync":
        refresh(d, db, store)
        write_reply(d, ["resynced"])
    elif cmd == "status":
        cmd_status(d, db, store)
    elif cmd == "list":
        cmd_list(d, db, store)
    elif cmd == "add":
        cmd_add(d, db, store, read_argfile(get_opt(argv, "--argfile")))
    elif cmd == "remove":
        cmd_remove(d, db, store, read_argfile(get_opt(argv, "--argfile")))
    elif cmd == "flag":
        mode = pos[1] if len(pos) > 1 else ""
        bid = pos[2] if len(pos) > 2 else ""
        if mode not in ("on", "off", "clear") or not re.match(r"^\d+$", str(bid)):
            write_reply(d, ["usage: goober flag on|off|clear <baseId>"])
        else:
            cmd_flag(d, db, store, mode, bid)
    elif cmd == "default":
        mode = pos[1] if len(pos) > 1 else ""
        if mode not in ("on", "off"):
            write_reply(d, ["usage: goober default on|off"])
        else:
            cmd_default(d, db, store, mode)
    else:
        write_reply(d, ["unknown resolver command: %s" % cmd])
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
