--!strict

local T = require("./TestHarness")
local Shop = require("../src/shared/ShopRules")
local Definitions = require("../src/shared/MagnetDefinitions")
local MAX_SAFE = 9007199254740991

local function state(coins: number?, tier: number?): any
	return { coins = coins or 0, magnetTier = tier or 1, inventory = { gear = 3 } }
end
local function unchanged(session: any, definitions: any, requested: unknown, expected: any)
	local coins, tier, inventory = session.coins, session.magnetTier, session.inventory
	T.equal(Shop.purchase(session, definitions, requested), expected)
	T.equal(session.coins == coins or (session.coins ~= session.coins and coins ~= coins), true)
	T.equal(session.magnetTier == tier or (session.magnetTier ~= session.magnetTier and tier ~= tier), true)
	T.equal(session.inventory, inventory)
	T.equal(session.inventory.gear, 3)
end
T.test("magnet catalog lookup returns configured tier or nil", function()
	for _, definition in Definitions do
		T.equal(Shop.definitionFor(Definitions, definition.tier), definition)
	end
	for _, tier in { 0, -1, 1.5, 4, math.huge, 0 / 0 } do
		T.equal(Shop.definitionFor(Definitions, tier), nil)
	end
end)
T.test("exact affordable upgrade debits catalog price and preserves inventory", function()
	local session = state(25)
	local inventory = session.inventory
	T.equal(Shop.purchase(session, Definitions, 2), "purchased")
	T.equal(session.coins, 0)
	T.equal(session.magnetTier, 2)
	T.equal(session.inventory, inventory)
	T.equal(session.inventory.gear, 3)
end)
T.test("sequential upgrades debit each price and retain surplus coins", function()
	local session = state(132)
	T.equal(Shop.purchase(session, Definitions, 2), "purchased")
	T.equal(session.coins, 107)
	T.equal(Shop.purchase(session, Definitions, 3), "purchased")
	T.equal(session.coins, 7)
	T.equal(session.magnetTier, 3)
end)
T.test("insufficient balance cannot partially charge or equip", function()
	unchanged(state(24), Definitions, 2, "insufficientCoins")
	unchanged(state(99, 2), Definitions, 3, "insufficientCoins")
end)
T.test("owned tier replay and lower tier cannot double charge or downgrade", function()
	unchanged(state(200, 2), Definitions, 2, "owned")
	unchanged(state(200, 3), Definitions, 1, "owned")
end)
T.test("future tier is locked despite sufficient funds", function()
	unchanged(state(200), Definitions, 3, "locked")
end)
for _, case in {
	{ name = "zero", value = 0 }, { name = "negative", value = -1 },
	{ name = "fraction", value = 1.5 }, { name = "missing tier", value = 4 },
	{ name = "NaN", value = 0 / 0 }, { name = "infinity", value = math.huge },
	{ name = "unsafe", value = MAX_SAFE + 1 }, { name = "string", value = "2" :: any },
	{ name = "boolean", value = true :: any }, { name = "table", value = {} :: any },
	{ name = "nil", value = nil :: any },
} do
	T.test("requested " .. case.name .. " tier rejects without mutation", function()
		unchanged(state(200), Definitions, case.value, "invalidTier")
	end)
end
for _, case in {
	{ name = "negative", value = -1 }, { name = "fraction", value = 1.5 },
	{ name = "NaN", value = 0 / 0 }, { name = "infinity", value = math.huge },
	{ name = "unsafe", value = MAX_SAFE + 1 }, { name = "string", value = "25" :: any },
	{ name = "boolean", value = true :: any }, { name = "nil", value = nil :: any },
} do
	T.test("invalid " .. case.name .. " wallet rejects purchase without mutation", function()
		local session = state(200)
		session.coins = case.value
		unchanged(session, Definitions, 2, nil)
	end)
	T.test("invalid " .. case.name .. " owned tier rejects purchase without mutation", function()
		local session = state(200)
		session.magnetTier = case.value
		unchanged(session, Definitions, 2, nil)
	end)
end
T.test("absent equipped catalog tier rejects server state", function()
	unchanged(state(200, 4), Definitions, 2, nil)
end)
T.test("safe integer maximum balance can purchase exactly", function()
	local session = state(MAX_SAFE)
	T.equal(Shop.purchase(session, Definitions, 2), "purchased")
	T.equal(session.coins, MAX_SAFE - 25)
end)
for _, case in {
	{ name = "negative", value = -1 }, { name = "fraction", value = 1.5 },
	{ name = "NaN", value = 0 / 0 }, { name = "infinity", value = math.huge },
	{ name = "unsafe", value = MAX_SAFE + 1 }, { name = "string", value = "25" :: any },
	{ name = "nil", value = nil :: any },
} do
	T.test("invalid " .. case.name .. " catalog price rejects whole transaction", function()
		local definitions = table.clone(Definitions)
		definitions[2] = table.clone(Definitions[2])
		definitions[2].price = case.value
		unchanged(state(200), definitions, 2, nil)
	end)
end
T.test("empty catalog cannot purchase", function()
	unchanged(state(200), {}, 2, nil)
end)
T.test("paid tier cannot have a zero price", function()
	local definitions = table.clone(Definitions)
	definitions[2] = table.clone(Definitions[2])
	definitions[2].price = 0
	unchanged(state(200), definitions, 2, nil)
end)
T.test("starter price must remain free", function()
	local definitions = table.clone(Definitions)
	definitions[1] = table.clone(Definitions[1])
	definitions[1].price = 1
	unchanged(state(200), definitions, 2, nil)
end)
T.test("duplicate tier catalog cannot purchase or resolve ambiguous tier", function()
	local definitions = table.clone(Definitions)
	definitions[3] = table.clone(Definitions[2])
	T.equal(Shop.definitionFor(definitions, 2), nil)
	unchanged(state(200), definitions, 2, nil)
end)
for _, radius in { 0, -1, math.huge, 0 / 0, "18" :: any } do
	T.test("invalid catalog radius " .. tostring(radius) .. " prevents charging coins", function()
		local definitions = table.clone(Definitions)
		definitions[2] = table.clone(Definitions[2])
		definitions[2].radius = radius
		unchanged(state(200), definitions, 2, nil)
	end)
end
T.test("invalid unrelated future catalog entry prevents partial transaction", function()
	local definitions = table.clone(Definitions)
	definitions[3] = table.clone(Definitions[3])
	definitions[3].price = -1
	unchanged(state(200), definitions, 2, nil)
end)
return true
