import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const compileOnly = process.argv[3] === '--compile-only';
assert(process.argv.length === 3 || (process.argv.length === 4 && compileOnly), 'Usage: node scripts/test-feedback.mjs <luau executable> [--compile-only]');
function source(relative) {
  return fs.readFileSync(path.join(root, relative), 'utf8').replace(
    /require\(ReplicatedStorage\.Shared\.(\w+)\)/g,
    (_, name) => `require("../../src/shared/${name}")`,
  ).replace('require(script.Parent.PlayerStateService)', 'PlayerState');
}
const tools = path.join(root, '.tools');
fs.mkdirSync(tools, { recursive: true });
const directory = fs.mkdtempSync(path.join(tools, 'feedback-regression-'));
try {
  const script = path.join(directory, 'run.luau');
  fs.writeFileSync(script, `--!strict
-- Execute actual modules with deterministic engine mocks. NOT Studio/network proof.
local builtinTypeof = typeof
local function typeof(value)
  if type(value) == "table" and value._kind then return value._kind end
  return builtinTypeof(value)
end
local now = 0
local os = { clock = function() return now end }
local timers = {}
local task = { delay = function(seconds, callback)
  table.insert(timers, { at = now + seconds, callback = callback })
end }
local function advance(seconds)
  now += seconds
  while true do
    local index, earliest = nil, math.huge
    for i, timer in timers do
      if timer.at <= now and timer.at < earliest then index, earliest = i, timer.at end
    end
    if not index then break end
    local timer = table.remove(timers, index)
    timer.callback()
  end
end
local function signal()
  local result = { listeners = {} }
  function result:Connect(callback)
    local connection = { Connected = true, callback = callback }
    function connection:Disconnect() self.Connected = false end
    table.insert(self.listeners, connection)
    return connection
  end
  function result:Fire(...)
    for _, connection in table.clone(self.listeners) do
      if connection.Connected then connection.callback(...) end
    end
  end
  function result:count()
    local count = 0
    for _, connection in self.listeners do if connection.Connected then count += 1 end end
    return count
  end
  return result
end
local vectorMeta = {}
local function vector(x, y, z)
  return setmetatable({ X = x, Y = y, Z = z, _kind = "Vector3" }, vectorMeta)
end
function vectorMeta.__sub(a, b) return vector(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
function vectorMeta.__index(v, key)
  if key == "Magnitude" then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
end
local Vector3 = { new = vector }
-- Translation-only CFrame mock: asserts lifecycle/ownership, not engine transforms.
local frameMeta = {}
local CFrame = {}
function CFrame.new(x, y, z)
  return setmetatable({ Position = vector(x or 0, y or 0, z or 0), _kind = "CFrame" }, frameMeta)
end
function frameMeta.__mul(a, b)
  return CFrame.new(a.Position.X+b.Position.X, a.Position.Y+b.Position.Y, a.Position.Z+b.Position.Z)
end
function frameMeta.__index(frame, key)
  if key == "Lerp" then return function(a, b, t)
    return CFrame.new(a.Position.X+(b.Position.X-a.Position.X)*t,
      a.Position.Y+(b.Position.Y-a.Position.Y)*t, a.Position.Z+(b.Position.Z-a.Position.Z)*t)
  end end
end
local Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local UDim = { new = function(scale, offset) return { Scale = scale, Offset = offset } end }
local UDim2 = { new = function(...) return {...} end, fromOffset = function(...) return {...} end, fromScale = function(...) return {...} end }
local Color3 = { fromRGB = function(...) return {...} end }
local Enum = setmetatable({}, { __index = function(_, _) return setmetatable({}, { __index = function(_, key) return key end }) end })
local Instance = {}
function Instance.new(className)
  local properties = { ClassName = className, _kind = "Instance", Visible = true,
    AbsoluteContentSize = Vector2.new(0, 0), AbsoluteWindowSize = Vector2.new(420, 280), CanvasPosition = Vector2.new(0, 0) }
  local object = { _properties = properties, attributes = {}, attributeSignals = {}, propertySignals = {},
    Activated = signal(), Destroying = signal(), ChildRemoved = signal(), CharacterRemoving = signal(), CharacterAdded = signal(), ChildAdded = signal(),
    OnServerEvent = signal(), OnClientEvent = signal(), sent = {}, children = {} }
  function object:IsA(class)
    return class == className or (class == "BasePart" and className == "Part")
  end
  function object:GetChildren() return table.clone(self.children) end
  function object:FindFirstChild(name)
    for _, child in self.children do if child.Name == name then return child end end
    return nil
  end
  function object:WaitForChild(name) return assert(self:FindFirstChild(name), name) end
  function object:FindFirstChildOfClass(class)
    for _, child in self.children do if child:IsA(class) then return child end end
  end
  function object:GetAttribute(name) return self.attributes[name] end
  function object:GetAttributeChangedSignal(name)
    if not self.attributeSignals[name] then self.attributeSignals[name] = signal() end
    return self.attributeSignals[name]
  end
  function object:GetPropertyChangedSignal(name)
    if not self.propertySignals[name] then self.propertySignals[name] = signal() end
    return self.propertySignals[name]
  end
  function object:SetAttribute(name, value)
    self.attributes[name] = value
    self:GetAttributeChangedSignal(name):Fire()
  end
  function object:FireServer(...) table.insert(self.sent, table.pack(...)) end
  function object:FireClient(player, ...)
    table.insert(self.sent, { player = player, args = table.pack(...) })
  end
  function object:Destroy()
    self.Destroying:Fire()
    self.Parent = nil
    for _, child in self:GetChildren() do child:Destroy() end
  end
  return setmetatable(object, {
    __index = properties,
    __newindex = function(self, key, value)
      if key == "Parent" then
        local old = properties.Parent
        if old then
          for i, child in old.children do if child == self then table.remove(old.children, i) break end end
          old.ChildRemoved:Fire(self)
        end
        if value then table.insert(value.children, self) value.ChildAdded:Fire(self) end
      elseif key == "Position" then
        properties.CFrame = CFrame.new(value.X, value.Y, value.Z)
      elseif key == "CFrame" then
        properties.Position = value.Position
      end
      properties[key] = value
      if self.propertySignals[key] then self.propertySignals[key]:Fire() end
    end,
  })
end
local Players = Instance.new("Players")
Players.PlayerRemoving = signal()
local ReplicatedStorage = Instance.new("ReplicatedStorage")
local workspace = Instance.new("Workspace")
local RunService = { RenderStepped = signal(), PreAnimation = signal(), PreSimulation = signal() }
local TweenService = { GetValue = function(_, progress) return progress end }
local HttpService = { id = 0 }
function HttpService:GenerateGUID(_) self.id += 1 return "lifecycle-" .. self.id end
local game = {}
function game:GetService(name)
  return assert(({ Players = Players, ReplicatedStorage = ReplicatedStorage, HttpService = HttpService, RunService = RunService, TweenService = TweenService })[name])
end
local Definitions = require("../../src/shared/CollectibleDefinitions")
local Config = require("../../src/shared/MagnetConfig")
local PlayerState = (function()
${source('src/server/Services/PlayerStateService.luau')}
end)()
local World = (function()
${source('src/server/Services/PrototypeWorldService.luau')}
end)()
local Collectibles = (function()
${source('src/server/Services/CollectibleService.luau')}
end)()
local Hud = (function()
${source('src/client/Controllers/HudController.luau')}
end)()
local Attraction = (function()
${source('src/client/Controllers/AttractionController.luau')}
end)()
local Magnet = (function()
${source('src/client/Controllers/MagnetController.luau')}
end)()
local function named(class, name, parent)
  local object = Instance.new(class) object.Name = name object.Parent = parent return object
end
local function check(description) print("PASS " .. description) end
named("Part", "PrototypeFloor", workspace)
named("SpawnLocation", "PrototypeSpawn", workspace)
local folder = World.create()
assert(World.create() == folder)
local parts = {}
for _, part in folder:GetChildren() do
  local id = part:GetAttribute("ObjectId")
  parts[id] = part
  local hint = part:FindFirstChild("PickupHint")
  assert(hint and hint:IsA("BillboardGui"))
  local label = assert(hint:FindFirstChildOfClass("TextLabel"))
  assert(string.find(label.Text, Definitions[id].name, 1, true))
  assert(string.find(label.Text, tostring(Definitions[id].reward), 1, true))
  local original = label.Text
  part:SetAttribute("Available", false)
  assert(label.Text == Definitions[id].name .. (if Definitions[id].kind == "Metal" then "\\n" .. Definitions[id].rarity else "") .. "\\nRespawning...")
  part:SetAttribute("Available", true)
  assert(label.Text == original)
end
check("world labels show catalog name/value and restore after respawn")
Collectibles.start(folder)
local remotes = ReplicatedStorage:WaitForChild(Config.remotesFolder)
local sell = remotes:WaitForChild(Config.sellRemote)
local receipt = remotes:WaitForChild(Config.sellResultRemote)
local buy = remotes:WaitForChild(Config.buyRemote)
local shopReceipt = remotes:WaitForChild(Config.buyResultRemote)
local upgradeRemote = remotes:WaitForChild(Config.upgradeRemote)
local upgradeReceipt = remotes:WaitForChild(Config.upgradeResultRemote)
local request = remotes:WaitForChild(Config.requestRemote)
local collection = remotes:WaitForChild(Config.resultRemote)
local bookReceipt = remotes:WaitForChild(Config.bookResultRemote)
local player = named("Player", "TestPlayer", Players)
local playerGui = named("PlayerGui", "PlayerGui", player)
local character = named("Model", "Character", workspace)
player.Character = character
local humanoid = named("Humanoid", "Humanoid", character) humanoid.Health = 100
local rootPart = named("Part", "HumanoidRootPart", character) rootPart.Position = parts.gear.Position
Players.LocalPlayer = player
PlayerState.add(player, require("../../src/shared/ProfileRules").defaults(), { mode = "Preview" })
-- Malformed requests, including explicit nil, spend limiter capacity but emit nothing.
sell.OnServerEvent:Fire(player, 999)
sell.OnServerEvent:Fire(player, nil)
sell.OnServerEvent:Fire(player)
assert(#receipt.sent == 0 and player:GetAttribute("Coins") == 0)
advance(1)
sell.OnServerEvent:Fire(player)
assert(#receipt.sent == 1 and receipt.sent[1].args.n == 1 and receipt.sent[1].args[1] == 0)
check("sale handler rejects argument injection/rate overflow silently and receipts empty sale")
request.OnServerEvent:Fire(player, parts.gear, parts.gear:GetAttribute("LifecycleId"))
request.OnServerEvent:Fire(player, parts.gear, parts.gear:GetAttribute("LifecycleId"))
assert(player:GetAttribute("Inventory_gear") == 1 and #collection.sent == 1)
assert(#bookReceipt.sent == 1 and bookReceipt.sent[1].args.n == 1)
local bookPayload = bookReceipt.sent[1].args[1]
local bookFields = 0 for _ in bookPayload do bookFields += 1 end
assert(bookFields == 3 and bookPayload.objectId == "gear" and bookPayload.count == 1 and bookPayload.reward == 0)
local payload = collection.sent[1].args[1]
local count = 0 for _ in payload do count += 1 end
assert(count == 3 and payload.lifecycleId and payload.objectId == "gear" and payload.startCFrame)
sell.OnServerEvent:Fire(player)
assert(#receipt.sent == 2 and receipt.sent[2].args.n == 1 and receipt.sent[2].args[1] == 5)
assert(player:GetAttribute("Inventory_gear") == 0 and player:GetAttribute("Coins") == 5)
assert(parts.gear:GetAttribute("Available") == false)
check("collection claims once, preserves exact cosmetic payload, sale receipt follows authoritative payout")
advance(Config.respawnDelay)
assert(parts.gear:GetAttribute("Available") == true)
local stranger = named("Player", "Unknown", Players)
sell.OnServerEvent:Fire(stranger)
assert(#receipt.sent == 2)
Players.PlayerRemoving:Fire(player)
sell.OnServerEvent:Fire(player)
assert(#receipt.sent == 3)
check("respawn restores availability; unknown player silent; leaving clears sale limiter")
-- Separate buy limiter and strict arity validation; malformed input consumes budget.
buy.OnServerEvent:Fire(player, 2, nil)
buy.OnServerEvent:Fire(player)
buy.OnServerEvent:Fire(player, 2)
assert(#shopReceipt.sent == 0)
assert(PlayerState.getAttractionRadius(player) == 12)
advance(1)
buy.OnServerEvent:Fire(player, "2")
buy.OnServerEvent:Fire(player, nil)
assert(#shopReceipt.sent == 0)
for _, invalidTier in { 0, -1, 1.5, 4, math.huge, 0 / 0, 9007199254740992, {} } do
  advance(0.5)
  buy.OnServerEvent:Fire(player, invalidTier)
end
assert(#shopReceipt.sent == 0)
advance(1)
buy.OnServerEvent:Fire(stranger, 2)
buy.OnServerEvent:Fire(player, 3)
assert(#shopReceipt.sent == 1 and shopReceipt.sent[1].args[1].status == "insufficientCoins")
buy.OnServerEvent:Fire(player, 2)
assert(#shopReceipt.sent == 2 and shopReceipt.sent[2].args[1].status == "insufficientCoins")
check("buy remote rejects malformed tiers/extra nil/unknown sessions and rate overflow without grants")
-- Upgrade remote validates exact arity, uses its own bucket, no implicit next-level replay.
upgradeRemote.OnServerEvent:Fire(player, "range", 1, nil)
upgradeRemote.OnServerEvent:Fire(player, "range")
upgradeRemote.OnServerEvent:Fire(player, "range", 1)
assert(#upgradeReceipt.sent == 0)
advance(1)
for _, args in { table.pack("unknown", 1), table.pack("range", "1"), table.pack("range", 0/0), table.pack("range", 6), table.pack(nil, 1) } do
  advance(0.5)
  upgradeRemote.OnServerEvent:Fire(player, table.unpack(args, 1, args.n))
end
assert(#upgradeReceipt.sent == 0)
advance(1)
upgradeRemote.OnServerEvent:Fire(stranger, "range", 1)
upgradeRemote.OnServerEvent:Fire(player, "range", 1)
assert(#upgradeReceipt.sent == 1 and upgradeReceipt.sent[1].args[1].status == "insufficientCoins")
local payload = upgradeReceipt.sent[1].args[1]
local fields = 0 for _ in payload do fields += 1 end
assert(fields == 3 and payload.upgradeId == "range" and payload.level == 1)
check("upgrade remote rejects malformed/extra nil and unknown sessions with independent limiter and exact cosmetic receipt")
-- Put coin exactly 18 studs away: starter cannot claim, forged display attrs do not help.
rootPart.Position = parts.coin.Position - Vector3.new(18, 0, 0)
player:SetAttribute("MagnetTier", 3)
player:SetAttribute("MagnetRadius", 10000)
request.OnServerEvent:Fire(player, parts.coin, parts.coin:GetAttribute("LifecycleId"))
assert(parts.coin:GetAttribute("Available") == true and player:GetAttribute("Coins") == 5)
for _ = 1, 20 do PlayerState.collect(player, "coin") end
advance(1)
buy.OnServerEvent:Fire(player, 2)
assert(player:GetAttribute("Coins") == 0 and player:GetAttribute("MagnetTier") == 2)
local bought = shopReceipt.sent[#shopReceipt.sent]
assert(bought.player == player and bought.args.n == 1)
local boughtPayload = bought.args[1]
local keys = 0 for _ in boughtPayload do keys += 1 end
assert(keys == 2 and boughtPayload.status == "purchased" and boughtPayload.tier == 2)
assert(PlayerState.getAttractionRadius(player) == 12)
request.OnServerEvent:Fire(player, parts.coin, parts.coin:GetAttribute("LifecycleId"))
assert(parts.coin:GetAttribute("Available") == true and player:GetAttribute("Coins") == 0)
buy.OnServerEvent:Fire(player, 2)
assert(player:GetAttribute("Coins") == 0 and shopReceipt.sent[#shopReceipt.sent].args[1].status == "owned")
for _ = 1, 25 do PlayerState.collect(player, "coin") end
assert(PlayerState.upgrade(player, "range", 1) == "purchased")
request.OnServerEvent:Fire(player, parts.coin, parts.coin:GetAttribute("LifecycleId"))
assert(parts.coin:GetAttribute("Available") == false and player:GetAttribute("Coins") == 1)
assert(player:GetAttribute("Inventory_gear") == 0)
check("cosmetic purchase never grants range; independent private range upgrade enables distant coin collection")
PlayerState.remove(player)
PlayerState.add(player, require("../../src/shared/ProfileRules").defaults(), { mode = "Preview" })
Players.PlayerRemoving:Fire(player)
advance(1)
Hud.start()
local gui = playerGui:WaitForChild("MagnetMayhemHUD")
local header = gui:WaitForChild("Coins")
local panel = gui:WaitForChild("Inventory")
local button = panel:WaitForChild("SellAll")
local toggle = gui:WaitForChild("Navigation"):WaitForChild("InventoryToggle")
toggle.Activated:Fire() assert(panel.Visible)
local shopPanel = gui:WaitForChild("Shop")
local shopToggle = gui:WaitForChild("Navigation"):WaitForChild("ShopToggle")
local ironBuy = shopPanel:WaitForChild("BuyMagnet2")
local goldBuy = shopPanel:WaitForChild("BuyMagnet3")
assert(not shopPanel.Visible)
shopToggle.Activated:Fire() assert(shopPanel.Visible and not panel.Visible)
toggle.Activated:Fire() assert(panel.Visible and not shopPanel.Visible)
shopToggle.Activated:Fire() assert(shopPanel.Visible and not panel.Visible)
shopToggle.Activated:Fire() assert(not shopPanel.Visible and not panel.Visible)
local bookPanel = gui:WaitForChild("CollectionBook")
local bookToggle = gui:WaitForChild("Navigation"):WaitForChild("BookToggle")
bookToggle.Activated:Fire() assert(bookPanel.Visible and not panel.Visible and not shopPanel.Visible)
shopToggle.Activated:Fire() assert(shopPanel.Visible and not panel.Visible and not bookPanel.Visible)
bookToggle.Activated:Fire() assert(bookPanel.Visible and not panel.Visible and not shopPanel.Visible)
toggle.Activated:Fire() assert(panel.Visible and not shopPanel.Visible and not bookPanel.Visible)
bookToggle.Activated:Fire() assert(bookPanel.Visible and not panel.Visible and not shopPanel.Visible)
bookToggle.Activated:Fire() assert(not bookPanel.Visible and not panel.Visible and not shopPanel.Visible)
assert(bookPanel:WaitForChild("bolt").Text == "??? | Common")
check("three panels are mutually exclusive, book unknown rows masked, toggles grant no state")
local default = header.Text
local coins = player:GetAttribute("Coins")
local invalid = { -1, 1.5, math.huge, 0/0, "5", {}, 9007199254740992 }
for _, value in invalid do receipt.OnClientEvent:Fire(value) end
receipt.OnClientEvent:Fire(nil)
receipt.OnClientEvent:Fire(5, 99)
assert(header.Text == default and player:GetAttribute("Coins") == coins)
check("HUD ignores malformed/extra-argument sale results without touching economy")
for _, payload in {
  {objectId="coin",count=1,reward=0}, {objectId="unknown",count=1,reward=0},
  {objectId="bolt",count=0,reward=0}, {objectId="bolt",count=16,reward=0},
  {objectId="bolt",count=1.5,reward=0}, {objectId="bolt",count=0/0,reward=0},
  {objectId="bolt",count=3,reward=0}, {objectId="bolt",count=1,reward=10},
  {objectId="bolt",count=1,reward=0,coins=99}, {}, "invalid",
} do bookReceipt.OnClientEvent:Fire(payload) end
bookReceipt.OnClientEvent:Fire({objectId="bolt",count=1,reward=0}, nil)
assert(header.Text == default and player:GetAttribute("Coins") == coins)
bookReceipt.OnClientEvent:Fire({objectId="gear",count=3,reward=10})
assert(string.find(header.Text, "Discovered Gear (3/15) +10 coins", 1, true))
assert(player:GetAttribute("Coins") == coins and player:GetAttribute("Discovered_gear") == false)
assert(bookPanel:WaitForChild("gear").Text == "??? | Rare")
advance(Config.feedbackDuration)
assert(header.Text == default)
check("book receipt rejects malformed grants and valid cosmetic feedback never changes discovery or wallet")
collection.OnClientEvent:Fire({ lifecycleId = "one", objectId = "coin", startCFrame = parts.coin.CFrame })
assert(header.Text ~= default and string.find(header.Text, "Coin", 1, true))
local coinText = header.Text
advance(1)
receipt.OnClientEvent:Fire(5)
local saleText = header.Text
assert(saleText ~= coinText and string.find(saleText, "5", 1, true))
advance(Config.feedbackDuration - 1)
assert(header.Text == saleText, "Older feedback timer erased newer message")
advance(1)
assert(header.Text == default)
receipt.OnClientEvent:Fire(0)
assert(header.Text ~= default)
advance(Config.feedbackDuration)
assert(header.Text == default and player:GetAttribute("Coins") == coins)
check("latest feedback wins, stale timers cannot clear it, empty receipt displays, expiry restores hint")
collection.OnClientEvent:Fire({ lifecycleId = "one", objectId = "unknown", startCFrame = parts.coin.CFrame })
collection.OnClientEvent:Fire({ lifecycleId = "one", objectId = "coin" })
collection.OnClientEvent:Fire({ lifecycleId = "", objectId = "coin", startCFrame = parts.coin.CFrame })
collection.OnClientEvent:Fire("invalid")
collection.OnClientEvent:Fire({ lifecycleId = "one", objectId = "coin", startCFrame = parts.coin.CFrame }, 99)
collection.OnClientEvent:Fire({ lifecycleId = string.rep("x", Config.maxLifecycleLength + 1), objectId = "coin", startCFrame = parts.coin.CFrame })
assert(header.Text == default)
collection.OnClientEvent:Fire({ lifecycleId = "one", objectId = "coin", startCFrame = parts.coin.CFrame, reward = 99 })
assert(player:GetAttribute("Coins") == coins, "Cosmetic extra fields granted reward")
collection.OnClientEvent:Fire({ lifecycleId = "metal", objectId = "gear", startCFrame = parts.gear.CFrame })
assert(string.find(header.Text, "Gear", 1, true))
assert(player:GetAttribute("Inventory_gear") == 0)
check("collection feedback validates cosmetic payload and never grants metal or coins")
PlayerState.collect(player, "bolt")
assert(button.Active)
button.Activated:Fire()
assert(#sell.sent == 1 and sell.sent[1].n == 0)
assert(button.Text == "Selling..." and not button.Active and not button.Selectable and not button.AutoButtonColor)
button.Activated:Fire()
receipt.OnClientEvent:Fire(1)
assert(not button.Active and #sell.sent == 1)
advance(0.5)
assert(button.Active and #sell.sent == 1)
button.Activated:Fire()
assert(#sell.sent == 2)
receipt.OnClientEvent:Fire(1) -- late earlier acknowledgement must not release new cooldown
assert(not button.Active)
PlayerState.sellAll(player)
advance(0.5)
assert(not button.Active and button.Text == "Sell all (empty)" and #sell.sent == 2)
check("sale sends no args, cooldown disables/rejects repeats, late receipts cannot release cooldown, no retries")
local beforeShop = header.Text
local originalTier = player:GetAttribute("MagnetTier")
local originalCoins = player:GetAttribute("Coins")
for _, payload in {
  {status="purchased",tier=0}, {status="purchased",tier=4}, {status="purchased",tier=1.5},
  {status="purchased",tier=0/0}, {status="purchased",tier=math.huge}, {status="purchased",tier="2"},
  {status="unknown",tier=2}, {tier=2}, {status="purchased"}, "invalid", {},
} do shopReceipt.OnClientEvent:Fire(payload) end
shopReceipt.OnClientEvent:Fire(nil)
shopReceipt.OnClientEvent:Fire({status="purchased",tier=2}, nil)
assert(header.Text == beforeShop)
for _, status in { "purchased", "insufficientCoins", "owned", "equipped", "invalidTier" } do
  shopReceipt.OnClientEvent:Fire({status=status,tier=2,coins=99999,radius=10000})
  assert(header.Text ~= beforeShop)
  assert(player:GetAttribute("Coins") == originalCoins and player:GetAttribute("MagnetTier") == originalTier)
end
advance(Config.feedbackDuration)
check("shop receipts validate status/tier/arity, show feedback only and never grant balances or equipment")
for _ = 1, 25 - originalCoins do PlayerState.collect(player, "coin") end
assert(ironBuy.Active and not goldBuy.Active)
ironBuy.Activated:Fire()
assert(#buy.sent == 1 and buy.sent[1].n == 1 and buy.sent[1][1] == 2)
assert(ironBuy.Text == "Buying..." and not ironBuy.Active and not ironBuy.Selectable)
ironBuy.Activated:Fire()
shopReceipt.OnClientEvent:Fire({status="purchased",tier=2})
assert(not ironBuy.Active and #buy.sent == 1)
advance(0.5)
assert(ironBuy.Active and #buy.sent == 1)
ironBuy.Activated:Fire()
shopReceipt.OnClientEvent:Fire({status="purchased",tier=2})
assert(not ironBuy.Active and #buy.sent == 2)
assert(PlayerState.buyMagnet(player, 2) == "purchased")
advance(0.5)
assert(ironBuy.Text == "Equipped" and not ironBuy.Active)
assert(goldBuy.Text == "Need 100 more coins" and not goldBuy.Active)
check("buy sends only tier, prevents repeats, late acknowledgements do not unlock cooldown, attribute change equips")
for _ = 1, 100 do PlayerState.collect(player, "coin") end
goldBuy.Activated:Fire()
advance(0.5)
assert(goldBuy.Active and #buy.sent == 3)
goldBuy.Activated:Fire()
assert(#buy.sent == 4 and not goldBuy.Active)
check("missing shop acknowledgement expires local cooldown with no automatic retry")
local dock = gui:WaitForChild("UpgradeDock")
local rangeUpgrade = dock:WaitForChild("Upgrade_range")
local powerUpgrade = dock:WaitForChild("Upgrade_power")
assert(rangeUpgrade.Active and powerUpgrade.Active)
local originalUpgradeCoins = player:GetAttribute("Coins")
local originalUpgradeLevel = player:GetAttribute("Upgrade_range")
local originalUpgradeHeader = header.Text
for _, payload in { {status="purchased",upgradeId="range",level=1,coins=999}, {status="purchased",upgradeId="unknown",level=1}, {status="purchased",upgradeId="range",level=0/0}, {status="unknown",upgradeId="range",level=1}, {status="purchased",upgradeId="range"} } do
  upgradeReceipt.OnClientEvent:Fire(payload)
end
upgradeReceipt.OnClientEvent:Fire({status="purchased",upgradeId="range",level=1}, nil)
assert(header.Text == originalUpgradeHeader)
rangeUpgrade.Activated:Fire()
assert(#upgradeRemote.sent == 1 and upgradeRemote.sent[1].n == 2)
assert(upgradeRemote.sent[1][1] == "range" and upgradeRemote.sent[1][2] == 1)
assert(not rangeUpgrade.Active and not powerUpgrade.Active)
rangeUpgrade.Activated:Fire()
upgradeReceipt.OnClientEvent:Fire({status="purchased",upgradeId="range",level=1})
assert(player:GetAttribute("Coins") == originalUpgradeCoins and player:GetAttribute("Upgrade_range") == originalUpgradeLevel)
assert(not rangeUpgrade.Active and #upgradeRemote.sent == 1)
advance(0.5)
assert(rangeUpgrade.Active and powerUpgrade.Active and #upgradeRemote.sent == 1)
rangeUpgrade.Activated:Fire()
upgradeReceipt.OnClientEvent:Fire({status="purchased",upgradeId="range",level=1})
assert(not rangeUpgrade.Active and #upgradeRemote.sent == 2)
assert(PlayerState.upgrade(player, "range", 1) == "purchased")
advance(0.5)
rangeUpgrade.Activated:Fire() -- 100 next price is unaffordable after the 25 debit.
assert(#upgradeRemote.sent == 2)
check("one-click dock sends id and explicit next level; receipts cannot grant stats or unlock cooldown; no auto retry")
PlayerState.collect(player, "can")
button.Activated:Fire()
advance(0.5) -- No receipt: courtesy cooldown still expires, with no automatic resend.
assert(button.Active and #sell.sent == 3)
button.Activated:Fire()
receipt.OnClientEvent:Fire(3)
local beforeDestroy = header.Text
local signals = { collection.OnClientEvent, receipt.OnClientEvent, shopReceipt.OnClientEvent, bookReceipt.OnClientEvent, upgradeReceipt.OnClientEvent }
for _, s in player.attributeSignals do table.insert(signals, s) end
local function collectResizeSignals(node)
  for _, s in node.propertySignals do table.insert(signals, s) end
  for _, child in node:GetChildren() do collectResizeSignals(child) end
end
collectResizeSignals(gui)
gui:Destroy()
for _, s in signals do assert(s:count() == 0, "HUD external listener leaked") end
receipt.OnClientEvent:Fire(999)
bookReceipt.OnClientEvent:Fire({objectId="gear",count=3,reward=10})
shopReceipt.OnClientEvent:Fire({status="purchased",tier=3})
collection.OnClientEvent:Fire({ lifecycleId = "gone", objectId = "coin", startCFrame = parts.coin.CFrame })
advance(Config.feedbackDuration + 1)
assert(header.Text == beforeDestroy and #sell.sent == 4 and #buy.sent == 4)
check("destroy disconnects external listeners and pending feedback/cooldown timers are inert")
-- Bounded actual-controller mocks: CFrames translate only; no render/physics proof.
for _, part in parts do part:SetAttribute("Available", false) end
rootPart.Position = Vector3.new(0, 0, 0)
for i, id in { "bolt", "can", "gear" } do
  local distance = ({12, 18, 24})[i]
  parts[id].Position = Vector3.new(distance, 0, 0)
  parts[id]:SetAttribute("Available", true)
end
player:SetAttribute("MagnetTier", 3)
player:SetAttribute("Upgrade_range", 0)
player:SetAttribute("MagnetRadius", 10000)
Attraction.start()
local function tick() advance(0.2) RunService.RenderStepped:Fire() end
local sentBefore = #request.sent
tick()
assert(#request.sent == sentBefore + 1 and request.sent[#request.sent][1] == parts.bolt)
player:SetAttribute("Upgrade_range", 1)
tick()
assert(#request.sent == sentBefore + 2 and request.sent[#request.sent][1] == parts.can)
player:SetAttribute("Upgrade_range", 2)
tick()
assert(#request.sent == sentBefore + 3 and request.sent[#request.sent][1] == parts.gear)
player.CharacterRemoving:Fire()
player:SetAttribute("MagnetTier", "invalid")
player:SetAttribute("Upgrade_range", "invalid")
tick()
assert(#request.sent == sentBefore + 4 and request.sent[#request.sent][1] == parts.bolt)
local originalFrame = parts.bolt.CFrame
local beforeGhostCoins = player:GetAttribute("Coins")
collection.OnClientEvent:Fire({lifecycleId="ghost-test",objectId="bolt",startCFrame=originalFrame})
local ghost = workspace:WaitForChild("AttractionGhost")
assert(ghost ~= parts.bolt and ghost.Anchored and not ghost.CanCollide and not ghost.CanTouch and not ghost.CanQuery)
tick()
assert(parts.bolt.CFrame == originalFrame and player:GetAttribute("Coins") == beforeGhostCoins)
player.CharacterRemoving:Fire()
assert(ghost.Parent == nil)
check("actual attraction scanner follows independent 12/18/24 range upgrades, ignores forged radius, falls back safely, animates disposable ghost only")
Magnet.start()
humanoid.RigType = Enum.HumanoidRigType.R15
local animator = named("Animator", "Animator", humanoid)
local leftUpper = named("Part", "LeftUpperArm", character)
local rightUpper = named("Part", "RightUpperArm", character)
local leftLower = named("Part", "LeftLowerArm", character)
local rightLower = named("Part", "RightLowerArm", character)
local leftHand = named("Part", "LeftHand", character)
-- Partial R15 must not bind only one hand or fall back to R6.
RunService.PreAnimation:Fire()
assert(humanoid:FindFirstChild("LocalMagnetLeftHold") == nil)
local rightHand = named("Part", "RightHand", character)
local function expectMagnet(tier)
  RunService.PreAnimation:Fire()
  RunService.RenderStepped:Fire()
  local model = workspace:WaitForChild("LocalMagnet")
  assert(#model:GetChildren() == ({5, 7, 8})[tier])
  local bridge = model:WaitForChild("Bridge")
  assert(bridge:WaitForChild("LeftGrip"):IsA("Attachment"))
  assert(bridge:WaitForChild("RightGrip"):IsA("Attachment"))
  for _, piece in model:GetChildren() do
    assert(piece.Anchored and not piece.CanCollide and not piece.CanTouch and not piece.CanQuery)
  end
  if player.Character == character then
    local left = humanoid:WaitForChild("LocalMagnetLeftHold")
    local right = humanoid:WaitForChild("LocalMagnetRightHold")
    assert(left.ChainRoot == leftUpper and left.EndEffector == leftHand)
    assert(right.ChainRoot == rightUpper and right.EndEffector == rightHand)
    assert(left.Target == bridge:WaitForChild("LeftGrip") and right.Target == bridge:WaitForChild("RightGrip"))
    assert(left.Enabled and right.Enabled and left.Weight == 1 and right.Weight == 1)
  end
  return model
end
local heldModel = expectMagnet(1)
local originalHumanoid = humanoid
local oldLeft = humanoid:WaitForChild("LocalMagnetLeftHold")
local oldRight = humanoid:WaitForChild("LocalMagnetRightHold")
originalHumanoid.Parent = nil
humanoid = named("Humanoid", "ReplacementHumanoid", character)
humanoid.Health = 100
humanoid.RigType = Enum.HumanoidRigType.R15
named("Animator", "Animator", humanoid)
expectMagnet(1)
assert(oldLeft.Parent == nil and oldRight.Parent == nil)
assert(humanoid:WaitForChild("LocalMagnetLeftHold").Parent == humanoid)
assert(humanoid:WaitForChild("LocalMagnetRightHold").Parent == humanoid)
local replacedHandControl = humanoid:WaitForChild("LocalMagnetLeftHold")
leftHand.Parent = nil
leftHand = named("Part", "LeftHand", character)
expectMagnet(1)
assert(replacedHandControl.Parent == nil)
assert(humanoid:WaitForChild("LocalMagnetLeftHold").EndEffector == leftHand)
check("same-model humanoid and hand replacement destroy stale IK and rebind both hands")
local previousAnimator = humanoid:FindFirstChildOfClass("Animator")
local animatorControl = humanoid:WaitForChild("LocalMagnetLeftHold")
previousAnimator.Parent = nil
RunService.PreAnimation:Fire()
assert(animatorControl.Parent == nil and humanoid:FindFirstChild("LocalMagnetRightHold") == nil)
named("Animator", "CurrentAnimator", humanoid)
expectMagnet(1)
local lowerArmControl = humanoid:WaitForChild("LocalMagnetLeftHold")
leftLower.Parent = nil
RunService.PreAnimation:Fire()
assert(lowerArmControl.Parent == nil and humanoid:FindFirstChild("LocalMagnetRightHold") == nil)
leftLower = named("Part", "LeftLowerArm", character)
expectMagnet(1)
assert(workspace:WaitForChild("LocalMagnet") == heldModel)
check("missing replaced Animator or lower arm removes both IK controls until complete without replacing carried prop")
local previous = expectMagnet(1) -- malformed replicated tier falls back to Starter
for _, tier in {2, 3} do
  player:SetAttribute("MagnetTier", tier)
  local nextModel = expectMagnet(tier)
  assert(nextModel ~= previous and previous.Parent == nil)
  previous = nextModel
end
humanoid.Health = 0
RunService.RenderStepped:Fire()
assert(previous.Parent == nil and workspace:FindFirstChild("LocalMagnet") == nil)
humanoid.Health = 100
previous = expectMagnet(3)
local newCharacter = named("Model", "ReplacementCharacter", workspace)
local newRoot = named("Part", "HumanoidRootPart", newCharacter) newRoot.Position = Vector3.new(0,0,0)
local newHumanoid = named("Humanoid", "Humanoid", newCharacter) newHumanoid.Health = 100
player.Character = newCharacter
local replacement = expectMagnet(3)
assert(replacement ~= previous and previous.Parent == nil)
assert(parts.bolt.CFrame == originalFrame and player:GetAttribute("Coins") == beforeGhostCoins)
check("actual local magnet binds two R15 hands only when complete; skin/character/death clear and rebuild cosmetic model and never moves authoritative collectible")
local requestsBeforeLoading = #request.sent
player:SetAttribute("DataReady", false)
tick()
assert(#request.sent == requestsBeforeLoading)
assert(workspace:FindFirstChild("LocalMagnet") == nil and replacement.Parent == nil)
player:SetAttribute("DataReady", true)
expectMagnet(3)
tick()
assert(#request.sent > requestsBeforeLoading)
check("loading readiness disables actual attraction requests and clears local magnet until activated")
PlayerState.freeze(player)
player:SetAttribute("DataReady", true)
local collectionsBeforeFrozen = #collection.sent
local salesBeforeFrozen = #receipt.sent
local buysBeforeFrozen = #shopReceipt.sent
advance(1)
request.OnServerEvent:Fire(player, parts.bolt, parts.bolt:GetAttribute("LifecycleId"))
sell.OnServerEvent:Fire(player)
buy.OnServerEvent:Fire(player, 3)
assert(#collection.sent == collectionsBeforeFrozen and #receipt.sent == salesBeforeFrozen and #shopReceipt.sent == buysBeforeFrozen)
check("server pickup/sale/shop remotes reject frozen private profile despite forged readiness attribute")
-- Capacity denial must happen before lifecycle consumption, not after claim.
advance(Config.respawnDelay)
local function collectingActor(name, profile, part)
  local actor = named("Player", name, Players)
  local model = Instance.new("Model")
  actor.Character = model
  local health = named("Humanoid", "Humanoid", model) health.Health = 100
  local root = named("Part", "HumanoidRootPart", model) root.Position = part.Position
  PlayerState.add(actor, profile, { mode = "Preview" })
  return actor
end
for _, scenario in { "maxWalletCoin", "thirdDiscoveryOverflow", "maxInventory" } do
  local profile = require("../../src/shared/ProfileRules").defaults()
  local id = if scenario == "maxWalletCoin" then "coin" elseif scenario == "thirdDiscoveryOverflow" then "gear" else "washer"
  if scenario == "maxInventory" then profile.inventory[id] = 9007199254740991
  else profile.coins = 9007199254740991 end
  if scenario == "thirdDiscoveryOverflow" then profile.discovered = { bolt = true, can = true } end
  local part = parts[id]
  part:SetAttribute("Available", true)
  local token = part:GetAttribute("LifecycleId")
  local rejected = collectingActor(scenario, profile, part)
  local priorCollection, priorBook = #collection.sent, #bookReceipt.sent
  local priorSale, priorShop = #receipt.sent, #shopReceipt.sent
  request.OnServerEvent:Fire(rejected, part, token)
  local snapshot, revision = PlayerState.snapshot(rejected)
  assert(revision == 0 and snapshot.coins == profile.coins)
  assert(snapshot.inventory[id] == profile.inventory[id] and snapshot.discovered[id] == nil)
  assert(part:GetAttribute("Available") == true and part:GetAttribute("LifecycleId") == token)
  assert(#collection.sent == priorCollection and #bookReceipt.sent == priorBook)
  assert(#receipt.sent == priorSale and #shopReceipt.sent == priorShop)
  local accepted = collectingActor(scenario .. "Follower", require("../../src/shared/ProfileRules").defaults(), part)
  request.OnServerEvent:Fire(accepted, part, token)
  request.OnServerEvent:Fire(accepted, part, token)
  assert(part:GetAttribute("Available") == false and #collection.sent == priorCollection + 1)
  if id == "coin" then
    assert(accepted:GetAttribute("Coins") == 1 and #bookReceipt.sent == priorBook)
  else
    assert(accepted:GetAttribute("Inventory_" .. id) == 1 and #bookReceipt.sent == priorBook + 1)
  end
  PlayerState.remove(rejected) PlayerState.remove(accepted)
end
check("capacity-denied pickups preserve profile, token and availability without receipts; next valid player claims same lifecycle exactly once")
for _, level in { 0, 5 } do
  advance(Config.respawnDelay + 1)
  local powerPlayer = named("Player", "PowerTest" .. tostring(level), Players)
  local powerBody = named("Model", "PowerBody", workspace)
  powerPlayer.Character = powerBody
  local powerRoot = named("Part", "HumanoidRootPart", powerBody)
  powerRoot.Position = parts.coin.Position
  local powerHumanoid = named("Humanoid", "Humanoid", powerBody)
  powerHumanoid.Health = 100
  local powerProfile = require("../../src/shared/ProfileRules").defaults()
  powerProfile.upgrades.power = level
  PlayerState.add(powerPlayer, powerProfile, { mode = "Preview" })
  powerPlayer:SetAttribute("MagnetPower", 100000)
  local burst = Config.requestBurst * (if level == 5 then 3 else 1)
  for _ = 1, burst - 1 do request.OnServerEvent:Fire(powerPlayer, nil, nil) end
  assert(parts.coin:GetAttribute("Available") == true)
  request.OnServerEvent:Fire(powerPlayer, parts.coin, parts.coin:GetAttribute("LifecycleId"))
  assert(powerPlayer:GetAttribute("Coins") == 1)
  powerRoot.Position = parts.bolt.Position
  local before = #collection.sent
  request.OnServerEvent:Fire(powerPlayer, parts.bolt, parts.bolt:GetAttribute("LifecycleId"))
  assert(#collection.sent == before and powerPlayer:GetAttribute("Inventory_bolt") == 0)
  PlayerState.remove(powerPlayer)
end
check("private power scales collection burst only; forged power cannot expand budget or per-unit coin payout")
print("26 mocked feedback integration checks authored; Roblox adapters/Studio NOT RUN")
`);
  const result = spawnSync(process.argv[2], compileOnly ? ['--null', script] : [script], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (compileOnly) process.stdout.write('STATIC ONLY: generated Luau compiled; behavior assertions NOT RUN\n');
  process.stdout.write(result.stdout ?? '');
  process.stderr.write(result.stderr ?? '');
  assert(!result.error, result.error?.message);
  assert.equal(result.status, 0, 'Mocked feedback integration regression failed');
} finally {
  fs.rmSync(directory, { recursive: true, force: true });
}
