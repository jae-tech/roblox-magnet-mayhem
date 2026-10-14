# Magnet Mayhem — Product Requirements

## Product and constraints

A small Roblox simulator for global PC/mobile players, built by a solo developer
with AI assistance and five human development hours per week. Prioritize a fun,
repeatable loop over polish. Use Luau, Rojo and Roblox Studio, with no external
backend or runtime packages. Publishing and real monetization require approval.

## Milestone 1: initial playable prototype

The original direct-payout milestone has been superseded by the explicitly
requested earning routes below. Current loops:
- Approach metal → automatic pickup → inventory → sell all → earn coins.
- Approach a map Coin → automatic pickup → immediately earn 1 coin.

These are independent sale routes: metals never pay their sale value at pickup,
and map Coins never enter inventory or contribute to sale value. First-discovery
Book milestones are a separate automatic coin reward.
Coins can also buy sequential, automatically equipped magnet upgrades.
The Collection Book records first discoveries of 15 distinct metals and grants
automatic one-time milestone coins; map Coin pickups do not count as discoveries.
The persistent-profile extension saves coins, all 15 metal counts, the equipped
tier and permanent discoveries together in live servers. All survive character
resets; default Studio Preview intentionally resets on leave or Stop/Play and does not save.

| Object | Earning route |
| --- | ---: |
| Bolt / Can / Gear | Sell for 1 / 3 / 5 coins/unit |
| Washer / Nut / Screw / Nail | Sell for 2 / 2 / 1 / 1 coins/unit |
| Chain / Lock / Spring | Sell for 8 / 10 / 12 coins/unit |
| Battery / Circuit / Motor | Sell for 18 / 22 / 30 coins/unit |
| Metal Crystal / Golden Crown | Sell for 45 / 60 coins/unit |
| Coin | Immediate 1 coin/pickup; not inventory or discovery |

- One visible starter magnet follows the character; no precision click/tap required.
- Initial attraction radius: 12 studs, upgraded to 18/24 by the requested shop;
  server distance tolerance remains 1 stud.
- Client scans every 0.15 seconds and presents only accepted pickups.
- Server owns target identity, availability, spawn token, position and reward.
- Catalog entries distinguish `kind = "Metal"` and `kind = "Coin"`; Bolt/Can/Gear
  and the twelve added entries are metals. `id = "coin"`, name `Coin`, reward 1
  is the direct-coin pickup; 16 map definitions represent 15 metals plus Coin.
- Each spawn token grants its configured outcome at most once. All collectibles
  use the same range/lifecycle/rate checks and respawn after 5 seconds.
- A minimal English HUD displays authoritative coins on PC/mobile.
- Each collectible has a `PickupHint` Billboard label with its name and immediate
  Coin reward or metal rarity and sale price per unit; unavailable spawns show `Respawning...`.
- Strict Luau modules where practical; engine-independent rules have automated tests.

## Requested extension: map coins, inventory and selling (current scope)

The user requested map coin pickups alongside inventory and selling. On
2026-10-13 the user reported two-player and selling verification complete and
deferred mobile testing until development is finished. This report is accepted
as user verification, not a detailed independently observed checklist pass.
It does not automatically add other roadmap systems to the implemented scope.

- Each accepted metal pickup adds exactly one unit of its catalog metal, with no
  immediate sale payout. A first discovery may separately grant a Book milestone
  reward; this does not double-pay the metal sale value.
- Each accepted Coin pickup increases the wallet by exactly 1, without changing
  metal counts or sale estimates. Coins cannot be sold.
- The inventory panel shows estimated total value and a `Sell all` button usable
  anywhere, disabled while empty. Selling consumes all held units and credits
  exactly the sum of each held metal count multiplied by its catalog sale value.
  Original Bolt/Can/Gear values remain 1/3/5 coins per unit.
- `RequestSellAll` has no arguments. Supplied arguments are rejected; all counts
  and prices come from server state/configuration. Empty or repeated sales grant
  zero coins. Consumption and credit are synchronous, without yielding.
- Sales use a separate server token bucket: 2 requests/second, burst 2. Collection
  rate limiting remains unchanged.
- The server owns counts and replicates `Inventory_<metalId>` Player attributes
  for all 15 metals; clients cannot grant or change inventory.
- An English `Inventory: N` HUD button toggles a panel containing all
  15 metal quantities; Coin is not an inventory row.
- There is no capacity limit. Counts and coins survive character resets and load
  from live saved profiles on rejoin; default Studio Preview does not persist.
- Accepted pickups produce a transient second-line HUD receipt, such as
  `Coin: +1 coin` or `Bolt: +1 in inventory`. Server-confirmed sales display
  `Sold metal: +N coins`; accepted empty sales display `Inventory is empty`.
  Newest feedback replaces older feedback and restores the default hint after
  3 seconds. Wallet/attribute changes do not imply a sale or generate receipts.
- The sale button reads `Selling...` and is disabled during its local 0.5-second
  courtesy cooldown. It is not locked waiting for acknowledgement; delayed
  results cannot release a newer cooldown. Destroying/recreating the HUD removes
  old event connections and prevents old timers from changing the new UI.
- No selling zone, capacity limit, Combo, Fusion or Robux purchases are included.
  The Collection Book extension is described below. Magnet upgrades are limited
  to the separately requested coin shop below.

## Requested extension: coin-only magnet shop (current scope)

The user explicitly requested a shop. Implement a local coin economy shop, not
monetization or publishing. Persistence is a separate requested extension below.

| Ordered tier | Name | Coin price | Radius | Visual color |
| --- | --- | ---: | ---: | --- |
| 1 | Starter | 0; initially equipped | 12 studs | Red |
| 2 | Iron | 25 | 18 studs | Blue |
| 3 | Gold | 100 | 24 studs | Gold |

- `Shop` toggles a scrolling HUD panel usable anywhere. Opening Shop closes
  Inventory and Book; opening any of these closes the others. Each panel
  remains independently toggleable.
- Purchase only the next tier; Starter → Iron → Gold. A successful purchase
  automatically equips the tier. There is no owned-magnet inventory, downgrade,
  fusion or buy-back flow. Prices are incremental: both upgrades cost 125 total.
- Purchase atomically validates server coins, deducts the frozen catalog price
  and advances the private session tier without yielding. It never consumes,
  creates or sells metal inventory. Insufficient funds leave all state unchanged.
- Requesting any owned tier returns `owned` without charge. Repeating a request
  for Iron after buying Iron cannot implicitly request or purchase Gold.
  Skipping a tier returns `locked`; invalid tier values cannot change state.
- `RequestBuyMagnet` accepts exactly one requested integer tier. Supplied price,
  balance, radius, quantity, another player or additional nil arguments are
  rejected. Unknown/noninteger/out-of-range tiers are rejected without mutation.
- Purchases have an independent server limiter of 2 requests/second, burst 2;
  collection and sale limiters remain intact.
- Server collection checks derive radius from the private session tier and frozen
  catalog, never replicated Player attributes. Client scanning uses the catalog
  tier as a hint; magnet color changes are cosmetic. Both Coin and metal pickup
  routes use the equipped server radius with the existing 1-stud tolerance.
- `MagnetTier` and `MagnetRadius` are replicated for display only. Client prices, affordability and
  radius hints cannot authorize payment, grant upgrades or extend server range.
- `ShopResult` contains exactly `status` and `tier`; statuses are `purchased`,
  `insufficientCoins`, `owned`, `locked`, `invalidTier`. The pure rules retain
  `invalidTier`; the remote filters invalid tiers before invoking them, so invalid
  tier, malformed/extra-argument and throttled requests are silent. These receipts never mutate player state.
- Shop feedback shares the existing header and newest-message-wins 3-second
  expiry. The next-upgrade button reads `Buying...` during an independent local 0.5-second
  courtesy cooldown, not an acknowledgement lock. No automatic retries; late
  receipts cannot unlock a newer cooldown. HUD cleanup removes old connections
  and prevents old timers from changing a replacement GUI.
- The equipped tier survives character resets and loads from the live saved
  profile on rejoin. Default Studio Preview returns to Starter on leave or
  Stop/Play; Preview does not save coins or inventory either.
- New shop/upgrade/range Studio checks are NOT RUN. Keep the earlier two-player
  and selling USER-REPORTED PASS; defer mobile acceptance until development is
  finished, without blocking this requested feature.

## Development extension: Collection Book (current scope)

Following the user's instruction to continue development nonstop, implement the
next Collection Book roadmap slice. Final testing is deferred until development
is finished; implementation is not a release-readiness or runtime-pass claim.

- The catalog contains 15 metals plus the separate map Coin. Rarity labels divide
  metals into Common (Bolt, Can, Washer, Nut, Screw, Nail), Rare (Gear, Chain,
  Lock, Spring), Epic (Battery, Circuit, Motor) and Legendary (Metal Crystal,
  Golden Crown), with counts 6/4/3/2. All are available on the prototype map and respawn after 5 seconds. Rarity is a classification,
  not a random drop probability, zone gate or heavier-object unlock.
- `Book` opens a third scrolling HUD panel, mutually exclusive with Inventory
  and Shop. Show discovered count out of 15; unknown entries show `???` plus
  rarity, and discovered entries show their catalog name plus rarity. The tab
  reads `Book: N/15`, the progress line reads `Discovered: N / 15`, and milestone
  rows show `Reached` or the remaining `Need N`; there is no manual claim state.
- Only an accepted first pickup of a metal records that discovery. Coin pickups,
  repeated metal lifecycles, sales, resets and purchases cannot clear or duplicate
  it. Discovery belongs to the collecting player, not everyone near the object.
- The server automatically grants one-time milestone coins at 3 discoveries
  (+10), 7 (+30) and 15 (+100). These are tunable prototype values, not prices
  specified by the user. There is no claim button or client claim remote.
  Discovery, milestone payment and the inventory grant happen synchronously.
  Replicated `Discovered_<metalId>` booleans are display hints only; the server
  reads private discovery state, never these attributes, for eligibility.
- Sparse discovery stores only known metal IDs with the value `true`. The saved
  discovery count determines which milestones have already been earned; selling
  an inventory unit never removes its discovery or makes its milestone payable
  again. Live rejoin restores discovery, while default Studio Preview resets it.
- `CollectionBookResult` is server-to-client and contains exactly
  `{ objectId, count, reward }`. It presents the server-confirmed first discovery
  and any milestone payout only; it cannot grant coins, inventory or discovery.
  Existing `CollectionResult` retains its unchanged three-key cosmetic payload.
- Book, new metals, migration and milestone runtime checks are NOT RUN. Earlier
  user-reported two-player/selling passes do not validate this extension. Final
  tests/mobile acceptance remain deferred; Combo and Fusion are not implemented
  by this slice. Publishing, API access and Robux purchases remain unapproved.

## Requested extension: persistent profiles (current scope)

The user requested saving after the coin-only shop. The Collection Book extension
adds discovery and twelve metal counts to the same atomic profile. Persist coins,
all metal counts, equipped tier and discoveries; do not add fusion, Robux or a
client-supplied save/load API.

- Save one strict version-2 profile per user using server-side `UpdateAsync` for
  load/lease acquisition and whole-profile writes. Validate finite nonnegative
  safe-integer balances/counts and a catalog tier 1–3. Migrate only valid version-1
  records: preserve coins, Bolt/Can/Gear counts and tier; retain lease checks
  during decoding and permitted acquisition; initialize twelve new counts to
  zero and discovery to empty.
  Do not infer discoveries from old counts or grant retroactive milestones.
  Reject malformed records and unsupported versions without repair or overwrite.
- Install defaults only for a confirmed absent record. Load failure, invalid data
  or a competing live lease blocks play and disconnects the player without
  overwriting stored data or silently granting an empty profile.
- Own each live profile through a session lease lasting 180 seconds. Renew with
  60-second staggered autosaves; stop gameplay 15 seconds before local expiry
  without confirmed renewal. Saves from a missing, foreign or expired lease
  cannot overwrite storage. Serialized saves prevent stale local snapshots
  from passing newer snapshots within a session.
- Retry load/save at most 3 times with a 20-second retry/callback budget. Freeze
  state on leave, attempt a final save and release the lease. Shutdown starts
  closes in parallel and waits at most 25 seconds. A stuck network operation
  cannot be guaranteed to complete within these deadlines.
- Report unsaved/saving/error status honestly. Changes made after the last
  successful save may be lost during a crash/outage; a failed lease release can
  delay rejoin until expiry. Do not promise guaranteed saving.
- Default `allowStudioDataStore = false`: Studio uses Preview, never accesses
  `DataStoreService`, and starts with zero coins/counts, no discoveries and
  Starter. Preview progress resets on leave or Stop/Play, with an explicit unsaved-progress HUD
  warning. Live storage failure never switches to Preview.
- Keep the existing namespace despite profile version 2, so existing version-1
  records remain reachable. Production store: `MagnetMayhem_PlayerData_v1`.
  Optional, separately approved Studio tests use `MagnetMayhem_PlayerData_Studio_v1` in an isolated test
  experience. Publishing and enabling API access have not been performed or
  authorized. Studio can access live data; use a separate test experience rather
  than enabling access on the live game. [Roblox Studio storage warning](https://create.roblox.com/docs/cloud-services/data-stores#enable-studio-access)
- `StorageMode`, `DataStatus`, `DataReady` are replicated display hints only.
  Private loaded profile/lease state authorizes gameplay. Loading, closing and
  unsafe/error states disable sale/purchase controls and client scanning. A
  transient `SaveDelayed` with a valid lease does not itself freeze play; server
  handlers independently reject requests until the profile is usable.
- Keep current earning routes, shop prices/order/radii, synchronous economy
  mutation, independent request limiters and cosmetic-only remote payloads.
  No client attributes authorize rewards, saved values, ownership or range.
- New real storage, failure recovery, cross-server lease and shutdown checks are
  NOT RUN; earlier user-reported two-player/selling passes remain unchanged.
  Mobile testing stays deferred until development ends.

`UpdateAsync` can rerun its callback during conflicts; callbacks cannot yield
and nil cancels a write. Validation/lease decisions remain side-effect-free in
that callback. [GlobalDataStore.UpdateAsync](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore#UpdateAsync)

## Authority contract

`RequestCollect(target: Instance, lifecycleId: string)` is advisory. The server
validates type/length, request rate, registry membership, lifecycle, availability,
living character/root and server-measured distance. The claim occurs without
yielding before award/presentation. No client reward/balance/position is accepted.
`CollectionResult` contains exactly `{ lifecycleId, objectId, startCFrame }` and
is cosmetic only. The HUD reads the server's replicated `Coins`, inventory, discovery, `MagnetTier` and `MagnetRadius` Player attributes
for display; the server never reads those attributes as economy or range authority.
`SaleResult` is server-to-client only and carries one authoritative nonnegative
integer payout (zero for an accepted empty sale). Malformed or rate-limited sale
requests produce no result. Receipts are presentation only; they cannot grant
coins or inventory. `CollectionResult` keeps its three-key payload unchanged.
Local animation never moves the authoritative part or grants coins or inventory.

## Independently testable milestones and gate

1. Scaffold/definitions: 16 valid definitions (15 metals plus Coin) and distinct Rojo service mappings.
2. Pure rules: inclusive distance, invalid numeric facts, stale tokens and duplicates.
3. Server: validated at-most-once claim/reward, respawn and player-state cleanup.
4. Client: visible magnet, accepted-result animation, reset cleanup and coin HUD.
5. Integration: automated checks plus the manual Studio matrix in
   `docs/STUDIO_VERIFICATION.md`.

Acceptance requires exact configured Coin rewards, metal inventory grants and sale values, no grants outside range or for
invalid/replayed tokens, repeatable respawns, one winner in a two-player race,
sequential coin-priced upgrades with exact debit/equipped radius, first-only
discoveries and one-time milestone payment, valid version-1 migration, readable
phone/tablet HUD and no runtime errors. A Rojo build or pure test is
not a Studio playtest. **Two-player and selling verification: USER-REPORTED PASS
(2026-10-13). Mobile: NOT RUN, deferred until development is finished.** Detailed
security/network/feedback checklist results are not individually recorded. Full
device/runtime acceptance remains a release-readiness gate; mobile testing is
not a prerequisite for follow-on feature development. Shop, upgraded range and
upgrade visuals, Collection Book and real persistence are NOT RUN in Studio; earlier broad reports
do not validate them.
New roadmap features still
need a requested feature scope; no publishing or Robux purchases are authorized.

## Remaining roadmap — not implemented in this slice

- Chain Combo: consecutive collection within 2 seconds; 1.0x–2.5x multipliers;
  server-calculated rewards and client effects.
- Magnet Fusion: three identical-tier magnets produce one higher-tier magnet;
  five initial tiers, guaranteed success and heavier-object unlocks.
- Monetization: only after separate approval; no purchases/passes configured now.

## Verification reporting

Record actual checks, failures and unavailable tools in `VALIDATION.md`.
Distinguish USER-REPORTED PASS from independently observed results; do not infer
individual checklist coverage from a broad report. Unexercised checks remain
NOT RUN or NOT INDIVIDUALLY RECORDED. Mobile verification is scheduled after
development, before release readiness. Default local Preview needs no publishing
or API Services configuration. Real storage testing requires a separately approved,
isolated test experience; no such setup has been performed.
