--!strict

-- A deterministic dynamic domain simulation, NOT Roblox networking/Studio proof.
local T = require("./TestHarness")
local Rules = require("../src/shared/CollectionRules")
local Definitions = require("../src/shared/CollectibleDefinitions")
local Inventory = require("../src/shared/InventoryRules")
local Sales = require("../src/shared/SaleRules")

local prices: Sales.Prices = {}
for id, definition in Definitions do
	if definition.kind == "Metal" then
		prices[id] = definition.reward
	end
end

T.test("two contenders collect then sell across 100 lifecycles without double payout", function()
	local sessions: { Sales.Session } = {
		{ coins = 0, inventory = Inventory.create(prices) },
		{ coins = 0, inventory = Inventory.create(prices) },
	}
	local entry: Rules.State = { objectId = "gear", lifecycleId = "initial", available = true }
	for generation = 1, 100 do
		local oldToken = entry.lifecycleId
		entry.lifecycleId = "spawn-" .. tostring(generation)
		entry.available = true
		local before = sessions[1].coins + sessions[2].coins
		for attempt = 1, 30 do
			local player = (attempt + generation) % 2 + 1
			local result = Rules.claim(Definitions, entry,
				if attempt <= 10 then oldToken else entry.lifecycleId,
				{ validCharacter = true, distance = 3 }, 12, 1)
			if result.accepted then
				T.equal(Inventory.add(sessions[player].inventory, entry.objectId), true)
			end
		end
		T.equal(sessions[1].coins + sessions[2].coins, before)
		T.equal(sessions[1].inventory.gear + sessions[2].inventory.gear, 1)
		local payout = 0
		for _, state in sessions do
			local sold = Sales.sellAll(state, prices)
			assert(sold ~= nil)
			payout += sold
			T.equal(Sales.sellAll(state, prices), 0)
			T.equal(state.inventory.gear, 0)
		end
		T.equal(payout, 5)
		T.equal(sessions[1].coins + sessions[2].coins - before, 5)
	end
	T.equal(sessions[1].coins + sessions[2].coins, 500)
	T.equal(sessions[1].inventory.gear + sessions[2].inventory.gear, 0)
end)

T.test("hostile object ids cannot override rewards", function()
	for _, id in { "../../gear", "GEAR", "gear\0", "🧲", string.rep("gear", 1000) } do
		local entry: Rules.State = { objectId = id, lifecycleId = "valid", available = true }
		T.equal(Rules.claim(Definitions, entry, "valid", {
			validCharacter = true, distance = 0,
		}, 12, 1).reward, 0)
		T.equal(entry.available, true)
	end
end)

T.test("invalid facts never reserve target from next legitimate player", function()
	local entry: Rules.State = { objectId = "can", lifecycleId = "valid", available = true }
	for _ = 1, 100 do
		T.equal(Rules.claim(Definitions, entry, "valid", {
			validCharacter = false, distance = 0,
		}, 12, 1).reward, 0)
		T.equal(Rules.claim(Definitions, entry, "valid", {
			validCharacter = true, distance = 999,
		}, 12, 1).reward, 0)
	end
	T.equal(Rules.claim(Definitions, entry, "valid", {
		validCharacter = true, distance = 2,
	}, 12, 1).reward, 3)
end)

T.test("two coin contenders across 100 lifecycles credit wallet once and never inventory", function()
	local sessions: { Sales.Session } = {
		{ coins = 0, inventory = Inventory.create(prices) },
		{ coins = 0, inventory = Inventory.create(prices) },
	}
	local entry: Rules.State = { objectId = "coin", lifecycleId = "initial", available = true }
	for generation = 1, 100 do
		local oldToken = entry.lifecycleId
		entry.lifecycleId = "coin-" .. tostring(generation)
		entry.available = true
		local before = sessions[1].coins + sessions[2].coins
		for attempt = 1, 30 do
			local player = (attempt + generation) % 2 + 1
			local result = Rules.claim(Definitions, entry,
				if attempt <= 10 then oldToken else entry.lifecycleId,
				{ validCharacter = true, distance = if attempt <= 20 then 99 else 3 }, 12, 1)
			if result.accepted then
				T.equal(Sales.creditCoins(sessions[player], result.reward), true)
			end
		end
		T.equal(sessions[1].coins + sessions[2].coins - before, 1)
		for _, state in sessions do
			T.equal(state.inventory.coin, nil)
			for id in prices do T.equal(state.inventory[id], 0) end
			T.equal(Sales.sellAll(state, prices), 0)
		end
		T.equal(sessions[1].coins + sessions[2].coins - before, 1)
	end
	T.equal(sessions[1].coins + sessions[2].coins, 100)
end)

T.test("invalid coin requests preserve spawn for a legitimate coin pickup", function()
	local state: Sales.Session = { coins = 0, inventory = Inventory.create(prices) }
	local entry: Rules.State = { objectId = "coin", lifecycleId = "valid", available = true }
	for _, request in {
		{ token = "old", distance = 1, validCharacter = true },
		{ token = "valid", distance = 99, validCharacter = true },
		{ token = "valid", distance = 1, validCharacter = false },
	} do
		local result = Rules.claim(Definitions, entry, request.token, {
			distance = request.distance, validCharacter = request.validCharacter,
		}, 12, 1)
		if result.accepted then Sales.creditCoins(state, result.reward) end
		T.equal(entry.available, true)
		T.equal(state.coins, 0)
	end
	local result = Rules.claim(Definitions, entry, "valid", {
		distance = 1, validCharacter = true,
	}, 12, 1)
	T.equal(result.accepted, true)
	T.equal(Sales.creditCoins(state, result.reward), true)
	T.equal(state.coins, 1)
	T.equal(state.inventory.coin, nil)
end)

T.finish()
