--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(ReplicatedStorage.Shared.CollectibleDefinitions)
local Inventory = require(ReplicatedStorage.Shared.InventoryRules)
local Sales = require(ReplicatedStorage.Shared.SaleRules)
local Shop = require(ReplicatedStorage.Shared.ShopRules)
local Magnets = require(ReplicatedStorage.Shared.MagnetDefinitions)
local Upgrades = require(ReplicatedStorage.Shared.UpgradeDefinitions)
local UpgradeRules = require(ReplicatedStorage.Shared.UpgradeRules)
local Profiles = require(ReplicatedStorage.Shared.ProfileRules)
local Book = require(ReplicatedStorage.Shared.CollectionBookRules)

type Session = Profiles.Profile
type Options = { mode: string, leaseDeadline: number? }
type Runtime = { mode: string, leaseDeadline: number?, active: boolean, revision: number, characterConnection: RBXScriptConnection?, humanoidConnection: RBXScriptConnection? }
local runtimes: { [Player]: Runtime } = {}
local sessions: { [Player]: Session } = {}
local prices: Sales.Prices = {}
for objectId, definition in Definitions do
	if definition.kind == "Metal" then
		prices[objectId] = definition.reward
	end
end
table.freeze(prices)
local PlayerState = {}

local function upgradeValue(session: Session, id: string): number
	local definition = UpgradeRules.definitionFor(Upgrades, id, session.upgrades[id])
	assert(definition ~= nil, "Invalid private upgrade state")
	return definition.value
end

local function applySpeed(player: Player, character: Model)
	if not PlayerState.has(player) or player.Character ~= character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.WalkSpeed = upgradeValue(sessions[player], "speed") end
end

local function watchCharacter(player: Player, character: Model)
	local runtime = runtimes[player]
	if not runtime then return end
	if runtime.humanoidConnection then runtime.humanoidConnection:Disconnect() end
	runtime.humanoidConnection = character.ChildAdded:Connect(function(child)
		if child:IsA("Humanoid") then applySpeed(player, character) end
	end)
	applySpeed(player, character)
end

function PlayerState.add(player: Player, payload: Profiles.Profile, options: Options)
	assert(not sessions[player], "Duplicate profile installation")
	local profile = Profiles.validate(payload)
	assert(profile ~= nil, "Invalid loaded profile")
	assert(options.mode == "Preview" or options.mode == "Persistent", "Invalid storage mode")
	assert(options.mode == "Preview" or (options.leaseDeadline ~= nil and options.leaseDeadline < math.huge
		and options.leaseDeadline > os.clock()), "Invalid or expired profile lease")
	sessions[player] = profile
	runtimes[player] = { mode = options.mode, leaseDeadline = options.leaseDeadline, active = true, revision = 0 }
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("MagnetTier", profile.magnetTier)
	for _, definition in Magnets do
		player:SetAttribute("OwnedMagnet_" .. definition.id, profile.ownedMagnets[definition.id] == true)
	end
	for _, id in UpgradeRules.orderedIds do player:SetAttribute("Upgrade_" .. id, profile.upgrades[id]) end
	player:SetAttribute("MagnetRadius", upgradeValue(profile, "range"))
	player:SetAttribute("MagnetPower", upgradeValue(profile, "power"))
	player:SetAttribute("MoveSpeed", upgradeValue(profile, "speed"))
	for objectId, count in profile.inventory do
		player:SetAttribute(Inventory.attributePrefix .. objectId, count)
	end
	for _, objectId in Book.orderedIds do
		player:SetAttribute(Book.attributePrefix .. objectId, profile.discovered[objectId] == true)
	end
	player:SetAttribute("StorageMode", options.mode)
	player:SetAttribute("DataStatus", if options.mode == "Preview" then "Preview" else "Ready")
	player:SetAttribute("DataReady", true)
	runtimes[player].characterConnection = player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then watchCharacter(player, player.Character) end
end

function PlayerState.has(player: Player): boolean
	local runtime = runtimes[player]
	if not runtime or not runtime.active or player.Parent ~= Players then return false end
	if runtime.mode == "Persistent" and (runtime.leaseDeadline == nil or os.clock() >= runtime.leaseDeadline) then
		runtime.active = false
		player:SetAttribute("DataReady", false)
		player:SetAttribute("DataStatus", "Error")
		return false
	end
	return true
end

function PlayerState.snapshot(player: Player): (Profiles.Profile?, number?)
	local session, runtime = sessions[player], runtimes[player]
	if not session or not runtime then return nil, nil end
	return Profiles.clone(session), runtime.revision
end

function PlayerState.freeze(player: Player)
	local runtime = runtimes[player]
	if runtime then runtime.active = false end
	player:SetAttribute("DataReady", false)
	player:SetAttribute("DataStatus", "Closing")
end

function PlayerState.renewLease(player: Player, deadline: number): boolean
	if not PlayerState.has(player) then return false end
	local runtime = runtimes[player]
	if runtime.mode ~= "Persistent" or not (deadline < math.huge and deadline > os.clock()) then return false end
	runtime.leaseDeadline = deadline
	return true
end

function PlayerState.setDataStatus(player: Player, status: string)
	local runtime = runtimes[player]
	if runtime and runtime.mode == "Persistent" then player:SetAttribute("DataStatus", status) end
end

local function changed(player: Player)
	local runtime = runtimes[player]
	runtime.revision += 1
	if runtime.mode == "Persistent" then player:SetAttribute("DataStatus", "Dirty") end
end

-- A synchronous preflight lets callers reject capacity before claiming a lifecycle.
function PlayerState.canCollect(player: Player, objectId: string): boolean
	if not PlayerState.has(player) then return false end
	local session = sessions[player]
	local definition = Definitions[objectId]
	if not session or not definition then return false end
	if definition.kind == "Coin" then
		return session.coins <= 9007199254740991 - definition.reward
	end
	local count = session.inventory[objectId]
	if definition.kind ~= "Metal" or count == nil or count >= 9007199254740991 then return false end
	local _, reward = Book.record(session.discovered, objectId)
	return reward ~= nil and session.coins <= 9007199254740991 - reward
end

function PlayerState.collect(player: Player, objectId: string): Book.Receipt?
	assert(PlayerState.canCollect(player, objectId), "Profile is not ready or pickup capacity reached")
	local session = sessions[player]
	assert(session ~= nil, "Cannot collect for an unknown player")
	local definition = Definitions[objectId]
	assert(definition ~= nil, "Unknown collectible")
	if definition.kind == "Coin" then
		assert(Sales.creditCoins(session, definition.reward), "Invalid server coin reward")
		player:SetAttribute("Coins", session.coins)
		changed(player)
		return nil
	end
	assert(definition.kind == "Metal", "Unknown collectible kind")
	local count = session.inventory[objectId]
	assert(count ~= nil and count < 9007199254740991, "Inventory count limit reached")
	local firstDiscovery = session.discovered[objectId] ~= true
	local discoveries, reward, discoveryCount = Book.record(session.discovered, objectId)
	assert(discoveries ~= nil and reward ~= nil and discoveryCount ~= nil, "Invalid discovery state")
	assert(session.coins + reward <= 9007199254740991, "Discovery coin limit reached")
	-- Validate the complete transaction before changing inventory, book or coins.
	assert(Inventory.add(session.inventory, objectId), "Missing inventory entry")
	session.discovered = discoveries
	session.coins += reward
	player:SetAttribute(Inventory.attributePrefix .. objectId, session.inventory[objectId])
	if firstDiscovery then
		player:SetAttribute(Book.attributePrefix .. objectId, true)
		if reward > 0 then player:SetAttribute("Coins", session.coins) end
	end
	changed(player)
	-- Unit value is paid on sale; one-time discovery bonuses are separate.
	return if firstDiscovery then { objectId = objectId, count = discoveryCount, reward = reward } else nil
end

function PlayerState.sellAll(player: Player): number
	assert(PlayerState.has(player), "Profile is not ready")
	local session = sessions[player]
	assert(session ~= nil, "Cannot sell for an unknown player")
	local payout = Sales.sellAll(session, prices)
	assert(payout ~= nil, "Invalid server sale state")
	if payout == 0 then
		return 0
	end
	for objectId, count in session.inventory do
		player:SetAttribute(Inventory.attributePrefix .. objectId, count)
	end
	player:SetAttribute("Coins", session.coins)
	changed(player)
	return payout
end

function PlayerState.buyMagnet(player: Player, tier: number): Shop.Status
	assert(PlayerState.has(player), "Profile is not ready")
	local session = sessions[player]
	assert(session ~= nil, "Cannot buy for an unknown player")
	local status = Shop.purchase(session, Magnets, tier)
	assert(status ~= nil, "Invalid server shop state")
	if status == "purchased" or status == "equipped" then
		local definition = Shop.definitionFor(Magnets, session.magnetTier)
		assert(definition ~= nil, "Unknown equipped magnet")
		player:SetAttribute("Coins", session.coins)
		player:SetAttribute("MagnetTier", session.magnetTier)
		player:SetAttribute("OwnedMagnet_" .. definition.id, true)
		changed(player)
	end
	return status
end

function PlayerState.upgrade(player: Player, id: string, level: number): UpgradeRules.Status
	assert(PlayerState.has(player), "Profile is not ready")
	local session = sessions[player]
	assert(session ~= nil, "Cannot upgrade for an unknown player")
	local status = UpgradeRules.purchase(session, Upgrades, id, level)
	assert(status ~= nil, "Invalid server upgrade state")
	if status == "purchased" then
		player:SetAttribute("Coins", session.coins)
		player:SetAttribute("Upgrade_" .. id, session.upgrades[id])
		local attribute = if id == "range" then "MagnetRadius" elseif id == "power" then "MagnetPower" else "MoveSpeed"
		player:SetAttribute(attribute, upgradeValue(session, id))
		if id == "speed" and player.Character then applySpeed(player, player.Character) end
		changed(player)
	end
	return status
end

function PlayerState.getAttractionRadius(player: Player): number
	assert(PlayerState.has(player), "Profile is not ready")
	return upgradeValue(sessions[player], "range")
end

function PlayerState.getMagneticPower(player: Player): number
	assert(PlayerState.has(player), "Profile is not ready")
	return upgradeValue(sessions[player], "power")
end

function PlayerState.remove(player: Player)
	local runtime = runtimes[player]
	if runtime then
		if runtime.characterConnection then runtime.characterConnection:Disconnect() end
		if runtime.humanoidConnection then runtime.humanoidConnection:Disconnect() end
	end
	sessions[player] = nil
	runtimes[player] = nil
end

return PlayerState
