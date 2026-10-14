# Design

## Source of truth
Status: Active. Date: 2026-10-14. Surfaces: Roblox PC/mobile HUD and prototype
world hints. Evidence: `PRD.md`, `README.md`, `HudController.luau`,
`PrototypeWorldService.luau` and `docs/STUDIO_VERIFICATION.md`. No screenshots,
brand assets or independently verified Studio/device evidence are available.
Current requested extensions: a coin-only magnet shop and persistent profiles. Initial catalog:
Starter (free, 12 studs), Iron (25 coins, 18 studs), Gold (100 coins, 24 studs).
Prices are prototype tuning values, not paid purchases or a monetization decision.

## Brand
Small, playful magnet simulator. Show trustworthy server-backed balances; avoid
purchase prompts, false reward promises and noisy full-screen effects.

## Product goals
Make the two existing earning paths understandable: Coins pay immediately;
metals enter inventory and pay on sale. Spend earned coins on a stronger magnet
with server-confirmed purchase and range. Persist coins, metal inventory and
equipped magnet together in live mode. Non-goals: paid purchases,
consumables, bags, fusion or other new progression systems.
Success signals: players can identify an object, understand its payout route and
see a sale receipt without mistaking a client estimate for a reward.

## Personas and jobs
Global casual PC/mobile players walking around the prototype. They need to find
collectibles, recognize automatic pickup and sell held metals without precise
target clicking. English copy follows the existing prototype convention.

## Information architecture
Top: authoritative Coins, guidance/latest feedback, then storage status.
Next: side-by-side Inventory and Shop toggles. Open only one panel at a time.
Inventory: three metal counts, estimated sale value, Sell all, storage-status note.
Shop: current magnet/radius and three tier cards with price, range and purchase
state. World: per-object name and earning-route hint. Purchases auto-equip; no
separate magnet storage/equip or physical shop zone is added.

## Design principles
Reuse the existing header instead of adding an overlapping toast. Feedback is
cosmetic, not state authority. Prefer the latest message over a growing queue.
Keep existing no-argument sale and collection security contracts unchanged.
Never show a successful save without confirmation. Loading or unavailable data
disables economy actions; no default profile is installed after a failed load.
Studio Preview is intentional and visibly unsaved, not a failed-live-load fallback.

## Visual language
Reuse dark navy HUD backgrounds, gold coin text, green sale action and catalog
metal colors. Gotham/GothamBold, existing 8–12px gaps and rounded corners. World
hints use compact white text over a translucent dark background. No new motion,
images, sound or flashing; existing accepted-pickup animation stays unchanged.

## Components
- Coins header: guidance/one transient receipt plus storage-status line; unknown
  balance displays `Coins: --` until data is ready.
- Inventory/Sell all: existing panel; empty/ready/short cooldown states.
- Shop toggle/panel: reuse inventory sizing/scroll patterns. Starter is owned;
  only the next tier is purchasable; later tiers are locked. Missing coins show
  the required amount. Purchase acts on a specific tier, never a client price.
- PickupHint: BillboardGui, object name plus immediate payout or sale unit price;
  replace price line with `Respawning...` while the spawn is unavailable.
Tokens stay in existing HUD/config/catalog files; no parallel UI framework.

## Accessibility
Use text as well as color to distinguish routes and results. Keep existing text
size constraints and Activated input for touch/gamepad/mouse. Hints require no
interaction, disappear beyond 60 studs and do not introduce sensory effects.
Contrast, focus and device legibility remain Studio checklist items, not verified
accessibility conformance claims.

## Responsive behavior
Preserve the centered 75%-width, max-420px HUD and scrolling panels on short
screens. Receipts reuse the three-line header so they add no overlay or obstruction.
The navigation row splits equally into Inventory/Shop with an 8px gap.
World hints have a fixed compact 170×52px footprint with a distance limit.

## Interaction states
Initial/missing attributes display an unknown wallet and disable economy actions.
Ready empty inventory disables selling. A
sale click shows `Selling...` for the existing 0.5-second courtesy cooldown;
this is not a transaction or acknowledgement lock. A separate server receipt
shows the actual payout (or empty inventory), independent of attribute ordering.
Late receipts do not release a newer cooldown. Invalid/rate-limited requests
remain silent; no automatic retries or inferred-success messages are added.
Newest pickup/sale feedback wins; stale timers and destroyed GUIs cannot update it.
Shop: owned / equipped / locked / insufficient coins / ready / short buying
cooldown. Client affordability is a hint only; server checks balance and ordered
ownership atomically. Repeat purchases of the same tier cannot charge again.
Purchase receipts never update coins/tier; replicated attributes do. No retries
are automated and late receipts do not release a newer purchase cooldown.
Storage: Loading / Preview / Ready / Dirty / Saving / Saved / SaveDelayed /
Closing / Error. Live readiness and lease ownership are private server state.
Loading/closing/error disables selling/buying and automatic scan presentation.
Transient save errors show delay while the valid lease remains; lease loss freezes
the economy and disconnects the player rather than allowing unsafe progress.

## Content voice
Short, literal English: `Coin: +1 coin`, `Bolt: +1 in inventory`,
`Sold metal: +9 coins`, `Inventory is empty`, `Respawning...`. Only server
receipts say a sale completed; displayed sale estimates remain hints.
Shop copy: `Buy Iron (25 coins)`, `Need N more coins`, `Equipped`, `Owned`,
`Locked`, `Buying...`, `Bought Iron — range 18 studs`. Storage copy:
`Preview: progress is not saved`, `Loading saved progress...`, `Progress loaded`,
`Waiting for auto-save`, `Saving progress...`, `Progress saved`,
`Save delayed - retrying`, `Data unavailable - rejoin to retry`.
Panel notes reuse the same status, not an obsolete leave-reset promise. Saving is
bounded best-effort; do not promise zero progress loss on crash or service outage.

## Implementation constraints
Strict Luau, existing Roblox GUI/RemoteEvent APIs, no runtime packages. New
SaleResult is server-to-client cosmetic data: one nonnegative integer payout.
CollectionResult remains exactly lifecycleId/objectId/startCFrame. Wallet and
inventory display continue reading replicated attributes only. Verify pure rules,
actual-module mock regressions, source compilation and Rojo build; distinguish
these from missing engine-aware typing and deferred Studio/network/device tests.
Shop uses a frozen scalar `MagnetDefinitions` catalog. RequestBuyMagnet accepts
exactly one requested tier, not price/balance/range. ShopResult carries only a
status and tier for cosmetic receipts. Coins and equipped tier change together
without yielding. The server uses session tier for collection range; clients may
read MagnetTier for scanning/appearance, but cannot expand server acceptance.
Storage uses the server-only persistence adapter; no save/load RemoteEvent exists.
Default Studio Preview makes zero DataStoreService calls. API Services settings,
publishing and purchase configuration are not changed by development.

## Open questions
- [ ] Actual phone/tablet hint and receipt legibility — owner: Studio QA;
  schedule: after development is finished per the user's 2026-10-13 update;
  impact: verify sizing/occlusion before claiming device readiness, not a current
  feature-development prerequisite.
- [ ] Observed slow-network ordering and respawn visuals — owner: Studio QA;
  impact: mocks do not prove Roblox replication/scheduling.
- [ ] Real DataStore restore/failure/lease/shutdown behavior — owner: final Studio QA;
  impact: requires a separately approved isolated test experience; current mocks
  and builds do not prove real backend behavior.
