# Magnet Mayhem — Milestone 1 validation

## Delivery status

PRD and first-milestone code are implemented. **Roblox Studio was NOT RUN.**
The milestone remains pending Studio verification; later systems stay gated.
No game publishing, purchases or external backend was configured.

## Actual automated evidence (2026-10-13)

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

## Changed product files

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

The repository initially had no commit, so all product files appear untracked
rather than as a normal base-commit diff. Existing `.codex/` files were preserved.
Generated `.tools/` binaries and `build/` output are intentionally ignored, not
source deliverables. Local place: `build/MagnetMayhem.rbxlx`.

## Architecture evidence and deliberate simplifications

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

Follow all steps in `docs/STUDIO_VERIFICATION.md`: unpublished local Play test,
each exact reward/respawn/reset, malformed/replayed/out-of-range requests, two-client
races, desktop/phone/tablet viewports and server/client Output. Complete those rows
before calling Milestone 1 verified. The server validates collection proximity,
but comprehensive movement/teleport anti-cheat is not implemented in this prototype.
