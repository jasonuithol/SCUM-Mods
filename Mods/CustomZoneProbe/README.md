# CustomZoneProbe (recon + proven recipe)

A **disposable** UE4SS server mod used to reverse-engineer SCUM's custom-zone
(map markup) system for the "Discord → server → all clients see a map marker"
feature. It started read-only and now also holds the **proven, crash-free recipe**
for broadcasting a live colored circle to every connected client's map.

Server-side only; no client files, so it coexists with BattlEye.

## The proven recipe (what works)

A server-side mod can put a transient colored circle on **all clients' maps** via:

1. `reg = GameState._customZoneRegistry` (`FindFirstOf("ConZGameState")` →
   `_customZoneRegistry`).
2. `global = reg._defaultGlobalConfiguration` — pass the **real** struct as-is.
3. `configs = { reg._defaultConfiguration, pingCfg }` — index 0 is the **real**
   config (so existing trader/outpost zones keep their color); index 1 is a
   **hand-built** config for the ping.
4. `regions = <all existing regions, real structs> + <our ping region>` — always
   re-send the existing zones, because the multicast **replaces** the client's
   whole set. The ping region points at `ConfigurationIndex = 1`.
5. `reg:NetMulticast_ReceiveCustomZoneData(global, configs, regions)`.

### Hard-won gotchas (do not relearn these the crashy way)

- **Never hand-build a struct that has an `FName` field.** Marshalling an `FName`
  from a Lua string crashes the server natively (uncatchable). So our region
  **omits** `UniqueDefaultZoneName`, and our config **omits** it too. `FString`,
  `FVector2D`, `FLinearColor`, enums and scalars all marshal fine from Lua tables.
- **A hand-built config is fine** as long as it omits the `FName` (and
  `DamageEventHandlingMethod`, which zero-inits to an empty list). Use it for the
  ping color so you never mutate the registry's real config (mutating that turns
  the outposts the same color, permanently until restart).
- **The multicast replaces the entire displayed zone set** — re-send existing
  zones every time or they blink out.
- **Coordinates are raw world centimetres**; `Size.X` = circle radius (cm),
  `Size.Y` = 0. Use a visible radius (500 m works; 100 m showed nothing).
- Reusing a **real** struct (read from a property) inside a Lua array marshals to
  a `TArray` correctly; reading the same property twice does **not** give an
  independent copy (so don't recolor a re-read config — it's shared).

## Chat commands (admin)

| Command | Does |
|---|---|
| `zonedump` | Walk `GameState._customZoneRegistry`, log every config/region + caller world pos |
| `zonetest` | Broadcast a **red** ping circle at the caller (keeps existing zones; auto-clears after `PING_EXPIRE_SEC`) |
| `zoneclear` | Multicast an empty set (transient wipe) |
| `zonebisect` / `zonebisect2` | Diagnostic ladders used to isolate the crash to the `FName` field |

The two RPC hooks (`CustomZones_Server_UpdateCustomZoneData` /
`CustomZones_Client_ReceiveCustomZoneData`) also log any zone traffic they see.

Tunables at the top of `Scripts/main.lua`: `PING_RADIUS_CM`, `PING_EXPIRE_SEC`,
`WRITE_TEST_ENABLED`.

## Install

1. Reuse the RE-UE4SS install from MapPing/the other mods (its bundled
   `UE4SS-settings-SCUM.ini` enables `HookProcessInternal` +
   `HookProcessLocalScriptFunction`, which the hooks need).
2. Copy this `CustomZoneProbe\` folder into `...\SCUM\Binaries\Win64\ue4ss\Mods\`.
3. Edit `MOD_DIR` at the top of `Scripts\main.lua` to match your server path.
4. Add `CustomZoneProbe : 1` to `ue4ss\Mods\mods.txt` (**not** `enabled.txt`).
5. Restart the server, join as an **admin**, type `zonetest`.

## Status

Recon scaffolding — **not** a shipped feature. The recipe above is being folded
into the **MapPing** mod (+ its sidecar) to drive pings from Discord buttons.
Delete the `CustomZoneProbe : 1` line from `mods.txt` once that lands.
