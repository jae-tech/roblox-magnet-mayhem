# Magnet Mayhem

Milestone 1 Roblox/Luau prototype: automatic magnet attraction, a direct map Coin pickup, three metals,
server-validated selling, metal inventory, a coin-priced magnet shop and server-owned
DataStore persistence,
respawning objects and a minimal PC/mobile HUD.
No runtime dependencies, publishing or Robux purchases. Local Studio defaults to
**Preview mode: progress is not saved**; live servers use persistent profiles.

## Open the prototype

Use Rojo 7.x and the Rojo Studio plugin, or open a built place directly:

```powershell
rojo build default.project.json -o build/MagnetMayhem.rbxlx
rojo serve default.project.json
```

Create `build/` first if needed. Connect the plugin to `localhost:34872` in an
unpublished local place. Sync, press Play, then walk toward the three objects at
`(-20, 1.5, -24)`, `(0, 1.5, -24)`, `(20, 1.5, -24)`.
Each accepted metal pickup adds one Bolt, Can or Gear to inventory, with no immediate
coin reward. Objects return after 5 seconds. Use the `Inventory` HUD button to
show quantities and estimated sale value, then `Sell all` anywhere to empty the
inventory and receive Bolt/Can/Gear values of 1/3/5 coins per unit. The sale button
is disabled while empty; repeated empty sales grant nothing. There is no capacity
limit or selling zone. Coins and inventory survive character resets. In live
servers, saved progress loads on rejoin; default Studio Preview resets on leave
or Stop/Play. Collection is automatic; the red horseshoe is a
client-only magnet visual, initially the red Starter magnet.

A separate bright yellow neon `Coin` cylinder at `(0, 1.5, 24)` automatically
collects within the equipped magnet's radius (initially 12 studs) and immediately adds 1 coin to your wallet. It respawns
after 5 seconds and pays at most once per spawn. It never enters inventory or
sale value: the panel has only Bolt, Can and Gear rows. Selling metals adds to
the existing wallet balance, preserving coins already picked up on the map.

Each object's `PickupHint` world label shows its name and immediate Coin reward
or metal sale price per unit. During its 5-second cooldown, the label reads
`Respawning...`, then returns to the pickup hint. The HUD's second line briefly
shows accepted pickup receipts (`Coin: +1 coin`, `Bolt: +1 in inventory`) and
server-confirmed sale results (`Sold metal: +N coins`, or `Inventory is empty`).
The newest receipt replaces the old one and restores `Pick up coins or sell metal`
after 3 seconds. On activation, `Sell all` shows `Selling...` and stays disabled
for a local 0.5-second courtesy cooldown, not until a server acknowledgement.
Delayed results do not release a newer cooldown; receipts never grant rewards.

## Magnet shop

Open the `Shop` HUD button anywhere. Shop and Inventory use separate scrolling
panels; opening one closes the other. Earn coins from map pickups or metal sales,
then buy upgrades in order:

| Magnet | Coin price | Attraction radius |
| --- | ---: | ---: |
| Starter | Free, initially equipped | 12 studs |
| Iron | 25 | 18 studs |
| Gold | 100 | 24 studs |

Buying immediately equips the new tier and changes the client magnet's color.
Gold costs another 100 coins after Iron; buying both costs 125 in total. Buying
changes only coins and the equipped tier, never metal inventory. The HUD shows
prices, radius and affordability as hints; the server decides the transaction.
An already-owned tier cannot charge again, and a repeated Iron request cannot
accidentally purchase Gold. You cannot skip directly from Starter to Gold.

The next-upgrade purchase button shows `Buying...` during an independent local
0.5-second courtesy cooldown; equipped/owned/locked rows keep their own states. It does not wait for an acknowledgement or retry automatically.
Shop results reuse the header's 3-second feedback area: for example,
`Bought Iron — range 18 studs` or `Not enough coins for Iron`. A delayed result
cannot release a newer cooldown. The equipped tier survives character resets and
loads from the saved profile on live rejoin. Default Studio Preview returns to
Starter on leave or Stop/Play. There is no unequip/downgrade flow, Robux purchase,
shop zone or fusion system.

Shop, upgraded range and upgrade visuals are **NOT RUN in Studio**. Previous
user-reported two-player/sale verification does not establish shop acceptance.

## Saving and local Preview

Live servers load/save one version-1 profile per player containing coins, the
three metal counts and the equipped magnet tier. Server-side `UpdateAsync`
acquires a session lease and writes the whole profile, preventing an older
server from overwriting a newer session. Defaults apply only when the stored
record is confirmed absent. A failed load, invalid/unsupported record or another
active lease blocks play and disconnects the player instead of installing zeros
and overwriting existing progress. Live failures never fall back to Preview.

- Autosave/lease renewal: every 60 seconds, staggered across players.
- Session lease: 180 seconds; gameplay stops 15 seconds before local expiry
  unless renewal succeeds. Readiness comes from private server state.
- Load/save attempts: at most 3, with a 20-second retry/callback budget. A Roblox
  network call already in flight cannot be forcibly stopped at that deadline.
- Leave: freeze gameplay, attempt a final whole-profile save and release the lease.
- Shutdown: close profiles in parallel, with a 25-second overall wait limit.

These are bounded best-effort saves, not a loss-free guarantee. Crashes, outages
or shutdown timeouts can lose changes since the last successful save; a failed
release may temporarily prevent rejoin until its lease expires.

`src/server/Services/PersistenceConfig.luau` defaults `allowStudioDataStore` to
`false`. In Studio Preview, code never accesses `DataStoreService`, starts with
zero coins/metal and Starter, and makes no real saves across join or Stop/Play.
The third HUD line and both panels show `Preview: progress is not saved`.
Persistent mode shows `Progress loaded`, `Waiting for auto-save`,
`Saving progress...`, `Progress saved` or `Save delayed - retrying` as appropriate.
Before readiness, coins read `Coins: --`; controls show `Data unavailable`
and stay disabled. These messages do not constitute real runtime verification.
`StorageMode`,
`DataStatus` and `DataReady` are display hints, not authority. Loading, closing
or unsafe/error profiles stop scanning and disable purchases/sales; saving
while a valid lease remains is not itself a gameplay lock. A transient
`SaveDelayed` status keeps play available until ownership/readiness becomes unsafe.

The production store is `MagnetMayhem_PlayerData_v1`; an explicitly approved
Studio storage test uses `MagnetMayhem_PlayerData_Studio_v1`. Merely enabling
Studio API access does not override the code's default Preview setting. No
API settings or publishing were changed. Real storage verification requires
separate approval and an isolated test experience; do not enable Studio access
against live player data. Roblox warns that Studio can access the same stores
as live clients. [Roblox Data stores](https://create.roblox.com/docs/cloud-services/data-stores#enable-studio-access)

`UpdateAsync` callbacks may run again during conflicts, cannot yield, and can
return nil to cancel a write. Profile/lease validation runs inside that callback
without issuing rewards or other side effects. [GlobalDataStore.UpdateAsync](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync)

**Persistence is NOT RUN against real Roblox DataStore/Studio servers.** See
[the controlled storage checklist](docs/STUDIO_VERIFICATION.md#persistent-profiles-and-preview-not-run).
Existing two-player/selling reports do not establish storage or shop acceptance.

## Checks

Development tools: official standalone Luau (`luau`, `luau-analyze`,
`luau-compile`), Rojo, Node.js for the optional check orchestrator. They are
developer tools, not dependencies shipped into the game. No install is performed
by the check script. Put tools on PATH or supply explicit paths:

```powershell
luau tests/run.luau
luau tests/adversarial.luau
luau-analyze src/shared tests
node scripts/check.mjs
node scripts/check.mjs --rojo C:\path\to\rojo.exe --luau C:\path\to\luau.exe
node scripts/test-hud.mjs /path/to/luau
node scripts/test-player-state.mjs /path/to/luau
```

The script also accepts `--analyze` and `--compile`. It discovers locally extracted
official Luau tools in `.tools/luau/` if present. Missing tools are printed as
NOT RUN; any available failing check exits nonzero. Pure tests prove domain
decisions, not real Roblox races. Full Roblox typechecking needs Roblox globals
and an Instance-aware type environment; standalone analysis is restricted to the
engine-independent shared modules/tests. The check script also runs the real HUD
update function and player-state service under scalar mocks to guard display,
coin/metal dispatch and sale behavior. Mocks do not prove real Roblox adapters,
replication or Studio behavior. See `VALIDATION.md` for actual results.

## Layout and authority

- `src/shared`: frozen scalar definitions/configuration, pure validation/claim rules.
- `src/server`: profile load/save and leases, authoritative coin/inventory/magnet state,
  target registry, request throttling, claim and respawn.
- `src/client`: tier-colored magnet visual, cosmetic homing ghost, inventory/shop HUD.
- `tests`: pure assertions plus adversarial lifecycle simulations.
- `docs/STUDIO_VERIFICATION.md`: exact runtime/multiplayer/mobile checklist.
- `PRD.md`: bounded requirements and gated future roadmap.

The client submits only a target and observed spawn token. The server decides all
rewards using server state and measured distance, claiming the target before any
side effect. `CollectionResult` carries appearance information only. HUD coins and inventory
come exclusively from the server's replicated `Coins`, `Inventory_bolt`,
`Inventory_can` and `Inventory_gear` Player attributes. `CollectionResult` remains
exactly `{ lifecycleId, objectId, startCFrame }` and cannot grant inventory.
`RequestSellAll` takes no arguments: the server rejects supplied arguments and
synchronously consumes authoritative inventory before crediting configured sale
value. A separate 2 requests/second, burst-2 server limiter protects sales; the
existing collection limiter is retained. `SaleResult` sends one authoritative
nonnegative integer payout to the requesting client for sale/empty feedback;
malformed or throttled sale requests are rejected silently. Receipts use accepted
collection events or sale results, never wallet/attribute changes to infer a sale.

`RequestBuyMagnet` accepts exactly one integer tier from the frozen catalog.
Extra arguments (including explicit nil, price, balance or radius) are rejected.
An independent 2 requests/second, burst-2 server limiter protects purchases.
Unknown/noninteger/out-of-range tiers and malformed requests cannot change state
and produce no receipt, as do throttled requests. The purchase atomically
checks server coins, debits the catalog price and changes the private session tier
without yielding. Server collection range comes from that tier, not Player
attributes or client hints. `MagnetTier` and `MagnetRadius` are replicated display hints; locally
spoofing it can affect presentation/scanning, not authoritative range or ownership.
`ShopResult` contains exactly `{ status, tier }`, cosmetic only: `purchased`,
`insufficientCoins`, `owned`, `locked` or the rules-level `invalidTier` status.
The remote filters invalid tiers before a receipt; that status is retained in
the pure rules/result vocabulary. A receipt never grants
coins, inventory, tiers or range.

**Two-player and selling verification: USER-REPORTED PASS (2026-10-13).** The user
confirmed these checks complete; individual checklist results were not supplied
or independently observed. Mobile verification is deferred until development is
finished and does not block follow-on feature development. Detailed device,
security/network and feedback acceptance remains required before calling the
game release-ready. Persistence is now explicitly requested; real storage checks
remain NOT RUN. Collection Book, Combo and Fusion remain roadmap features until
their scope is requested; publishing and monetization
still require separate approval.

## Official references

- [Rojo project format](https://rojo.space/docs/v7/project-format/)
- [Roblox client/server validation](https://create.roblox.com/docs/scripting/security/client-server-boundary)
- [Official Luau tools](https://github.com/luau-lang/luau/releases)
