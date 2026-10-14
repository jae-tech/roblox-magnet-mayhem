# Design

## Source of truth
Status: Active. Date: 2026-10-14. Surfaces: Roblox PC/mobile HUD and prototype
world hints. Evidence: `PRD.md`, `README.md`, `HudController.luau`,
`PrototypeWorldService.luau` and `docs/STUDIO_VERIFICATION.md`. No screenshots,
brand assets or independently verified Studio/device evidence are available.
Current change: separate cosmetic magnet looks from coin-priced range, magnetic
power and movement-speed upgrades. Carry the magnet with both hands in front.
Cosmetic catalog: Starter (free), Iron (25 coins), Gold (100 coins), no stats.
Prices are prototype tuning values, not paid purchases or a monetization decision.

## Brand
Small, playful magnet simulator. Show trustworthy server-backed balances; avoid
purchase prompts, false reward promises and noisy full-screen effects.

## Product goals
Make the two existing earning paths understandable: Coins pay immediately;
metals enter inventory and pay on sale. Spend coins on independent stats or a
magnet appearance; appearance never confers a gameplay advantage. Persist coins, metal inventory and
equipped magnet and metal discoveries together in live mode. Give players a
visible 15-metal collection goal with server-awarded milestone bonuses.
Non-goals: paid purchases,
consumables, bags, fusion or other new progression systems.
Success signals: players can identify an object, understand its payout route and
see a sale receipt without mistaking a client estimate for a reward.

## Personas and jobs
Global casual PC/mobile players walking around the prototype. They need to find
collectibles, recognize automatic pickup and sell held metals without precise
target clicking. English copy follows the existing prototype convention.

## Information architecture
Top: authoritative Coins, guidance/latest feedback, then storage status.
Next: side-by-side Inventory, Shop and Book toggles. Open only one panel at a time.
Inventory: Sell all/estimated value first, then fifteen metal counts and a
storage-status note, so the core action is not buried below the expanded list.
Shop: current appearance and three cosmetic cards with price/ownership/equip
state. Buy any affordable look; owned looks can be equipped without paying again.
Right edge: three always-present Range/Power/Speed icon buttons; one press buys
the next level, with no additional panel or confirmation. Show level, current/next
value and next price. World: per-object name and earning-route hint.
Book: discovery count / 15, automatic milestones, then ordered discovery rows.
Unseen entries show `???` and rarity; discovered entries show name and rarity.
Coin is excluded. Rarity classifies catalog entries, not random drop probability.
Prototype milestone tuning: 3 discoveries → 10 coins, 7 → 30, 15 → 100.

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
images, sound or flashing. Magnetic power shortens accepted-pickup animation;
two-handed procedural carrying replaces the floating side prop.

## Components
- Coins header: guidance/one transient receipt plus storage-status line; unknown
  balance displays `Coins: --` until data is ready.
- Inventory/Sell all: existing panel; empty/ready/short cooldown states.
- Shop toggle/panel: reuse scrolling patterns; cosmetic-only Starter/Iron/Gold
  with equipped / owned-free-equip / affordable / shortfall states. No tier gate.
- Upgrade dock: right-side three icon buttons with text, current/next value,
  level and coin cost; loading / insufficient / buying / max states. Native
  code-drawn target/magnet/chevron icons need no external image assets.
- PickupHint: BillboardGui, object name plus immediate payout or sale unit price;
  replace price line with `Respawning...` while the spawn is unavailable.
- Book: read-only scrolling panel; locked/discovered rows use text plus four
  rarity colors (Common/Rare/Epic/Legendary). Rewards are automatic; no claim button.
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
The navigation row splits into three equal-width short-label toggles.
Reserve a 106px right dock plus 12px gutters; center panels occupy the remaining
width (maximum 420px) rather than covering the upgrade buttons. Dock cards are
88px tall with 8px gaps. Final mobile legibility remains unverified.
Scrolling canvas height follows UIListLayout's measured content plus outer
padding explicitly, independent of the constrained panel height. Recalculate on
content, visible-window and visibility changes; clamp scroll position on shrink.
World hints have a compact 170×68px footprint including metal rarity.

## Interaction states
Initial/missing attributes display an unknown wallet and disable economy actions.
Ready empty inventory disables selling. A
sale click shows `Selling...` for the existing 0.5-second courtesy cooldown;
this is not a transaction or acknowledgement lock. A separate server receipt
shows the actual payout (or empty inventory), independent of attribute ordering.
Late receipts do not release a newer cooldown. Invalid/rate-limited requests
remain silent; no automatic retries or inferred-success messages are added.
Newest pickup/sale feedback wins; stale timers and destroyed GUIs cannot update it.
Shop: owned-free-equip / equipped / insufficient coins / ready / short buying
cooldown. Client affordability is a hint only; server checks balance and
ownership atomically. Repeat purchases of the same skin cannot charge again.
Purchase receipts never update coins/tier; replicated attributes do. No retries
are automated and late receipts do not release a newer purchase cooldown.
Upgrades: current desired level is explicit in each request; repeated old-level
requests cannot buy another level. Three stats are independent, capped at level
5, share a short upgrade courtesy cooldown and separate server bucket from skins.
Power improves scan/ghost speed and allowed server collection throughput; it is
not a sale multiplier or authority to move server parts. Speed is applied by the
server to the live and replacement Humanoid. Appearance changes do not alter stats.
Storage: Loading / Preview / Ready / Dirty / Saving / Saved / SaveDelayed /
Closing / Error. Live readiness and lease ownership are private server state.
Loading/closing/error disables selling/buying and automatic scan presentation.
Transient save errors show delay while the valid lease remains; lease loss freezes
the economy and disconnects the player rather than allowing unsafe progress.
Book: loading / no discoveries / partial / complete; selling never clears
discoveries, repeated pickups never grant the same milestone again. Live rejoin
restores the book; Preview resets it. Legacy profiles start with no discoveries
because earlier sessions did not record them; no historical or retroactive reward.

## Content voice
Short, literal English: `Coin: +1 coin`, `Bolt: +1 in inventory`,
`Sold metal: +9 coins`, `Inventory is empty`, `Respawning...`. Only server
receipts say a sale completed; displayed sale estimates remain hints.
Shop copy: `Buy Iron (25 coins)`, `Need N more coins`, `Equipped`, `Equip Gold`,
`Buying...`, `Bought Iron (appearance only)`. Upgrade copy: `Range L0`,
`12 > 18 studs`, `25 coins`, `Need N coins`, `Upgrading...`, `MAX`. Storage copy:
`Preview: progress is not saved`, `Loading saved progress...`, `Progress loaded`,
`Waiting for auto-save`, `Saving progress...`, `Progress saved`,
`Save delayed - retrying`, `Data unavailable - rejoin to retry`.
Panel notes reuse the same status, not an obsolete leave-reset promise. Saving is
bounded best-effort; do not promise zero progress loss on crash or service outage.
Book copy: `Discovered: N / 15`, `??? | Rare`, `Gear | Rare`, and
`Discovered Gear (3/15) +10 coins` only for a server-confirmed discovery receipt.

## Implementation constraints
Strict Luau, existing Roblox GUI/RemoteEvent APIs, no runtime packages. New
SaleResult is server-to-client cosmetic data: one nonnegative integer payout.
CollectionResult remains exactly lifecycleId/objectId/startCFrame. Wallet and
inventory display continue reading replicated attributes only. Verify pure rules,
actual-module mock regressions, source compilation and Rojo build; distinguish
these from missing engine-aware typing and deferred Studio/network/device tests.
Shop uses a frozen cosmetic `MagnetDefinitions` catalog. RequestBuyMagnet accepts
exactly one requested tier, not price/balance/range. ShopResult carries only a
status and tier for cosmetic receipts. Coins and equipped tier change together
without yielding. Private upgrade levels alone determine range, power and speed;
MagnetTier is appearance only. RequestUpgrade accepts an ID and desired level,
never a price/value. UpgradeResult is cosmetic status/upgradeId/level only.
Storage uses the server-only persistence adapter; no save/load RemoteEvent exists.
Default Studio Preview makes zero DataStoreService calls. API Services settings,
publishing and purchase configuration are not changed by development.
CollectionBookResult is a cosmetic exact objectId/count/reward receipt; it cannot
change discoveries, wallet or inventory. Version-3 profiles add owned skins and
independent upgrades. Valid version-1/2 saves migrate with previous ownership and
range preserved; store namespace stays unchanged. Local R15 IK/R6 joint poses and
ghosts cannot grant anything; death/readiness/reset/skin changes clean up the pose.
R6 prop placement derives from both arms' actual reach and shoulder pivots;
incomplete or unsupported rigs hide the prop instead of faking hand contact.
Visual contact, walking and avatar scaling require the deferred Studio pass.

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
