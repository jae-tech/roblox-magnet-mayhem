import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
assert.equal(process.argv.length, 3, 'Usage: node scripts/test-player-state.mjs <luau executable>');
let source = fs.readFileSync(path.join(root, 'src/server/Services/PlayerStateService.luau'), 'utf8');
// Change only Roblox module lookup to standalone paths; execute real service logic.
source = source.replace(/require\(ReplicatedStorage\.Shared\.(\w+)\)/g,
  (_, name) => `require("../../src/shared/${name}")`);
const tools = path.join(root, '.tools');
fs.mkdirSync(tools, { recursive: true });
const directory = fs.mkdtempSync(path.join(tools, 'player-state-regression-'));
try {
  const script = path.join(directory, 'run.luau');
  fs.writeFileSync(script, `--!strict
-- Actual service logic with mocked services/players; NOT Roblox networking proof.
local clock = 100
local os = { clock = function() return clock end }
local Players = {}
local game = {}
function game:GetService(name: string): any
	if name == "Players" then return Players end
	assert(name == "ReplicatedStorage")
	return {}
end
local PlayerState = (function()
${source}
end)()
local function player(): any
	local result: any = { Parent = Players, attributes = {} }
	function result:SetAttribute(name: string, value: any)
		self.attributes[name] = value
	end
	return result
end
local first, second = player(), player()
PlayerState.add(first, require("../../src/shared/ProfileRules").defaults(), { mode = "Preview" })
PlayerState.add(second, require("../../src/shared/ProfileRules").defaults(), { mode = "Preview" })
assert(PlayerState.has(first))
assert(first.attributes.Coins == 0)
assert(first.attributes.MagnetTier == 1 and first.attributes.MagnetRadius == 12)
assert(PlayerState.getAttractionRadius(first) == 12)
assert(first.attributes.Inventory_coin == nil)
assert(first.attributes.Inventory_bolt == 0)
assert(first.attributes.Inventory_can == 0)
assert(first.attributes.Inventory_gear == 0)
print("PASS player state initializes only metal inventory and zero coins")
PlayerState.collect(first, "coin")
assert(first.attributes.Coins == 1)
assert(first.attributes.Inventory_coin == nil)
assert(second.attributes.Coins == 0)
print("PASS actual coin branch credits only wallet and isolates players")
for _, id in { "bolt", "can", "gear" } do
	PlayerState.collect(first, id)
	assert(first.attributes["Inventory_" .. id] == 1)
end
assert(first.attributes.Coins == 1)
assert(not pcall(PlayerState.add, first, require("../../src/shared/ProfileRules").defaults(), { mode = "Preview" }))
assert(first.attributes.Coins == 1)
assert(first.attributes.Inventory_can == 1)
assert(second.attributes.Inventory_can == 0)
print("PASS actual metal branch increments inventory without direct coin rewards")
first:SetAttribute("Coins", 99999)
first:SetAttribute("Inventory_can", 99999)
first:SetAttribute("Inventory_coin", 99999)
assert(PlayerState.sellAll(first) == 9)
assert(first.attributes.Coins == 10)
for _, id in { "bolt", "can", "gear" } do
	assert(first.attributes["Inventory_" .. id] == 0)
end
assert(PlayerState.sellAll(first) == 0)
assert(first.attributes.Coins == 10)
assert(second.attributes.Coins == 0)
print("PASS sale uses authoritative state, ignores spoofed attributes, never sells coins twice")
PlayerState.collect(first, "coin")
assert(first.attributes.Coins == 11)
PlayerState.collect(first, "gear")
assert(PlayerState.sellAll(first) == 5)
assert(first.attributes.Coins == 16)
assert(first.attributes.Inventory_gear == 0)
print("PASS coin pickups and later metal sales compose with existing wallet balance")
for _ = 1, 9 do PlayerState.collect(first, "coin") end
assert(first.attributes.Coins == 25)
first:SetAttribute("MagnetTier", 3)
first:SetAttribute("MagnetRadius", 10000)
assert(PlayerState.getAttractionRadius(first) == 12)
assert(PlayerState.buyMagnet(first, 3) == "locked")
assert(PlayerState.buyMagnet(first, 2) == "purchased")
assert(first.attributes.Coins == 0 and first.attributes.MagnetTier == 2 and first.attributes.MagnetRadius == 18)
assert(PlayerState.getAttractionRadius(first) == 18)
assert(PlayerState.buyMagnet(first, 2) == "owned")
assert(PlayerState.buyMagnet(first, 3) == "insufficientCoins")
assert(PlayerState.getAttractionRadius(second) == 12)
assert(not pcall(PlayerState.add, first, require("../../src/shared/ProfileRules").defaults(), { mode = "Preview" }))
assert(PlayerState.getAttractionRadius(first) == 18)
print("PASS real service purchases atomically, isolates players, ignores spoofed radius/tier and preserves character session")
PlayerState.remove(first)
assert(not PlayerState.has(first))
assert(not pcall(PlayerState.collect, first, "coin"))
assert(not pcall(PlayerState.sellAll, first))
PlayerState.add(first, require("../../src/shared/ProfileRules").defaults(), { mode = "Preview" })
assert(first.attributes.Coins == 0)
assert(first.attributes.Inventory_gear == 0)
assert(first.attributes.MagnetTier == 1 and PlayerState.getAttractionRadius(first) == 12)
first.Parent = nil
assert(not PlayerState.has(first))
assert(PlayerState.has(second))
print("PASS removal invalidates session and rejoin initializes independent fresh state")
local persistent = player()
local profile = require("../../src/shared/ProfileRules").defaults()
profile.coins = 25
profile.inventory.gear = 2
PlayerState.add(persistent, profile, { mode = "Persistent", leaseDeadline = 150 })
profile.inventory.gear = 1000
assert(persistent.attributes.Inventory_gear == 2)
assert(persistent.attributes.DataReady == true and persistent.attributes.DataStatus == "Ready")
local frozenSnapshot, initialRevision = PlayerState.snapshot(persistent)
assert(initialRevision == 0 and frozenSnapshot.coins == 25)
PlayerState.collect(persistent, "coin")
assert(persistent.attributes.DataStatus == "Dirty" and select(2, PlayerState.snapshot(persistent)) == 1)
PlayerState.freeze(persistent)
assert(not PlayerState.has(persistent) and persistent.attributes.DataReady == false)
assert(PlayerState.snapshot(persistent).coins == 26)
assert(not PlayerState.renewLease(persistent, 200))
print("PASS loaded profiles are copied, revision starts clean and frozen profile remains available for final snapshot")
local expiring = player()
PlayerState.add(expiring, require("../../src/shared/ProfileRules").defaults(), { mode = "Persistent", leaseDeadline = 150 })
assert(PlayerState.renewLease(expiring, 160))
clock = 160
expiring:SetAttribute("DataReady", true)
assert(not PlayerState.has(expiring))
assert(not PlayerState.renewLease(expiring, 200))
assert(not pcall(PlayerState.collect, expiring, "coin"))
print("PASS lease deadline boundary disables mutation and expired ownership cannot renew or reactivate")
for _, invalid in { math.huge, 0/0, -1, 159 } do
  local rejected = player()
  assert(not pcall(PlayerState.add, rejected, require("../../src/shared/ProfileRules").defaults(), { mode = "Persistent", leaseDeadline = invalid }))
  assert(not PlayerState.has(rejected))
end
local finite = player()
PlayerState.add(finite, require("../../src/shared/ProfileRules").defaults(), { mode = "Persistent", leaseDeadline = 200 })
assert(not PlayerState.renewLease(finite, math.huge))
assert(not PlayerState.renewLease(finite, 0/0))
assert(not PlayerState.renewLease(finite, 160))
print("PASS persistent installs and renewals reject nonfinite or expired local lease deadlines")
print("10 mocked player state checks passed; Roblox adapters/Studio NOT RUN")
`);
  const result = spawnSync(process.argv[2], [script], { cwd: root, encoding: 'utf8', timeout: 30000 });
  process.stdout.write(result.stdout ?? '');
  process.stderr.write(result.stderr ?? '');
  assert(!result.error, result.error?.message);
  assert.equal(result.status, 0, 'Mocked player state regression failed');
} finally {
  fs.rmSync(directory, { recursive: true, force: true });
}
