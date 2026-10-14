# Magnet Mayhem

Milestone 1 Roblox/Luau prototype: automatic magnet attraction, a direct map Coin pickup, 15 metals,
server-validated selling, metal inventory, cosmetic skins, independent coin stat
upgrades, two-handed carry, server-owned persistence and a permanent Collection
Book, respawning objects and a minimal PC/mobile HUD.
No runtime dependencies, publishing or Robux purchases. Local Studio defaults to
**Preview mode: progress is not saved**; live servers use persistent profiles.

## Open the prototype

Use Rojo 7.x and the Rojo Studio plugin, or open a built place directly:

```powershell
rojo build default.project.json -o build/MagnetMayhem.rbxlx
rojo serve default.project.json
```

Create `build/` first if needed. Connect the plugin to `localhost:34872` in an
unpublished local place. Sync, press Play, then approach the map metals. Original Bolt, Can and Gear remain at
`(-20, 1.5, -24)`, `(0, 1.5, -24)` and `(20, 1.5, -24)`.
Each accepted metal pickup adds one matching unit to inventory, with no immediate
sale payout. First discoveries can separately earn a Collection Book milestone.
Objects return after 5 seconds. Use the `Inventory` HUD button to
show quantities and estimated sale value, then `Sell all` anywhere to empty the
inventory and receive each metal's catalog sale value. Bolt/Can/Gear still sell
for 1/3/5 coins per unit; the new metal values are listed in [PRD.md](PRD.md). The sale button
is disabled while empty; repeated empty sales grant nothing. There is no capacity
limit or selling zone. Coins and inventory survive character resets. In live
servers, saved progress loads on rejoin; default Studio Preview resets on leave
or Stop/Play. Collection is automatic; the red horseshoe is a
client-only magnet visual, initially the red Starter skin, carried in front with
both hands. Final pose/rig acceptance remains deferred.

A separate bright yellow neon `Coin` cylinder at `(0, 1.5, 24)` automatically
collects within the independently upgraded range (initially 12 studs) and immediately adds 1 coin to your wallet. It respawns
after 5 seconds and pays at most once per spawn. It never enters inventory or
sale value: the panel has 15 metal rows and no Coin row. Coins do not advance the Book. Selling metals adds to
the existing wallet balance, preserving coins already picked up on the map.

Each object's `PickupHint` world label shows its name and immediate Coin reward
or metal rarity and sale price per unit. During its 5-second cooldown, the label reads
`Respawning...`, then returns to the pickup hint. The HUD's second line briefly
shows accepted pickup receipts (`Coin: +1 coin`, `Bolt: +1 in inventory`) and
server-confirmed sale results (`Sold metal: +N coins`, or `Inventory is empty`).
The newest receipt replaces the old one and restores `Pick up coins or sell metal`
after 3 seconds. On activation, `Sell all` shows `Selling...` and stays disabled
for a local 0.5-second courtesy cooldown, not until a server acknowledgement.
Delayed results do not release a newer cooldown; receipts never grant rewards.

## Cosmetic magnet shop

Open `Shop` anywhere to buy or equip a skin. Shop, Inventory and Book are
mutually exclusive scrolling panels. Full-list height keeps every card and the
storage note reachable, including in short viewports. The panel is titled
`Magnet Looks`; cards say `Appearance only`. An owned alternative shows
`Equip <name>`, while the current skin shows `Equipped`.

| Skin | Coin price | Appearance |
| --- | ---: | --- |
| Starter | Free; initially owned/equipped | Red Classic horseshoe |
| Iron | 25 | Blue Industrial horseshoe |
| Gold | 100 | Gold Royal horseshoe |

Buy in any order: Gold does not require Iron. A purchase records ownership and
immediately equips that skin. Click an owned skin to equip it free, including
Starter; an equipped skin cannot charge again. **Skins change appearance only**:
no skin grants range, power, movement speed or extra rewards. Prices and
ownership come from the server. No Robux purchase, shop zone, fusion or buy-back.

## One-click stat upgrades

Use the three fixed **right-side icon buttons**: Range (target rings), Power
(horseshoe) and Speed (chevrons; movement speed). Each shows current/next
values, level and next cost, such as `Range L0`, `12 > 18 studs` and
`25 coins`. Other states read `Loading...`, `Need N coins`, `Upgrading...` or `MAX`. One click buys only
the next level for that stat, without opening Shop or confirming a dialog.
Loading/unavailable, insufficient funds, cooldown and maximum-level states are
disabled. No automatic retries or bulk purchases.

| Stat | Level-0 value → level-5 value | Prices for levels 1 / 2 / 3 / 4 / 5 |
| --- | --- | --- |
| Range | 12 → 42 studs, +6 per level | 25 / 100 / 250 / 500 / 1000 coins |
| Power | 1 / 1.25 / 1.5 / 2 / 2.5 / 3× | 20 / 60 / 150 / 350 / 700 coins |
| Move speed | 16 → 26 studs/second, +2 per level | 20 / 60 / 150 / 350 / 700 coins |

The three levels start at 0, progress independently and cap at 5. Prices are
per level, not totals. Power speeds up client scanning/cosmetic pull and scales
the server's permitted collection rate and burst; it does **not** multiply
payouts, unlock heavy objects or move physical server parts. New ghosts capture
their power-adjusted pull duration; an upgrade does not retime a ghost in flight. Range uses private
server upgrade state, not the equipped skin. Server-applied Move speed sets
`Humanoid.WalkSpeed` from the private level on load, upgrade and character reset,
including late Humanoid arrival; this is not movement anti-cheat.
[Roblox Humanoid.WalkSpeed](https://create.roblox.com/docs/reference/engine/classes/Humanoid#WalkSpeed)

Skin buy/equip and stat upgrades use separate 0.5-second local courtesy
cooldowns, not indefinite acknowledgement locks. Equipping shows `Equipping...`;
buying shows `Buying...`. Server receipts share the existing newest-message-wins feedback area;
late receipts cannot release a newer cooldown or grant anything. Skin ownership,
equipped skin and all three levels survive resets and save with live progress.
Default Preview resets these to Starter only and level 0 on leave or Stop/Play.

## Two-handed carry

The local horseshoe is carried in front of the avatar, with each hand targeting
its matching grip instead of a prop floating beside the body. R15 uses two
position `IKControl` chains; R6 uses procedural shoulder transforms during
PreSimulation. Normal leg animation remains enabled. No animation asset upload
is needed. [Roblox IKControl](https://create.roblox.com/docs/reference/engine/classes/IKControl),
[Roblox Motor6D.Transform](https://create.roblox.com/docs/reference/engine/classes/Motor6D#Transform)

The pose and prop are **local cosmetic visuals**; they do not promise visibility
to other players, move the character root or authorize pickups. Old controls and
prop are cleared on death/reset, skin change or loss of readiness. Rig/scale
alignment and movement/jump behavior remain final Studio checks.

**Cosmetic shop, independent upgrades and R6/R15 carry: NOT RUN — DEFERRED in
Studio.** The user will test after development ends; earlier two-player/selling
reports do not establish acceptance for this new scope.

## Collection Book

Open `Book: N/15` anywhere to see `Discovered: N / 15`. `Inventory: N`,
`Shop` and `Book: N/15` are self-toggling tabs; the active tab is tinted and
opening another closes the current panel. Unknown metals show
`??? | Rare`, for example; discovery reveals a name such as `Gear | Rare`. The
15 metals are classified as Common (6), Rare (4), Epic (3) and Legendary (2).
All are available on the prototype map with 5-second respawns: rarity labels
are not drop odds, zone requirements or weight unlocks.

World metal labels also show name, rarity and sale value; the Coin label keeps
its direct-wallet earning route.

Your first accepted pickup of each metal records its discovery. Repeated pickups
still add inventory but do not rediscover it; selling does not erase discoveries.
Map Coins never count. The server automatically pays milestones once:

| Distinct discoveries | Bonus coins |
| ---: | ---: |
| 3 | 10 |
| 7 | 30 |
| 15 | 100 |

These are tunable prototype rewards. Milestone rows show `Reached` or `Need N`,
not a claim button. First-discovery feedback can read
`Discovered Gear (3/15) +10 coins`; ordinary pickups still use pickup receipts.
Discovery and milestone payment belong only to the winning collector; receipts are cosmetic.
Discovery survives character resets and is saved in live profiles. Default
Studio Preview clears it on leave or Stop/Play, just like coins and inventory.
Version-1 saves retain coins and original metal counts, with no inferred
discoveries or retroactive milestone rewards; version-2 discoveries are preserved.
Both migrate to the current cosmetic/stat schema as described below.

**Book, new-metal and migration runtime acceptance are NOT RUN.** The user
requested uninterrupted development and final testing after development ends;
previous two-player/selling reports do not establish these new behaviors. Combo
and Fusion are still next roadmap features, not part of this Book slice.

## Saving and local Preview

Live servers load/save one version-3 profile per player containing coins, all
15 metal counts, equipped/owned skins, three upgrade levels and sparse discoveries. Server-side
`UpdateAsync` acquires a session lease and writes the whole profile, preventing an older
server from overwriting a newer session. Defaults apply only when the stored
record is confirmed absent. A failed load, invalid/unsupported record or another
active lease blocks play and disconnects the player instead of installing zeros
and overwriting existing progress. Live failures never fall back to Preview.
Exact valid version-1/version-2 records migrate during permitted acquisition.
Preserve coins, legacy counts, equipped skin and lease; preserve version-2
discoveries. Version 1 adds twelve zero counts and empty discovery. Both grant
Starter through the old equipped tier and map its previous 12/18/24-stud reach to
range level `oldTier - 1`, without charging; power and speed start at 0. Decoding
preserves the old lease so migration cannot bypass a foreign owner. Corrupt or
unknown-version records are rejected rather than repaired or reset.

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
zero coins/metal, no discoveries, Starter only and all upgrade levels 0.
It makes no real saves across join or Stop/Play.
The third HUD line and panel notices show `Preview: progress is not saved`.
Persistent mode shows `Progress loaded`, `Waiting for auto-save`,
`Saving progress...`, `Progress saved` or `Save delayed - retrying` as appropriate.
Before readiness, coins read `Coins: --`; controls show `Data unavailable`
and stay disabled. These messages do not constitute real runtime verification.
`StorageMode`,
`DataStatus` and `DataReady` are display hints, not authority. Loading, closing
or unsafe/error profiles stop scanning and disable skin/stat purchases and sales; saving
while a valid lease remains is not itself a gameplay lock. A transient
`SaveDelayed` status keeps play available until ownership/readiness becomes unsafe.

The namespace stays unchanged when the record version becomes 3, so migration
can find existing saves. The production store is `MagnetMayhem_PlayerData_v1`; an explicitly approved
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

**Behavior tests are deferred until development finishes, as requested.** The
commands below are existing verification recipes, not fresh pass evidence for
the cosmetic/stat/carry changes. See `VALIDATION.md` for checks actually run.

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
- `src/server`: profile load/save and leases, authoritative coin/inventory/skin/stat state,
  target registry, request throttling, claim and respawn.
- `src/client`: two-handed skin visual, cosmetic homing ghost, inventory/shop/book HUD and right-side stat dock.
- `tests`: pure assertions plus adversarial lifecycle simulations.
- `docs/STUDIO_VERIFICATION.md`: exact runtime/multiplayer/mobile checklist.
- `PRD.md`: bounded requirements and gated future roadmap.

The client submits only a target and observed spawn token. The server decides all
rewards using server state and measured distance, claiming the target before any
side effect. `CollectionResult` carries appearance information only. HUD coins and inventory
come exclusively from the server's replicated `Coins` and
`Inventory_<metalId>` Player attributes for all 15 metals. `CollectionResult` remains
exactly `{ lifecycleId, objectId, startCFrame }` and cannot grant inventory.
`RequestSellAll` takes no arguments: the server rejects supplied arguments and
synchronously consumes authoritative inventory before crediting configured sale
value. A separate 2 requests/second, burst-2 server limiter protects sales; the
collection limiter remains separate and scales with private power. `SaleResult` sends one authoritative
nonnegative integer payout to the requesting client for sale/empty feedback;
malformed or throttled sale requests are rejected silently. Receipts use accepted
collection events or sale results, never wallet/attribute changes to infer a sale.

`RequestBuyMagnet` accepts exactly one known integer skin tier. Extra arguments,
including explicit nil/price/balance, are rejected. An independent 2 requests/second,
burst-2 limiter protects purchases/equip. The server synchronously debits only
unowned skins and records ownership/equip; owned skins equip free. `ShopResult`
is exactly `{ status, tier }`, cosmetic only, with rule statuses `purchased`,
`equipped`, `owned`, `insufficientCoins` and `invalidTier`. Invalid/throttled
remote requests are silent. Skins never authorize collection range.

`RequestUpgrade` accepts exactly `(upgradeId, desiredLevel)` and has its own
2 requests/second, burst-2 limiter. IDs are `range`, `power`, `speed`; valid next
levels are 1–5. Repeated old levels cannot charge; skipped levels are denied.
`UpgradeResult` is exactly `{ status, upgradeId, level }`, cosmetic only. Private
levels determine server range, collection throughput (`12 × power` requests/second,
burst `6 × power`) and applied movement speed. `OwnedMagnet_<skinId>`,
`Upgrade_<upgradeId>`, `MagnetTier`, `MagnetRadius`, `MagnetPower` and `MoveSpeed`
attributes are display hints, not ownership/stat/payment authority. Client
spoofing may change local presentation, not private server economy or range.

`CollectionBookResult` contains exactly `{ objectId, count, reward }` for a
first discovery, with any automatically awarded milestone coins. It is a cosmetic
server receipt, not a grant or claim API. Replicated `Discovered_<metalId>`
booleans drive the Book display. Private server discovery state determines
eligibility; client-spoofed counts/flags cannot discover metals or replay bonuses.
Selling preserves discovery even when every inventory count becomes zero.

**Two-player and selling verification: USER-REPORTED PASS (2026-10-13).** The user
confirmed these checks complete; individual checklist results were not supplied
or independently observed. Mobile verification is deferred until development is
finished and does not block follow-on feature development. Detailed device,
security/network and feedback acceptance remains required before calling the
game release-ready. Persistence is now explicitly requested; real storage checks
remain NOT RUN. Cosmetic skins, separate stat upgrades and two-handed carry are the current
requested slice; Combo and
Fusion remain unimplemented roadmap features. Final testing is deferred until development
is finished, without claiming release readiness; publishing and monetization
still require separate approval.

## Official references

- [Rojo project format](https://rojo.space/docs/v7/project-format/)
- [Roblox client/server validation](https://create.roblox.com/docs/scripting/security/client-server-boundary)
- [Official Luau tools](https://github.com/luau-lang/luau/releases)
