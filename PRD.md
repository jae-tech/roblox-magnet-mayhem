# Magnet Mayhem — Product Requirements

## Product and constraints

A small Roblox simulator for global PC/mobile players, built by a solo developer
with AI assistance and five human development hours per week. Prioritize a fun,
repeatable loop over polish. Use Luau, Rojo and Roblox Studio, with no external
backend or runtime packages. Publishing and real monetization require approval.

## Milestone 1: initial playable prototype (current scope)

Approach metal → automatic magnet pickup → cosmetic attraction → earn coins.
Coins are awarded directly; selling and persistent data are deliberately deferred.
Coins survive character resets but reset when leaving/restarting the server session.

| Object | Reward | Placeholder |
| --- | ---: | --- |
| Bolt | 1 coin | Small silver block |
| Can | 3 coins | Blue cylinder |
| Gear | 5 coins | Gold disc |

- One visible starter magnet follows the character; no precision click/tap required.
- Attraction radius: 12 studs, server tolerance: 1 stud.
- Client scans every 0.15 seconds and presents only accepted pickups.
- Server owns target identity, availability, spawn token, position and reward.
- Each spawn token rewards at most once; objects respawn after 5 seconds.
- A minimal English HUD displays authoritative session coins on PC/mobile.
- Strict Luau modules where practical; engine-independent rules have automated tests.

## Authority contract

`RequestCollect(target: Instance, lifecycleId: string)` is advisory. The server
validates type/length, request rate, registry membership, lifecycle, availability,
living character/root and server-measured distance. The claim occurs without
yielding before award/presentation. No client reward/balance/position is accepted.
`CollectionResult` contains exactly `{ lifecycleId, objectId, startCFrame }` and
is cosmetic only. The HUD reads the server's replicated `Player.Coins` attribute.
Local animation never moves the authoritative part or grants coins.

## Independently testable milestones and gate

1. Scaffold/definitions: three valid definitions and distinct Rojo service mappings.
2. Pure rules: inclusive distance, invalid numeric facts, stale tokens and duplicates.
3. Server: validated at-most-once claim/reward, respawn and player-state cleanup.
4. Client: visible magnet, accepted-result animation, reset cleanup and coin HUD.
5. Integration: automated checks plus the manual Studio matrix in
   `docs/STUDIO_VERIFICATION.md`.

Acceptance requires exact configured rewards, no rewards outside range or for
invalid/replayed tokens, repeatable respawns, one winner in a two-player race,
readable phone/tablet HUD and no runtime errors. A Rojo build or pure test is
not a Studio playtest. **Studio verification is pending; later systems remain gated.**

## Roadmap only — do not implement before Milestone 1 is verified

- Selling/inventory and Roblox DataStore persistence: server-validated economy,
  failure/retry/session handling and permanent progression.
- Collection Book: 15 metals; Common/Rare/Epic/Legendary; permanent discovery;
  milestone rewards.
- Chain Combo: consecutive collection within 2 seconds; 1.0x–2.5x multipliers;
  server-calculated rewards and client effects.
- Magnet Fusion: three identical-tier magnets produce one higher-tier magnet;
  five initial tiers, guaranteed success and heavier-object unlocks.
- Monetization: only after separate approval; no purchases/passes configured now.

## Verification reporting

Record actual checks, failures and unavailable tools in `VALIDATION.md`.
Roblox Studio, replication, physics, real races and viewport behavior must remain
NOT RUN until actually exercised. No publishing or API Services configuration is
needed for this session-only prototype.
