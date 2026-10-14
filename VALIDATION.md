# Magnet Mayhem — development and validation

## Delivery status

The prototype, independent map-coin/inventory/selling routes, in-game feedback
and world hints, cosmetic-only magnet shop, independent coin-priced range/power/
movement upgrades, two-handed local carry, persistent profiles and Collection
Book are implemented.
Latest user evidence (2026-10-13): two-player and selling verification are
complete, and mobile testing will be done after development is finished. This
supersedes the earlier blanket pending status for those broad areas; it is
USER-REPORTED PASS, not independently observed or individually recorded matrix
coverage. Mobile remains NOT RUN, scheduled for the final development stage and
does not block follow-on feature work. Security/network/feedback details are not
individually recorded; full device/runtime acceptance remains a release gate.
New cosmetic/stat/pose Studio checks, Collection Book and real DataStore checks
are NOT RUN; the earlier broad
two-player/selling report does not validate the newly added shop. Other roadmap
systems still need a requested feature scope.
No game publishing, Robux purchases or external backend was configured.

## Cosmetic shop, one-click stats and two-handed carry (2026-10-14, macOS)

The latest user scope replaces ability-granting magnets with cosmetic looks.
Starter is free, Iron costs 25 coins and Gold 100. Any affordable unowned look
can be bought; an owned look equips free. Purchase/equip changes appearance,
ownership and the purchase debit only, never range, power or movement speed.

Three fixed right-side icon buttons independently buy the next Range/Power/Speed
level in one click, without a panel or confirmation. Cards show current/next
value, level, price, loading/shortfall/cooldown/MAX. Levels 0–5 are prototype
tuning: range 12→42 studs, power 1→3x, speed 16→26. Prices are defined only in
the frozen server catalog. Requests include the explicit ID and desired level;
old-level replay cannot buy another level. Skin/stat courtesy cooldowns and
server rate buckets remain independent. Cosmetic receipts never grant state.

Private range controls server collection distance. Private power scales the
server collection bucket (12×power/s, burst 6×power); client scan interval and
new ghost duration divide by the catalog power. Unit rewards remain unchanged.
The server applies private movement speed to the loaded/replacement Humanoid,
including late creation, and removes listeners with the profile. This is not a
movement anti-cheat claim. Skins cannot change any of these abilities.

Version-3 profiles add owned looks and three stat levels. Strict valid v1/v2
migration retains prior coins/counts/discoveries/lease and equipped look, grants
previous sequential ownership and range level old tier minus one (12/18/24-stud
reach preserved). Power/speed begin at zero; store namespaces/Preview opt-in are
unchanged. Snapshots detach every profile map.

The prop is carried in front with both hands: R15 local IK; R6 pose after Animator
with pivot-preserving arm rotations and rig-derived dual-reach placement.
Same-character Humanoid/Animator/limb/joint replacement rebinds safely. Incomplete
or unsupported reach geometry hides the local prop rather than displaying a
floating hold; original transforms are restored. Nonparallel lookAt up vectors
make vertical reach orientation deterministic. Ghosts target the held bridge.
These are code/mathematical guarantees, not observed avatar contact or visual QA.
[IKControl](https://create.roblox.com/docs/reference/engine/classes/IKControl),
[Motor6D timing](https://create.roblox.com/docs/reference/engine/classes/Motor6D#Transform),
[CFrame orientation](https://create.roblox.com/docs/reference/engine/datatypes/CFrame#lookAt).

| Fresh check | Actual result |
| --- | --- |
| Six JavaScript script syntax checks | PASS — exit 0 |
| Five generated mock scripts with `--compile-only` | PASS — compilation only; assertions NOT RUN |
| `luau-analyze src/shared tests` | PASS — no diagnostics; exit 0 |
| Whole-source/test compilation | PASS — 3 KLOC / 148 KB bytecode; exit 0 |
| Fresh Rojo place and sourcemap | PASS — generated unpublished local artifacts |
| `git diff --check` | PASS |
| Independent scoped code review | APPROVE — static only; 0 unresolved confirmed defects |
| Unit/mocked behavior suites | NOT RUN — final execution deferred by user |
| R6/R15 visual contact, real wheel/touch, multiplayer and mobile | NOT RUN — deferred Studio acceptance |
| Real DataStore migration/rejoin/failure and engine-aware typing | NOT RUN — backend setup/type environment unavailable |

Review repairs: same-character pose rebinding, R6 grip/pivot geometry, finite
catalog values, invalid/missing intermediate levels distinguished from a real
cap, and stale cosmetic fixtures. Regression coverage is authored for these
cases, free skin equip/ability isolation, upgrade replay/arity/limits/costs,
private throughput/speed, v3 migration and receipt/cleanup behavior. No assertion
execution is represented as a pass. The prior scroll sizing fix is retained.

New files: `UpgradeDefinitions.luau`, `UpgradeRules.luau`,
`UpgradeRules.spec.luau`. Changed: cosmetic catalog/rules/profile/config, server
state/collection adapters, all three client controllers, mocked/pure regression
coverage and project documents. Reuses existing wallet, save leases, receipts,
panels and native GUI/rig APIs; no runtime dependency or uploaded animation asset.
Remaining risks: final rig/device/network behavior, controlled storage migration
and Roblox-aware adapter typing. Latest build: `build/MagnetMayhem.rbxlx`.

## Shop scrolling: corrective implementation (2026-10-14, macOS)

User-reported issue: Shop scrolling moves only one notch. The previous shared
panel relied on automatic canvas sizing. This fix disables automatic sizing and
sets vertical CanvasSize from the measured list extent plus fixed outer padding,
preserving native scroll input. It updates on content/window/visibility changes,
clamps positions after resize/shrink and ignores collapsed hidden measurements.
All three panels share this fix; nine resize listeners join existing HUD cleanup.

Measured layout content includes list spacing; outer UIPadding is separate.
The fixed-padding height calculation and viewport clamp are implementation
inferences from these APIs. Documentation does not prove the earlier automatic
canvas/size-constraint interaction caused this project's symptom.
[Roblox list measurement](https://create.roblox.com/docs/reference/engine/classes/UIGridStyleLayout#AbsoluteContentSize),
[list padding](https://create.roblox.com/docs/ui/list-flex-layouts#padding),
[ScrollingFrame](https://create.roblox.com/docs/reference/engine/classes/ScrollingFrame).

Focused calculation regression: `node scripts/test-panel-scroll.mjs
.tools/luau/luau` — PASS, 5 checks. The actual panel factory/cleanup is extracted
into scalar mocks: full Shop bottom, resize/content clamp, hidden/reopen and
fractional height, shared three-panel behavior and listener cleanup. This bounded
bug check does not run the deferred full suites or prove engine mouse/touch input.
Studio reproduction/acceptance remains NOT RUN. No gameplay/storage changes.
Fresh six-script syntax checks, shared/tests analysis, whole-source/test
compilation (3 KLOC / 119 KB), Rojo build/sourcemap and whitespace checks pass.
Independent scoped review: COMMENT, 0 confirmed issues; engine behavior remains
unverified. Changed files: HUD factory, focused scrolling harness, compatibility
mocks/check runner, design/usage/runtime checklist and this record.

## Collection Book: development evidence (2026-10-14, macOS)

Nonstop continuation advances to a bounded Collection Book slice, not publishing
or monetization. The map now contains 15 metals plus Coin, with Common/Rare/Epic/
Legendary classifications (6/4/3/2). Rarity is a label, not random drop odds.
First discoveries persist in live profiles and automatically award milestone
bonuses at 3/7/15 distinct discoveries: 10/30/100 coins. Duplicate pickups, sales
and loads do not re-award or erase discoveries. Unit sale value remains separate.
The new Book tab shares the existing scrolling panel and feedback system;
unseen entries are masked, three panels are mutually exclusive, and Sell all
stays above the expanded inventory list. Cosmetic receipts never grant state.

Profile version 2 adds fifteen counts and sparse discoveries. Only valid legacy
version-1 records migrate, preserving coins, three old counts, tier and lease;
new counts start at zero and the book empty, without retroactive rewards.
Existing store namespaces and default unsaved Studio Preview remain unchanged.

Review found and repaired capacity rejection after lifecycle claim, strict
catalog rarity type mismatch and an obsolete world-label assertion. Private
capacity preflight now occurs before claim, preventing max-wallet/max-count/
milestone-overflow rejection from stranding an available object. No broad
exception swallowing, client authority, runtime package or claim remote added.

| Check | Actual result |
| --- | --- |
| All five JavaScript script syntax checks | PASS — exit 0 |
| `luau-analyze src/shared tests` | PASS — no diagnostics; exit 0 |
| Whole-source/test compilation | PASS — 3 KLOC / 118 KB bytecode; exit 0 |
| Fresh Rojo place and sourcemap mapping | PASS — nonempty place; Script/LocalScript mappings verified |
| `git diff --check` | PASS |
| Independent scoped code review | COMMENT — 0 unresolved introduced issues; static evidence only |
| New/updated unit and mocked behavior suites | NOT RUN — authored for the final verification phase per user request |
| Full Roblox-aware typing, Studio, mobile and real storage | NOT RUN — no backend/device/engine acceptance claimed |

Authored coverage includes six pure Book cases, five additional profile/schema/
migration cases, three-tab/loading/masking/cosmetic receipts, state overflow
rejection, preserved same-token availability for another claimant and saved-book
rejoin. Compilation of generated mocks is not execution of their assertions.
Final testing should also exercise the existing exact lease-expiry-at-claim
boundary and all newly expanded catalog/network/device behavior.

New files: `src/shared/CollectionBookRules.luau`, `tests/BookRules.spec.luau`.
Changed files: shared catalog/profile/rules/config; server state/collection/world;
client HUD; regression scripts/tests and project docs. Simplification: reuse
existing collection ownership, coin wallet, save snapshot, scrolling panels and
header feedback; no separate reward/claim service. Unpublished build:
`build/MagnetMayhem.rbxlx`. Final behavior evidence remains deliberately pending.

## Persistent profiles: implementation evidence (2026-10-14, macOS, historical v1)

This section records the initial persistence implementation before Collection
Book. Current records are version 2 with the migration described above.

The requested save feature stores coins, Bolt/Can/Gear inventory and equipped
magnet tier together. Live servers load an atomic version-1 profile, acquire a
180-second session lease and autosave every 60 seconds with an initial stagger.
Gameplay freezes before the 15-second safety margin, on ownership loss, and
before leave/shutdown writes. Final closes coalesce and shutdown drains in
parallel for at most 25 seconds. Failed/corrupt/contended loads do not install or
write defaults. Immutable snapshots and revision tracking keep mutations during
I/O dirty; orphan-acquisition cleanup retains local ownership while yielding.
Nonfinite/expired local lease deadlines cannot install or renew private authority.

Default Studio Preview never accesses DataStoreService and explicitly displays
`Preview: progress is not saved`. It resets progress on leave or Stop/Play.
Live storage failures never silently become Preview. Separate production/test
store names are configured, but Studio opt-in remains false. No API Services
setting, isolated test experience or publication was changed.

The user requested nonstop development and deferred final testing on 2026-10-14.
No Studio/device/backend playtest was launched. A bounded internal review ran
165 pure tests and 10 player-state mocks before final integration; these are not
real-engine evidence. The new persistence harness contains deterministic mocked
load/save/retry/lease/close scenarios. Review caught a harness clock-offset issue;
it was corrected, but a full post-correction mock rerun is deferred to the final
verification phase, not reported as passing here.

| Check | Actual result |
| --- | --- |
| All five JavaScript script syntax checks | PASS — exit 0 |
| `luau-analyze src/shared tests` | PASS — no diagnostics; exit 0 |
| Whole-source/test compilation | PASS — 2 KLOC / 99 KB bytecode; exit 0 |
| Fresh Rojo place and sourcemap | PASS — build and sourcemap generated |
| `git diff --check` | PASS |
| Independent persistence code review | COMMENT — 0 remaining source issues; final regression evidence deferred |
| Full final automated/mock regression run | DEFERRED — not claimed passing after final integration edits |
| Full Roblox-aware typecheck | NOT RUN — engine type environment not configured |
| Real DataStore restore/failure/cross-server/shutdown | NOT RUN — controlled backend setup not performed |
| Final Studio/mobile acceptance | NOT RUN — user deferred until development is finished |

New files: `ProfileRules.luau`, `PersistenceConfig.luau`,
`PersistenceService.luau`, `ProfileRules.spec.luau`, `test-persistence.mjs`.
Integration changes: player-state/main, client HUD/scan/magnet readiness,
existing mocked harnesses/check script and project documents. Reuses the existing
wallet, inventory, tier catalog and HUD header; no runtime dependency or
client-save remote is added. Live durability remains best-effort: crashes/outages
can lose unsaved changes, a failed release can delay rejoin, and physical
in-flight requests cannot be forcibly cancelled. Build output is unpublished.

## Coin-only magnet shop: evidence (2026-10-13, macOS, historical)

The user requested a shop. This implementation spends earned in-game coins only;
it does not introduce Roblox/Robux purchases or enable API Services/publishing.

| Magnet | Purchase price | Collection radius |
| --- | ---: | ---: |
| Starter | Free, initially equipped | 12 studs |
| Iron | 25 coins | 18 studs |
| Gold | 100 coins after Iron | 24 studs |

Open the `Shop` HUD toggle; it shares the existing scrolling-panel sizing and
closes Inventory while open. Cards show equipped/owned/locked/affordable/shortfall
states. Buying auto-equips the next tier and changes the local magnet color.
Coins, inventory and equipped magnet survive character resets but reset on
leave/new session. No persistence, bags, consumables, fusion or other upgrades
are added; initial prices are documented prototype tuning values.

`RequestBuyMagnet` accepts exactly one known numeric tier. Extra prices, balances,
radii or nil arguments, malformed tiers, unknown sessions and rate overflow are
rejected silently. The independent buy bucket is 2 requests/second, burst 2,
cleaned on leave. Pure rules validate the entire state/catalog before mutation;
the server deducts the configured price and raises the tier synchronously. Replays
of the same or lower tier cannot charge again; skipped tiers remain locked.
Inventory is not spent or changed by purchases.

Collection radius comes from private server session tier and the frozen catalog,
never replicated `MagnetTier`/`MagnetRadius` attributes. Client tier-based scanning
and model colors are presentation/advisory only. Existing Coin/metal grants,
sale transaction, separate collection/sale limits, synchronous lifecycle claims
and exact three-key `CollectionResult` remain intact.

`ShopResult` carries exactly `{ status, tier }` after the transaction. The HUD
uses it only for a receipt; it never grants coins, equipment or range. Missing,
malformed and separately arriving attributes use bounded Starter/zero display
defaults. The 0.5-second `Buying...` courtesy cooldown is independent of receipts;
late results cannot release a newer cooldown, no retries are automatic, and
destroyed HUDs disconnect external listeners and ignore old timers.

Fresh explicit-tool command is the same four-script syntax/full-check command
recorded in the feedback evidence below, with the same local official tools:

| Check | Actual result |
| --- | --- |
| `luau tests/run.luau` | PASS — 143 passed, 0 failed; 52 new shop rule tests |
| `luau tests/adversarial.luau` | PASS — 5 passed, 0 failed |
| Actual HUD update under scalar mocks | PASS — 11 presentation checks |
| Actual player-state service under mocks | PASS — 7 authoritative session checks |
| Actual HUD/world/server/client controllers under mocks | PASS — 17 integration checks |
| `luau-analyze src/shared tests` | PASS — no diagnostics; exit 0 |
| Whole-source/test compilation | PASS — 76 KB bytecode; exit 0 |
| Four JavaScript script syntax checks | PASS — exit 0 |
| Structure/scope/strict headers | PASS — 15 source modules |
| Fresh Rojo place and sourcemap | PASS — nonempty build and Script/LocalScript mapping |
| Source/test whitespace and `git diff --check` | PASS |
| Independent scoped code review | APPROVE — 0 remaining issues; all checks rerun |
| Full Roblox-aware typecheck | NOT RUN — Instance/global type environment not configured |
| New shop/range/receipt Studio and real multiplayer checks | NOT RUN — no independently observed runtime evidence |
| Mobile acceptance | NOT RUN — user scheduled it after development is finished |

Pure coverage includes exact affordability, order/ownership/replay, invalid and
unsafe wallet/tier/price/catalog facts, isolation and no partial mutation. Actual
module mocks verify request arity (including extra nil), limiter independence,
receipt-after-debit, inventory preservation, session reset, private-range versus
spoofed display attributes, panel exclusivity, exact requested-tier clicks,
cosmetic-only result handling, cooldown/timer ordering, no retries and cleanup.
Two added actual-client checks verify catalog-based 12/18/24 scanning, malformed
tier fallback, ignored spoofed radius, disposable ghosts, catalog colors and
model replacement/death/reset behavior without moving authoritative parts.
The mocks use translation-only CFrame and linear easing; they do not prove real
Roblox geometry, physics, rendering, replication, networking or touch usability.

Changed files for this shop: new `src/shared/MagnetDefinitions.luau`,
`src/shared/ShopRules.luau` and `tests/ShopRules.spec.luau`;
`src/shared/MagnetConfig.luau`, server `PlayerStateService`/`CollectibleService`,
client `HudController`/`AttractionController`/`MagnetController`, `tests/run.luau`,
the three existing mock scripts, `AGENTS.md` (project appendix only), `DESIGN.md`,
`PRD.md`, `README.md`, `docs/STUDIO_VERIFICATION.md` and this evidence record.

Simplifications: reuse the current coin wallet, remote factory, request-bucket
rules, header receipts and scrolling-panel style; one frozen tier catalog drives
price, range and appearance, with no new shop framework or dependency. Remaining
risks are engine-aware typing and new shop/device/network runtime acceptance,
plus deliberate session-only progress. Latest unpublished build:
`build/MagnetMayhem.rbxlx`; tools/builds stay ignored and mock temporary files
are removed after success or failure.

## User verification update before shop (2026-10-13)

| Area | Current evidence | Source / limitation |
| --- | --- | --- |
| Two-player verification | USER-REPORTED PASS | User confirmed complete; mode/version/logs and per-case results not supplied |
| Selling verification | USER-REPORTED PASS | User confirmed complete; individual adversarial/value/concurrency cases not enumerated |
| Mobile verification | NOT RUN — DEFERRED | User scheduled it after development is finished |
| Full independent Studio matrix / Roblox-aware typecheck | NOT RUN / NOT INDIVIDUALLY RECORDED | No new independently observed engine results provided |

That status-update turn changed documentation/scheduling only: no gameplay,
economy, remote, tooling or build changes. `git diff --check` passed. Earlier
automated results were not rerun for that documentation-only update; fresh shop
results are now recorded above.
Earlier NOT RUN entries describe the state at their recorded delivery time;
the table above is the current summary. No claim of mobile or release readiness
is made and no publishing/API Services/purchases are enabled.

## In-game feedback and hints: delivery evidence (2026-10-13, macOS, historical)

The user's request to continue development is implemented as bounded usability
work within the existing earning routes, not a new progression/economy system.

- World `PickupHint` labels show the collectible name and Coin immediate payout
  or metal sale unit price. Unavailable spawns show `Respawning...` and restore
  the normal hint when available again.
- The existing HUD header shows Coin/metal pickup receipts and server-confirmed
  sale payouts. The latest message wins, expires after three seconds and never
  alters the attribute-backed wallet or inventory.
- `PlayerState.sellAll` returns the actual payout; only admitted, zero-argument
  sales send a scalar `SaleResult` after the authoritative transaction. Empty
  sales return/confirm zero; invalid or rate-limited requests remain silent.
- `Selling...` disables the sale action during the existing 0.5-second local
  courtesy cooldown, independent of receipts. Late responses do not release a
  newer cooldown. There are no automatic retries or inferred-success messages.
- Malformed result arguments/lifecycle/numeric values are ignored. Stale feedback
  timers cannot erase a newer message; destroyed HUDs disconnect external
  listeners and delayed callbacks become inert.

The server keeps the same collection claims, prices, inventory consumption and
rate limits. `RequestSellAll` still has no arguments; `CollectionResult` remains
exactly `{ lifecycleId, objectId, startCFrame }`. No runtime dependencies,
upgrades, persistence, purchases or publishing were introduced. UI decisions and
remaining design questions are recorded in `DESIGN.md`.

Fresh command:

```bash
node --check scripts/check.mjs
node --check scripts/test-hud.mjs
node --check scripts/test-player-state.mjs
node --check scripts/test-feedback.mjs
node scripts/check.mjs \
  --luau .tools/luau/luau \
  --analyze .tools/luau/luau-analyze \
  --compile .tools/luau/luau-compile \
  --rojo "$HOME/.rokit/tool-storage/rojo-rbx/rojo/7.7.1/rojo"
```

| Check | Actual result |
| --- | --- |
| Pure rule unit tests | PASS — 91 passed, 0 failed; exit 0 |
| Adversarial lifecycle tests | PASS — 5 passed, 0 failed; exit 0 |
| Actual HUD update under scalar mocks | PASS — 7 presentation checks |
| Actual player-state service under mocks | PASS — 6 state/payout checks |
| Actual HUD/world/server handlers under mocks | PASS — 9 interaction checks |
| `luau-analyze src/shared tests` | PASS — no diagnostics; exit 0 |
| Whole-source/test Luau compilation | PASS — 59 KB bytecode; exit 0 |
| Node syntax, all four check scripts | PASS — exit 0 |
| Feedback harness from a clean checkout without `.tools` | PASS — all 9 integration checks; temporary files cleaned |
| Structure/scope/strict headers | PASS — 13 source modules |
| Fresh Rojo place and sourcemap | PASS — nonempty build and Script/LocalScript mapping |
| `git diff --check` and source/test whitespace | PASS |
| Independent scoped code review | APPROVE — no remaining issues; full checks rerun |
| Full Roblox-aware typecheck | NOT RUN — Instance/global type environment not configured |
| Feedback/earning-route Studio, network and device checks | NOT RUN — deferred by user |

The new integration harness executes the actual HUD, world, player-state and
collectible modules with only require-path substitutions and small deterministic
Instance/signal/clock/task mocks. It checks malformed receipts, zero-argument
sales (including explicit nil rejection), throttling, transaction-before-receipt,
exact three-key collection output, no client grants, label availability, timer
ordering, independent cooldowns, no retries and GUI destruction. These mocks do
not prove Roblox scheduling, networking, rendering or replication.

Review identified a standalone-harness assumption that `.tools` already existed.
The harness now creates its own parent before its unique temporary directory;
running it in a fresh temporary source checkout without `.tools` passed, and
cleanup left the created tools directory empty. No gameplay fixes were needed.

Changed files for this continuation: `DESIGN.md`, `src/shared/MagnetConfig.luau`,
`src/server/Services/PlayerStateService.luau`,
`src/server/Services/CollectibleService.luau`,
`src/server/Services/PrototypeWorldService.luau`,
`src/client/Controllers/HudController.luau`, `scripts/check.mjs`,
`scripts/test-hud.mjs`, `scripts/test-player-state.mjs`, new
`scripts/test-feedback.mjs`, `AGENTS.md` (project appendix only), `PRD.md`,
`README.md`, `docs/STUDIO_VERIFICATION.md` and this record.

Simplifications: reuse the two-line HUD rather than a toast queue/overlay; return
the existing sale transaction's payout rather than infer it from wallet changes;
use attribute-driven hints and short one-shot timers instead of another frame
loop. Risks: full engine-aware typing, world hint occlusion/mobile readability,
real slow-network ordering and GUI/respawn behavior remain unverified. Updated
unpublished place: `build/MagnetMayhem.rbxlx`; build/tools remain ignored.

## Independent coin pickups: earlier evidence (2026-10-13, macOS, historical)

The user clarified that direct coin pickup must coexist with item collection and
selling. Current behavior has two separate routes:

- Bright yellow neon `Coin` at `(0, 1.5, 24)` credits 1 coin immediately and never
  becomes an inventory unit or sale value. It respawns after 5 seconds.
- Bolt/Can/Gear add one metal unit per accepted pickup, then sell for 1/3/5 coins.
  Selling adds to the wallet without replacing coins already collected on the map.
  One map Coin plus one of each metal sold results in 10 coins.

Server catalog `kind` decides the outcome, not a client hint. Only metal entries
initialize inventory and sale prices; the HUD shows only those three metal rows.
Both kinds reuse the existing target registry, living-character/range validation,
request limiter, synchronous claim, cosmetic payload and respawn lifecycle.
Coin credits reject invalid or unsafe wallet/reward arithmetic before mutation.
No additional remote, runtime dependency, persistence or purchase system was added.

Fresh checks used the explicit-tool command shown in the selling evidence below:

| Check | Actual result |
| --- | --- |
| `luau tests/run.luau` | PASS — 91 passed, 0 failed; exit 0 |
| `luau tests/adversarial.luau` | PASS — 5 passed, 0 failed; exit 0 |
| `node scripts/test-hud.mjs .tools/luau/luau` | PASS — 5 mocked presentation checks |
| `node scripts/test-player-state.mjs .tools/luau/luau` | PASS — 6 mocked service checks |
| `luau-analyze src/shared tests` | PASS — no diagnostics; exit 0 |
| Whole-source/test Luau compilation | PASS — exit 0 |
| Node syntax checks for all three check scripts | PASS — exit 0 |
| Structure/scope/strict headers | PASS — 13 source modules |
| Fresh Rojo place and sourcemap | PASS — nonempty build and Script/LocalScript mapping; exit 0 |
| `git diff --check` and source/test whitespace checks | PASS |
| Independent coin-route review | APPROVE — no actionable defects; automated checks rerun |
| Full Roblox-aware typecheck | NOT RUN — Instance/global type environment not configured |
| New Coin / inventory / selling Studio checks | NOT RUN — deferred by user |

Pure coverage includes direct credit, malformed wallet/reward and overflow,
metal-only inventory, combined wallet accounting, and 100 Coin lifecycles with
two simulated contenders, stale tokens, replays and rejected requests. The player
state regression loads the actual service with only module-path substitutions
and small service/player mocks. It checks both branches, isolation, ignoring
display attributes, repeat sales, and removal/rejoin. These mocks do not prove
Roblox attributes, signals, replication, physics or real RemoteEvent concurrency.

Changes since selling delivery: `src/shared/CollectibleDefinitions.luau`,
`src/shared/CollectionRules.luau`, `src/shared/SaleRules.luau`,
`src/shared/InventoryRules.luau` (comment), `src/server/Services/PlayerStateService.luau`,
`src/server/Services/PrototypeWorldService.luau`, `src/server/Services/CollectibleService.luau`
(comment), `src/server/main.server.luau`, `src/client/Controllers/AttractionController.luau`,
`src/client/Controllers/HudController.luau`, rule/adversarial tests,
`scripts/test-hud.mjs`, new `scripts/test-player-state.mjs`, `scripts/check.mjs`,
and the product/evidence docs including the AGENTS project appendix.

Simplifications: reuse the collectible registry, claim rules, animation, wallet
and sale service; filter metals rather than creating a second inventory or coin
remote. Remaining risk: engine-aware types and actual Coin rendering/replication,
multiplayer and device behavior remain unverified. Updated unpublished local place:
`build/MagnetMayhem.rbxlx`. Tools/builds stay ignored; mock temp dirs are cleaned.

## Selling extension evidence (2026-10-13, macOS, historical)

The metal-only selling snapshot below predates independent map Coin pickups.

The user explicitly requested selling after inventory. The current loop supersedes
the earlier direct coin payout: **collect inventory, then sell it for coins**.
Pickup grants one metal unit and no coins. The Inventory panel's `Sell all` button
works anywhere, shows estimated value and is disabled when empty. Unit prices are
Bolt 1, Can 3 and Gear 5; collecting one of each then selling pays 9 coins.

`RequestSellAll` accepts zero arguments; even an explicit nil argument is rejected.
The server uses its own session table and frozen catalog prices, validates the
entire sale before mutation, and consumes inventory/credits coins without yielding.
Empty and repeated sales pay zero. Invalid/negative/fractional/nonfinite values,
unknown IDs and unsafe integer arithmetic reject without partial clearing or credit.
The safe-integer limit is a representation guard, not a gameplay bag capacity.
Sales use their own 2 requests/second, burst-2 token bucket; player removal cleans
both request buckets. Collection validation and the three-key cosmetic payload
remain unchanged.

No persistence, selling zone, upgrades, Book, Combo, Fusion, purchases or runtime
dependencies were added. Reset/leave behavior remains session-only. Coin/count
attributes can arrive separately; server tables, not HUD snapshots, are authoritative.

Fresh command (same official Luau 0.742 / Rojo 7.7.1 / Node 22.16.0 macOS tools):

```bash
node scripts/check.mjs \
  --luau .tools/luau/luau \
  --analyze .tools/luau/luau-analyze \
  --compile .tools/luau/luau-compile \
  --rojo "$HOME/.rokit/tool-storage/rojo-rbx/rojo/7.7.1/rojo"
```

| Check | Actual result |
| --- | --- |
| `luau tests/run.luau` | PASS — 67 passed, 0 failed; exit 0 |
| `luau tests/adversarial.luau` | PASS — 3 passed, 0 failed; exit 0 |
| `node scripts/test-hud.mjs .tools/luau/luau` | PASS — 5 mocked presentation checks; exit 0 |
| `luau-analyze src/shared tests` | PASS — no diagnostics; exit 0 |
| `luau-compile --null` on all source/test files | PASS — exit 0 |
| Node syntax checks for both scripts | PASS — exit 0 |
| Structure/scope/strict-header checks | PASS — 13 source modules |
| Fresh Rojo build and sourcemap | PASS — nonempty local place and Script/LocalScript mapping; exit 0 |
| `git diff --check` and source/test whitespace checks | PASS |
| Independent review after HUD fix | APPROVE — no unresolved issues; all automated checks rerun |
| Full Roblox-aware typecheck | NOT RUN — Roblox Instance/global type environment not configured |
| Selling Studio / real remote / mobile tests | NOT RUN — deferred by user |

Sale tests cover exact mixed value, empty/repeated sales, subsequent pickups,
player isolation, malformed whole-sale rollback and multiplication/sum/balance
overflow. Adversarial tests simulate collect→sell→replay across 100 lifecycles
without double payment; this is domain simulation, not real concurrent networking.

An independent review caught a shadowed HUD sale-value accumulator, including a
possible nil arithmetic failure before attribute replication. It was fixed using
distinct variable names. The persistent HUD regression extracts the actual update
function and tests missing/partial/non-number attributes, three metals estimating
9 coins, toggle text and post-sale counts/coins. Scalar mocks do **not** exercise
GUI sizing, signals, RemoteEvents or the full Roblox adapter. The test deletes
its own freshly created ignored temporary directory on success or failure.

Selling changes: `src/shared/SaleRules.luau`,
`src/server/Services/PlayerStateService.luau`, `src/server/Services/CollectibleService.luau`,
`src/server/main.server.luau`, `src/shared/MagnetConfig.luau`,
`src/client/Controllers/HudController.luau`, `tests/SaleRules.spec.luau`,
`tests/InventoryRules.spec.luau`, `tests/CollectionRules.spec.luau`,
`tests/run.luau`, `tests/adversarial.luau`, `scripts/test-hud.mjs`,
`scripts/check.mjs`, and the product/evidence docs including the AGENTS project appendix.

Simplifications: reuse the existing inventory panel, remote factory and player
session service; add only a no-argument sale request and pure transaction rules.
Remaining risk is the deferred engine-aware/runtime/UI boundary described above.
Updated place: `build/MagnetMayhem.rbxlx` (ignored, unpublished).

## Session-inventory extension evidence (2026-10-13, macOS, historical)

This inventory-only snapshot was superseded by the selling extension above;
its immediate coin payout is no longer the current behavior.

Implemented scope:

- Every accepted pickup adds one Bolt, Can or Gear, alongside unchanged 1/3/5 coins.
- Server session tables own quantities. Replicated `Inventory_bolt`, `Inventory_can`
  and `Inventory_gear` attributes are read-only presentation inputs for the client.
- The Inventory button opens/closes per-type quantities and shows the total count.
- Coins/counts survive character resets and reset on leave/new session.
- No gameplay capacity limit, selling, persistence, upgrades, Book, Combo, Fusion,
  purchases or new runtime dependencies were added.
- Existing synchronous claim, server rate limiting and the exact cosmetic-only
  `CollectionResult` payload are preserved.

Tools: existing Rojo 7.7.1 executable at
`$HOME/.rokit/tool-storage/rojo-rbx/rojo/7.7.1/rojo`, Node.js 22.16.0, and official
standalone Luau 0.742 macOS arm64 tools extracted under ignored `.tools/luau/`.
No global install or Rokit manifest changes were made.

Executed command:

```bash
node scripts/check.mjs \
  --luau .tools/luau/luau \
  --analyze .tools/luau/luau-analyze \
  --compile .tools/luau/luau-compile \
  --rojo "$HOME/.rokit/tool-storage/rojo-rbx/rojo/7.7.1/rojo"
```

| Check | Actual result |
| --- | --- |
| `luau tests/run.luau` | PASS — 26 passed, 0 failed; exit 0 |
| `luau tests/adversarial.luau` | PASS — 3 passed, 0 failed; exit 0 |
| `luau-analyze src/shared tests` | PASS — no diagnostics; exit 0 |
| `luau-compile --null` on all source/test files | PASS — exit 0 |
| Structure/scope/strict-header checks | PASS — 12 source modules |
| Rojo build and sourcemap | PASS — fresh nonempty place and Script/LocalScript mapping; exit 0 |
| `git diff --check` and source/test whitespace checks | PASS |
| Independent read-only review | APPROVE — no actionable inventory code/security defects; checks rerun |
| Full Roblox-aware typecheck | NOT RUN — Roblox Instance/global type environment not configured |
| New inventory Studio / replication / reset / touch tests | NOT RUN — deferred by user |

New pure tests cover catalog zero counts, isolated sessions, one unit per pickup
regardless of reward, hostile IDs, rejection without mutation, lifecycle replays
and respawns. The 100-lifecycle adversarial simulation additionally proves one
combined inventory grant per simulated spawn across two contenders. These are
**domain tests, not Roblox adapter or real network tests**.

Changed files for this extension: `src/shared/InventoryRules.luau`,
`src/server/Services/PlayerStateService.luau`, `src/server/Services/CollectibleService.luau`,
`src/server/main.server.luau`, `src/client/Controllers/HudController.luau`,
`tests/InventoryRules.spec.luau`, `tests/run.luau`, `tests/adversarial.luau`,
`AGENTS.md` (project appendix only), `PRD.md`, `README.md`,
`docs/STUDIO_VERIFICATION.md`, and this evidence file.

Simplifications: extend existing player state and HUD, use three replicated scalar
attributes instead of another inventory remote, and keep the existing direct coin
economy. Local attraction effects do not award inventory. Attribute changes are
not an atomic coin/count snapshot; only server tables are authoritative.

Remaining risks: inventory adapters, actual GUI layout/touch, character-reset
behavior and replication need Studio checks later. The refreshed unpublished
place is `build/MagnetMayhem.rbxlx`; it and the development tools remain ignored.

## Original milestone automated evidence (2026-10-13, historical)

Tools: Rojo 7.7.1 (existing sibling-workspace executable), official standalone
Luau 0.742 (downloaded into ignored `.tools/luau/`, no global installation), Node.js.
No runtime packages/dependencies were added.

| Check | Actual result |
| --- | --- |
| `luau tests/run.luau` | PASS — 20 passed, 0 failed; exit 0 |
| `luau tests/adversarial.luau` | PASS — 3 passed, 0 failed; exit 0 |
| `luau-analyze src/shared tests` | PASS — no diagnostics; exit 0 |
| `luau-compile --null` on all source/test files | PASS — compilation exit 0 |
| `rojo build default.project.json -o build/MagnetMayhem.rbxlx` | PASS — nonempty local place, exit 0 |
| `rojo sourcemap default.project.json --output build/sourcemap.json` | PASS — correct Script/LocalScript mapping, exit 0 |
| `node scripts/check.mjs --rojo C:\Secret\tower-slash\.tools\rojo.exe` | PASS — available checks, structure/scope/strict headers, exit 0 |
| `git diff --check` plus source/test whitespace checks | PASS |
| Independent read-only code review | APPROVE — no actionable code/security bugs found |
| Full Roblox-aware typecheck | NOT RUN — Roblox Instance/global type environment not configured |
| Standalone StyLua/Selene | NOT RUN — tools unavailable; Luau pure analysis supplies its own diagnostics |
| Roblox Studio runtime / real multiplayer / mobile UI | NOT RUN — requires manual Studio interaction |

An initial pure-analysis failure from Luau dictionary-value invariance was fixed
by matching the scalar catalog type without `any` casts or weakening strictness.
All subsequent automated checks pass. Pure tests exercise exact rewards, malformed
numeric facts, range boundaries, missing/dead-character facts, stale tokens,
duplicate claims, respawn generations and request-bucket behavior.

Adversarial tests dynamically simulate 100 spawn lifecycles and alternating
contenders with replays, hostile/oversized/Unicode object IDs and rejection followed
by a legitimate claim. This is deterministic **domain simulation, not proof of
Roblox RemoteEvent/networking/concurrent execution**.

## Original prototype changed product files

- `PRD.md`, `README.md`, `VALIDATION.md`, `default.project.json`
- `AGENTS.md` (project appendix; existing orchestration instructions preserved)
- `.gitignore` (local tools/build/Studio artifacts ignored)
- `src/shared/CollectibleDefinitions.luau`
- `src/shared/MagnetConfig.luau`
- `src/shared/CollectionRules.luau`
- `src/server/main.server.luau`
- `src/server/Services/PlayerStateService.luau`
- `src/server/Services/PrototypeWorldService.luau`
- `src/server/Services/CollectibleService.luau`
- `src/client/main.client.luau`
- `src/client/Controllers/MagnetController.luau`
- `src/client/Controllers/AttractionController.luau`
- `src/client/Controllers/HudController.luau`
- `tests/TestHarness.luau`, `tests/CollectionRules.spec.luau`
- `tests/run.luau`, `tests/adversarial.luau`
- `scripts/check.mjs`
- `docs/STUDIO_VERIFICATION.md`

At original delivery the repository had no commit, so product files appeared
untracked rather than as a normal base-commit diff. Existing `.codex/` files were preserved.
Generated `.tools/` binaries and `build/` output are intentionally ignored, not
source deliverables. Local place: `build/MagnetMayhem.rbxlx`.

## Original prototype architecture evidence and deliberate simplifications

- Rojo explicitly separates shared/server/client service trees.
- Registry state and session balances are server-owned; client attributes are hints.
- The request path type/length/rate-checks input and validates target registry,
  character health/root, server distance, current lifecycle and availability.
- `Rules.claim` consumes availability synchronously before award/remote/timer.
- Winner presentation contains only `{ lifecycleId, objectId, startCFrame }`.
- HUD reads `Player.Coins`; animation cannot award/revoke coins or move server parts.
- Player removal clears session state and request buckets; target removal invalidates registry.
- Frozen scalar configuration, native Roblox services and disposable local parts
  replace networking frameworks, server attraction physics and dependency packages.
- Floor/spawn are serialized in Rojo rather than created after characters spawn.
- Coins are direct, session-only rewards. No selling, persistence, Book, Combo,
  Fusion, upgrades or monetization implementation is present.

## Remaining manual boundary

Two-player and selling verification are now USER-REPORTED PASS. Individual
security/network/feedback cases remain unrecorded, and mobile checks are deferred
until development is finished. Follow `docs/STUDIO_VERIFICATION.md` for detailed
runtime/device acceptance before claiming release readiness, not as a mobile
prerequisite for requested feature development. The server validates collection
proximity, but comprehensive movement/teleport anti-cheat is not implemented.
