# Magnet Mayhem

Milestone 1 Roblox/Luau prototype: automatic magnet attraction, three metals,
server-validated direct coin rewards, respawning objects and a minimal PC/mobile HUD.
No runtime dependencies, publishing, purchases, selling, or persistent data.

## Open the prototype

Use Rojo 7.x and the Rojo Studio plugin, or open a built place directly:

```powershell
rojo build default.project.json -o build/MagnetMayhem.rbxlx
rojo serve default.project.json
```

Create `build/` first if needed. Connect the plugin to `localhost:34872` in an
unpublished local place. Sync, press Play, then walk toward the three objects at
`(-20, 1.5, -24)`, `(0, 1.5, -24)`, `(20, 1.5, -24)`.
Bolt/Can/Gear grant 1/3/5 coins once per spawn and return after 5 seconds.
Collection is automatic; the red horseshoe is a client-only starter magnet visual.

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
```

The script also accepts `--analyze` and `--compile`. It discovers locally extracted
official Luau tools in `.tools/luau/` if present. Missing tools are printed as
NOT RUN; any available failing check exits nonzero. Pure tests prove domain
decisions, not real Roblox races. Full Roblox typechecking needs Roblox globals
and an Instance-aware type environment; standalone analysis is restricted to the
engine-independent shared modules/tests. See `VALIDATION.md` for actual results.

## Layout and authority

- `src/shared`: frozen scalar definitions/configuration, pure validation/claim rules.
- `src/server`: coin sessions, target registry, request throttling, claim and respawn.
- `src/client`: starter magnet visual, cosmetic homing ghost, coin-attribute HUD.
- `tests`: pure assertions plus adversarial lifecycle simulations.
- `docs/STUDIO_VERIFICATION.md`: exact runtime/multiplayer/mobile checklist.
- `PRD.md`: bounded requirements and gated future roadmap.

The client submits only a target and observed spawn token. The server decides all
rewards using server state and measured distance, claiming the target before any
side effect. `CollectionResult` carries appearance information only. HUD coins
come exclusively from the server's replicated Player attribute.

**Roblox Studio has not been tested.** Complete the manual checklist before calling
this milestone verified or implementing Collection Book, Combo, Fusion or monetization.

## Official references

- [Rojo project format](https://rojo.space/docs/v7/project-format/)
- [Roblox client/server validation](https://create.roblox.com/docs/scripting/security/client-server-boundary)
- [Official Luau tools](https://github.com/luau-lang/luau/releases)
