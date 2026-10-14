import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
assert.equal(process.argv.length, 3, 'Usage: node scripts/test-persistence.mjs <luau executable>');
function source(relative) {
  return fs.readFileSync(path.join(root, relative), 'utf8').replace(
    /require\(ReplicatedStorage\.Shared\.(\w+)\)/g,
    (_, name) => `require("../../src/shared/${name}")`,
  ).replace('require(script.Parent.PlayerStateService)', 'PlayerState')
    .replace('require(script.Parent.PersistenceConfig)', 'PersistenceConfig');
}
const directory = fs.mkdtempSync(path.join(root, '.tools/persistence-regression-'));
try {
  const script = path.join(directory, 'run.luau');
  fs.writeFileSync(script, `--!strict
-- Actual persistence adapter under deterministic mocks; NO Roblox API requests.
-- Coroutine scheduling proves state transitions, not Studio service behavior.
local Rules = require("../../src/shared/ProfileRules")
local clock = 1000
local os = { clock = function() return clock end, time = function() return math.floor(clock) end }
local DateTime = { now = function() return { UnixTimestamp = math.floor(clock), UnixTimestampMillis = clock * 1000 } end }
local jobs = {}
local sequence = 0
local task = {}
local function schedule(thread, at, args)
  sequence += 1
  table.insert(jobs, { thread = thread, at = at, sequence = sequence, args = args or table.pack() })
end
function task.spawn(callback, ...)
  local thread = if type(callback) == "thread" then callback else coroutine.create(callback)
  schedule(thread, clock, table.pack(...))
  return thread
end
function task.defer(callback, ...) return task.spawn(callback, ...) end
function task.delay(seconds, callback, ...)
  local thread = coroutine.create(callback)
  schedule(thread, clock + seconds, table.pack(...))
  return thread
end
function task.wait(seconds)
  local delay = seconds or 0.03
  schedule(coroutine.running(), clock + delay)
  coroutine.yield()
  return delay
end
local function advance(seconds)
  local target = clock + seconds
  local steps = 0
  while true do
    local index, earliest, order = nil, math.huge, math.huge
    for i, job in jobs do
      if job.at <= target and (job.at < earliest or job.at == earliest and job.sequence < order) then
        index, earliest, order = i, job.at, job.sequence
      end
    end
    if not index then break end
    clock = earliest
    local job = table.remove(jobs, index)
    local ok, message = coroutine.resume(job.thread, table.unpack(job.args, 1, job.args.n))
    assert(ok, message)
    steps += 1
    assert(steps < 10000, "scheduler failed to make progress")
  end
  clock = target
end
local function signal()
  local value = { listeners = {} }
  function value:Connect(callback)
    table.insert(self.listeners, callback)
    return { Disconnect = function() end }
  end
  function value:Fire(...)
    for _, callback in self.listeners do task.spawn(callback, ...) end
  end
  return value
end
local Players = { PlayerAdded = signal(), PlayerRemoving = signal(), players = {} }
function Players:GetPlayers() return table.clone(self.players) end
local RunService = { studio = false }
function RunService:IsStudio() return self.studio end
local HttpService = { count = 0 }
function HttpService:GenerateGUID(_)
  self.count += 1
  return "GUID-" .. tostring(self.count)
end
local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {} for key, child in value do result[key] = copy(child) end return result
end
local function equal(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for key, value in a do if not equal(value, b[key]) then return false end end
  for key in b do if a[key] == nil then return false end end
  return true
end
local store = { replays = 0, records = {}, calls = {}, failures = 0, afterCommitErrors = 0, delay = 0, hooks = {} }
function store:UpdateAsync(key, transform)
  table.insert(self.calls, { key = key, time = clock })
  local hook = table.remove(self.hooks, 1)
  if hook then hook(key) end
  if self.delay > 0 then task.wait(self.delay) end
  if self.failures > 0 then self.failures -= 1 error("injected transient failure") end
  local old = copy(self.records[key])
  local keyInfo = {}
  function keyInfo:GetUserIds() return { 123456 } end
  function keyInfo:GetMetadata() return { marker = "preserve" } end
  local original = copy(old)
  local transformed, users, metadata = transform(old, keyInfo)
  local replay, replayUsers, replayMetadata = transform(old, keyInfo)
  assert(equal(old, original), "UpdateAsync callback mutated saved input")
  assert(equal(transformed, replay) and equal(users, replayUsers) and equal(metadata, replayMetadata), "callback replay not deterministic")
  self.replays += 1
  if transformed ~= nil then
    assert(users and users[1] == 123456, "UpdateAsync discarded user ids")
    assert(metadata and metadata.marker == "preserve", "UpdateAsync discarded metadata")
    self.records[key] = copy(transformed)
  end
  if self.afterCommitErrors > 0 then self.afterCommitErrors -= 1 error("unknown outcome after committed write") end
  if self.returnDelay and self.returnDelay > 0 then
    local seconds = self.returnDelay
    self.returnDelay = 0
    task.wait(seconds)
  end
  return if transformed ~= nil then copy(self.records[key]) else nil, keyInfo
end
local DataStoreService = { accesses = 0 }
function DataStoreService:GetDataStore(name)
  self.accesses += 1
  assert(name == "MagnetMayhem_PlayerData_v1" or name == "MagnetMayhem_PlayerData_Studio_v1")
  return store
end
local shutdownCallback = nil
local game = { JobId = "mock-server", PlaceId = 123 }
function game:GetService(name)
  if name == "Players" then return Players end
  if name == "ReplicatedStorage" then return {} end
  if name == "RunService" then return RunService end
  if name == "HttpService" then return HttpService end
  if name == "DataStoreService" then return DataStoreService end
  error("unexpected service " .. name)
end
function game:BindToClose(callback) shutdownCallback = callback end
local warnings = {}
local function warn(...) table.insert(warnings, table.pack(...)) end
local PersistenceConfig = (function()
${source('src/server/Services/PersistenceConfig.luau')}
end)()
local PlayerState = (function()
${source('src/server/Services/PlayerStateService.luau')}
end)()
local Persistence = (function()
${source('src/server/Services/PersistenceService.luau')}
end)()
local function player(id)
  local p = { UserId = id, Name = "Player" .. tostring(id), Parent = Players, attributes = {}, kicks = {} }
  function p:SetAttribute(key, value) self.attributes[key] = value end
  function p:GetAttribute(key) return self.attributes[key] end
  function p:Kick(message) table.insert(self.kicks, message) end
  return p
end
local function join(p)
  table.insert(Players.players, p)
  Players.PlayerAdded:Fire(p)
  advance(0)
end
local function leave(p)
  p.Parent = nil
  for i, candidate in Players.players do if candidate == p then table.remove(Players.players, i) break end end
  Players.PlayerRemoving:Fire(p)
  advance(0)
end
local checks = 0
local function check(name)
  checks += 1
  print("PASS " .. name)
end
Persistence.start()
local first = player(15)
store.delay = 2
join(first)
assert(first.attributes.DataReady == false and first.attributes.DataStatus == "Loading")
assert(not PlayerState.has(first))
assert(not pcall(PlayerState.collect, first, "coin"))
assert(not pcall(PlayerState.sellAll, first))
assert(not pcall(PlayerState.buyMagnet, first, 2))
check("loading profile blocks pickup, sale and purchase before validated installation")
advance(2)
store.delay = 0
assert(PlayerState.has(first) and first.attributes.DataReady == true)
assert(first.attributes.StorageMode == "Persistent" and first.attributes.Coins == 0)
assert(store.records["15"].lease)
check("new live player installs initialized profile only after confirmed lease acquisition")
local second = player(30)
join(second)
PlayerState.collect(first, "coin")
PlayerState.collect(first, "gear")
assert(second.attributes.Coins == 0 and second.attributes.Inventory_gear == 0)
local snapshot, revision = PlayerState.snapshot(first)
assert(snapshot.coins == 1 and revision == 2)
snapshot.inventory.gear = 99
assert(PlayerState.snapshot(first).inventory.gear == 1)
assert(PlayerState.sellAll(first) == 5)
assert(PlayerState.sellAll(first) == 0)
assert(select(2, PlayerState.snapshot(first)) == 3)
assert(PlayerState.buyMagnet(first, 2) == "insufficientCoins")
assert(select(2, PlayerState.snapshot(first)) == 3)
check("players isolate progress, immutable snapshots detach inventory, no-op mutations keep revision")
for _ = 1, 19 do PlayerState.collect(first, "coin") end
assert(PlayerState.buyMagnet(first, 2) == "purchased")
PlayerState.collect(first, "can")
leave(first)
assert(not PlayerState.has(first))
assert(store.records["15"].lease == nil)
assert(store.records["15"].data.magnetTier == 2)
assert(store.records["15"].data.inventory.can == 1)
local resumed = player(15)
join(resumed)
assert(resumed.attributes.MagnetTier == 2 and resumed.attributes.Inventory_can == 1)
assert(resumed.attributes.Coins == 0 and PlayerState.getAttractionRadius(resumed) == 18)
check("leave final-saves coins, inventory and equipped magnet and rejoin restores all progress")
local duplicate = player(15)
local callsBeforeDuplicate = #store.calls
join(duplicate)
assert(not PlayerState.has(duplicate) and duplicate.attributes.DataStatus == "Error")
assert(#store.calls == callsBeforeDuplicate and PlayerState.has(resumed))
leave(duplicate)
check("duplicate same-user join cannot overwrite or remove the active session owner")
local ambiguous = player(45)
store.afterCommitErrors = 1
join(ambiguous)
assert(not PlayerState.has(ambiguous))
local token = store.records["45"].lease.owner
advance(1)
assert(PlayerState.has(ambiguous) and store.records["45"].lease.owner == token)
check("unknown committed acquisition outcome retries same token without resetting or duplicate owner")
local malformed = player(60)
store.records["60"] = { version = 99, data = Rules.defaults() }
local beforeMalformed = copy(store.records["60"])
join(malformed)
assert(not PlayerState.has(malformed) and malformed.attributes.DataStatus == "Error")
assert(store.records["60"].version == beforeMalformed.version)
assert(#malformed.kicks == 1)
check("unsupported or corrupt saved record never defaults, installs, or overwrites stored payload")
local contended = player(75)
store.records["75"] = { version = 1, data = Rules.defaults(), lease = { owner = "foreign", expiresAt = os.time() + 180 } }
join(contended)
assert(not PlayerState.has(contended))
assert(store.records["75"].lease.owner == "foreign")
check("another live session ownership cancels acquisition and leaves foreign lease untouched")
local failing = player(90)
store.failures = 3
local failureCalls = #store.calls
join(failing)
advance(3)
assert(not PlayerState.has(failing) and failing.attributes.DataStatus == "Error")
assert(store.records["90"] == nil and #store.calls == failureCalls + 3)
assert(store.calls[failureCalls + 2].time - store.calls[failureCalls + 1].time == 1)
assert(store.calls[failureCalls + 3].time - store.calls[failureCalls + 2].time == 2)
check("load retries transient errors with bounded deterministic backoff and never saves fallback defaults")
local orphan = player(105)
store.delay = 2
join(orphan)
leave(orphan)
advance(2)
store.delay = 0
assert(not PlayerState.has(orphan) and store.records["105"] == nil)
check("leave during yielding load cancels callback and cannot install or overwrite orphan profile")
local committedOrphan = player(210)
store.returnDelay = 2
join(committedOrphan)
assert(store.records["210"].lease and not PlayerState.has(committedOrphan))
leave(committedOrphan)
advance(3)
assert(not PlayerState.has(committedOrphan))
assert(store.records["210"].lease == nil and store.records["210"].data.coins == 0)
check("orphaned committed load releases only its acquired token without installing gameplay state")
local releasingOrphan = player(225)
store.returnDelay = 2
join(releasingOrphan)
leave(releasingOrphan)
store.delay = 3
advance(2)
local whileReleasing = player(225)
local callsBeforeReleaseJoin = #store.calls
join(whileReleasing)
assert(not PlayerState.has(whileReleasing) and #store.calls == callsBeforeReleaseJoin)
assert(store.records["225"].lease ~= nil)
advance(4)
store.delay = 0
assert(store.records["225"].lease == nil)
local afterRelease = player(225)
join(afterRelease)
assert(PlayerState.has(afterRelease))
leave(afterRelease) leave(whileReleasing)
check("orphan release retains same-user local ownership while yielding and permits rejoin only after cleanup")
-- Freeze happens before waiting for final I/O and attributes cannot re-activate it.
local frozen = player(120)
join(frozen)
PlayerState.collect(frozen, "coin")
store.delay = 2
leave(frozen)
frozen.Parent = Players
frozen:SetAttribute("DataReady", true)
frozen:SetAttribute("StorageMode", "Preview")
assert(not PlayerState.has(frozen))
assert(not pcall(PlayerState.collect, frozen, "coin"))
assert(not PlayerState.renewLease(frozen, clock + 500))
advance(2)
store.delay = 0
assert(store.records["120"].data.coins == 1 and store.records["120"].lease == nil)
check("closing immediately freezes private authority, spoofed readiness cannot collect or renew")
local lostOwner = player(195)
join(lostOwner)
PlayerState.collect(lostOwner, "coin")
store.records["195"].lease = { owner = "new-foreign-owner", expiresAt = os.time() + 180 }
-- Force only this player's autosave ahead of the rest through its private launch schedule.
advance(60)
assert(not PlayerState.has(lostOwner) and lostOwner.attributes.DataStatus == "Error")
assert(store.records["195"].lease.owner == "new-foreign-owner")
assert(store.records["195"].data.coins == 0)
leave(lostOwner)
check("save ownership CAS cancellation freezes authority and never overwrites the new foreign session")
-- Clean other active players before isolating the autosave interleaving.
leave(second) leave(resumed) leave(ambiguous)
local autosave = player(135)
join(autosave)
PlayerState.collect(autosave, "coin")
store.delay = 2
advance(60)
assert(autosave.attributes.DataStatus == "Saving")
PlayerState.collect(autosave, "coin")
advance(2)
store.delay = 0
assert(store.records["135"].data.coins == 1)
assert(autosave.attributes.Coins == 2 and autosave.attributes.DataStatus == "Dirty")
check("autosave captures immutable pre-yield snapshot and never marks later mutations as saved")
store.afterCommitErrors = 1
advance(58)
assert(autosave.attributes.DataStatus == "Saving")
advance(1)
assert(store.records["135"].data.coins == 2 and autosave.attributes.DataStatus == "Saved")
check("ambiguous autosave retry is idempotent and confirms snapshot without coin duplication")
-- In-flight autosave + two close callers must serialize one fresh release snapshot.
store.delay = 2
advance(59)
assert(autosave.attributes.DataStatus == "Saving")
PlayerState.collect(autosave, "gear")
local callsBeforeClose = #store.calls
leave(autosave)
assert(not PlayerState.has(autosave))
task.spawn(shutdownCallback)
advance(5)
assert(store.records["135"].lease == nil)
assert(store.records["135"].data.inventory.gear == 1)
assert(#store.calls == callsBeforeClose + 1)
check("overlapping leave and shutdown coalesce close, await in-flight save, then save fresh final state once")
-- Start a second actual adapter instance for deterministic expiry/deadline tests.
jobs = {} Players.players = {} Players.PlayerAdded = signal() Players.PlayerRemoving = signal()
store.delay = 0
local Service2 = (function()
${source('src/server/Services/PersistenceService.luau')}
end)()
Service2.start()
local expiring = player(150)
join(expiring)
PlayerState.collect(expiring, "coin")
store.failures = 100
advance(165)
assert(not PlayerState.has(expiring) and expiring.attributes.DataStatus == "Error")
expiring:SetAttribute("DataReady", true)
assert(not PlayerState.has(expiring))
assert(not PlayerState.renewLease(expiring, clock + 500))
check("repeated save outages expire private lease, freeze play and cannot resurrect through renew/spoof")
store.failures = 0
local slow = player(165)
join(slow)
PlayerState.collect(slow, "coin")
store.delay = 100
local closeStart = clock
local shutdownDone = false
task.spawn(function() shutdownCallback() shutdownDone = true end)
advance(25.1)
assert(shutdownDone and not PlayerState.has(slow))
assert(clock - closeStart < 26)
local beforeLate = copy(store.records["165"])
advance(75)
assert(store.records["165"].data.coins == beforeLate.data.coins)
check("shutdown returns by bounded deadline and late yielding callback cannot overwrite after deadline")
-- Studio Preview never asks for DataStoreService and explicitly loses progress on rejoin.
jobs = {} Players.players = {} Players.PlayerAdded = signal() Players.PlayerRemoving = signal()
RunService.studio = true
store.delay = 0
local accesses = DataStoreService.accesses
local PreviewService = (function()
${source('src/server/Services/PersistenceService.luau')}
end)()
PreviewService.start()
local previewPlayer = player(180)
join(previewPlayer)
assert(previewPlayer.attributes.StorageMode == "Preview" and previewPlayer.attributes.DataReady == true)
PlayerState.collect(previewPlayer, "coin")
leave(previewPlayer)
local previewRejoin = player(180)
join(previewRejoin)
assert(previewRejoin.attributes.Coins == 0)
assert(DataStoreService.accesses == accesses and store.records["180"] == nil)
check("API-disabled Studio uses explicit Preview, never accesses DataStore and never falsely resumes progress")
assert(store.replays > 10)
check("actual adapter UpdateAsync callback replay stays deterministic, preserves input, user ids and metadata")

print(tostring(checks) .. " mocked persistence checks passed; actual DataStore/Studio NOT RUN")
`);
  const result = spawnSync(process.argv[2], [script], { cwd: root, encoding: 'utf8', timeout: 30000 });
  process.stdout.write(result.stdout ?? '');
  process.stderr.write(result.stderr ?? '');
  assert(!result.error, result.error?.message);
  assert.equal(result.status, 0, 'Mocked persistence regression failed');
} finally {
  fs.rmSync(directory, { recursive: true, force: true });
}
