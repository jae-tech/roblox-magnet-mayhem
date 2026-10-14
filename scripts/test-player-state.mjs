import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const compileOnly = process.argv[3] === '--compile-only';
assert(process.argv.length === 3 || (process.argv.length === 4 && compileOnly), 'Usage: node scripts/test-player-state.mjs <luau executable> [--compile-only]');
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
local function signal(): any
	local result: any = { listeners = {} }
	function result:Connect(callback: any): any
		local connection = { callback = callback, Connected = true }
		function connection:Disconnect() self.Connected = false end
		table.insert(self.listeners, connection)
		return connection
	end
	function result:Fire(...: any)
		for _, connection in self.listeners do if connection.Connected then connection.callback(...) end end
	end
	return result
end
local function character(): any
	local model: any = { ChildAdded = signal(), humanoid = nil }
	function model:FindFirstChildOfClass(class: string): any return if class == "Humanoid" then self.humanoid else nil end
	return model
end
local function humanoid(): any
	local h: any = { WalkSpeed = 16 }
	function h:IsA(class: string): boolean return class == "Humanoid" end
	return h
end
local function player(): any
	local result: any = { Parent = Players, attributes = {}, CharacterAdded = signal() }
	function result:SetAttribute(name: string, value: any)
		self.attributes[name] = value
	end
	return result
end
local function economyProfile()
	local profile = require("../../src/shared/ProfileRules").defaults()
	-- Existing sale/shop assertions isolate economy from new first-discovery rewards.
	profile.discovered = { bolt = true, can = true, gear = true }
	return profile
end
local first, second = player(), player()
PlayerState.add(first, economyProfile(), { mode = "Preview" })
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
assert(PlayerState.buyMagnet(first, 3) == "insufficientCoins")
assert(PlayerState.buyMagnet(first, 2) == "purchased")
assert(first.attributes.Coins == 0 and first.attributes.MagnetTier == 2 and first.attributes.MagnetRadius == 10000)
assert(PlayerState.getAttractionRadius(first) == 12)
assert(PlayerState.buyMagnet(first, 2) == "owned")
assert(PlayerState.buyMagnet(first, 1) == "equipped")
assert(PlayerState.buyMagnet(first, 2) == "equipped")
assert(first.attributes.Coins == 0 and first.attributes.OwnedMagnet_iron == true)
for _ = 1, 65 do PlayerState.collect(first, "coin") end
first:SetAttribute("Upgrade_range", 5)
first:SetAttribute("MagnetPower", 10000)
first:SetAttribute("MoveSpeed", 10000)
assert(PlayerState.getAttractionRadius(first) == 12 and PlayerState.getMagneticPower(first) == 1)
assert(PlayerState.upgrade(first, "range", 2) == "locked")
assert(PlayerState.upgrade(first, "range", 1) == "purchased")
assert(PlayerState.upgrade(first, "range", 1) == "owned")
assert(PlayerState.upgrade(first, "power", 1) == "purchased")
assert(PlayerState.upgrade(first, "speed", 1) == "purchased")
assert(first.attributes.Coins == 0 and PlayerState.getAttractionRadius(first) == 18)
assert(PlayerState.getMagneticPower(first) == 1.25 and first.attributes.MoveSpeed == 18)
assert(PlayerState.buyMagnet(first, 1) == "equipped")
assert(PlayerState.getAttractionRadius(first) == 18 and PlayerState.getMagneticPower(first) == 1.25)
assert(PlayerState.getAttractionRadius(second) == 12 and PlayerState.getMagneticPower(second) == 1)
assert(not pcall(PlayerState.add, first, require("../../src/shared/ProfileRules").defaults(), { mode = "Preview" }))
assert(PlayerState.getAttractionRadius(first) == 18)
print("PASS independent stat purchases ignore forged attrs; owned skins equip free without changing stats")
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
local Book = require("../../src/shared/CollectionBookRules")
local discoveryPlayer = player()
PlayerState.add(discoveryPlayer, require("../../src/shared/ProfileRules").defaults(), { mode = "Preview" })
assert(PlayerState.collect(discoveryPlayer, "coin") == nil)
local totalReward = 0
for i, id in Book.orderedIds do
  local receipt = PlayerState.collect(discoveryPlayer, id)
  assert(receipt and receipt.objectId == id and receipt.count == i)
  local fields = 0 for _ in receipt do fields += 1 end
  assert(fields == 3)
  local reward = if i == 3 then 10 elseif i == 7 then 30 elseif i == 15 then 100 else 0
  assert(receipt.reward == reward)
  totalReward += reward
  assert(discoveryPlayer.attributes.Coins == 1 + totalReward)
  assert(discoveryPlayer.attributes[Book.attributePrefix .. id] == true)
  assert(PlayerState.collect(discoveryPlayer, id) == nil)
  assert(discoveryPlayer.attributes.Coins == 1 + totalReward)
end
assert(totalReward == 140)
local saved = PlayerState.snapshot(discoveryPlayer)
local sale = PlayerState.sellAll(discoveryPlayer)
assert(sale > 0 and Book.count(PlayerState.snapshot(discoveryPlayer).discovered) == 15)
PlayerState.remove(discoveryPlayer)
PlayerState.add(discoveryPlayer, saved, { mode = "Preview" })
assert(Book.count(PlayerState.snapshot(discoveryPlayer).discovered) == 15)
assert(PlayerState.collect(discoveryPlayer, "gear") == nil)
assert(discoveryPlayer.attributes.Coins == 141)
print("PASS discovery rewards once at thresholds, exact cosmetic receipts, sale/rejoin preserve history")
saved.discovered.bolt = nil
assert(PlayerState.snapshot(discoveryPlayer).discovered.bolt == true)
local detached = PlayerState.snapshot(discoveryPlayer)
detached.discovered.can = nil
assert(PlayerState.snapshot(discoveryPlayer).discovered.can == true)
print("PASS loaded and snapshotted discovery maps are isolated from caller mutation")
local overflow = player()
local maxProfile = require("../../src/shared/ProfileRules").defaults()
maxProfile.coins = 9007199254740991
maxProfile.discovered = { bolt = true, can = true }
PlayerState.add(overflow, maxProfile, { mode = "Preview" })
assert(not pcall(PlayerState.collect, overflow, "gear"))
local afterOverflow, overflowRevision = PlayerState.snapshot(overflow)
assert(afterOverflow.coins == maxProfile.coins and afterOverflow.inventory.gear == 0)
assert(afterOverflow.discovered.gear == nil and overflowRevision == 0)
print("PASS discovery milestone overflow rejects the whole transaction without partial inventory/book/reward mutation")
assert(not PlayerState.canCollect(overflow, "coin"))
assert(not PlayerState.canCollect(overflow, "gear"))
assert(PlayerState.canCollect(overflow, "bolt")) -- already discovered: zero milestone reward
local zeroBonus = player()
local zeroProfile = require("../../src/shared/ProfileRules").defaults()
zeroProfile.coins = 9007199254740991
PlayerState.add(zeroBonus, zeroProfile, { mode = "Preview" })
assert(PlayerState.canCollect(zeroBonus, "bolt")) -- first discovery before a milestone
assert(not PlayerState.canCollect(zeroBonus, "unknown"))
local fullCount = player()
local fullProfile = require("../../src/shared/ProfileRules").defaults()
fullProfile.inventory.gear = 9007199254740991
PlayerState.add(fullCount, fullProfile, { mode = "Preview" })
assert(not PlayerState.canCollect(fullCount, "gear"))
assert(PlayerState.canCollect(fullCount, "coin"))
assert(not PlayerState.canCollect(persistent, "coin")) -- frozen private readiness
assert(select(2, PlayerState.snapshot(overflow)) == 0)
print("PASS capacity preflight rejects wallet/count/milestone overflow but accepts zero-reward discoveries and repeats")
local moving = player()
local movingProfile = require("../../src/shared/ProfileRules").defaults()
movingProfile.coins = 100
movingProfile.upgrades.speed = 2
local body = character()
moving.Character = body
PlayerState.add(moving, movingProfile, { mode = "Preview" })
local firstHumanoid = humanoid()
body.humanoid = firstHumanoid
body.ChildAdded:Fire(firstHumanoid)
assert(firstHumanoid.WalkSpeed == 20)
moving:SetAttribute("MoveSpeed", 10000)
moving:SetAttribute("Upgrade_speed", 5)
assert(PlayerState.upgrade(moving, "speed", 3) == "insufficientCoins")
assert(firstHumanoid.WalkSpeed == 20)
local replacement = character()
local replacementHumanoid = humanoid()
replacement.humanoid = replacementHumanoid
moving.Character = replacement
moving.CharacterAdded:Fire(replacement)
assert(replacementHumanoid.WalkSpeed == 20)
firstHumanoid.WalkSpeed = 123
body.ChildAdded:Fire(firstHumanoid)
assert(firstHumanoid.WalkSpeed == 123)
PlayerState.remove(moving)
replacementHumanoid.WalkSpeed = 321
replacement.ChildAdded:Fire(replacementHumanoid)
assert(replacementHumanoid.WalkSpeed == 321)
print("PASS loaded private speed applies to late Humanoid and reset; replaced and removed listeners are inert")
print("15 mocked player state checks authored; Roblox adapters/Studio NOT RUN")
`);
  const result = spawnSync(process.argv[2], compileOnly ? ['--null', script] : [script], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (compileOnly) process.stdout.write('STATIC ONLY: generated Luau compiled; behavior assertions NOT RUN\n');
  process.stdout.write(result.stdout ?? '');
  process.stderr.write(result.stderr ?? '');
  assert(!result.error, result.error?.message);
  assert.equal(result.status, 0, 'Mocked player state regression failed');
} finally {
  fs.rmSync(directory, { recursive: true, force: true });
}
