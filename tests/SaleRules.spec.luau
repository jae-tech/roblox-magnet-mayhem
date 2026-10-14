--!strict

local T = require("./TestHarness")
local Sales = require("../src/shared/SaleRules")
local Inventory = require("../src/shared/InventoryRules")
local Definitions = require("../src/shared/CollectibleDefinitions")

local MAX_SAFE = 9007199254740991
local prices: Sales.Prices = {}
for objectId, definition in Definitions do
	if definition.kind == "Metal" then
		prices[objectId] = definition.reward
	end
end

local function session(coins: number?): Sales.Session
	return { coins = coins or 0, inventory = Inventory.create(prices) }
end

local function assertRejected(state: Sales.Session, salePrices: Sales.Prices)
	local beforeCoins = state.coins
	local beforeCounts = table.clone(state.inventory)
	T.equal(Sales.sellAll(state, salePrices), nil)
	T.equal(state.coins == beforeCoins or (state.coins ~= state.coins and beforeCoins ~= beforeCoins), true)
	for id, count in beforeCounts do
		local actual = state.inventory[id]
		T.equal(actual == count or (actual ~= actual and count ~= count), true)
	end
	for id in state.inventory do
		T.equal(beforeCounts[id] ~= nil, true)
	end
end

T.test("mixed inventory sale credits exact catalog value and retains zero keys", function()
	local state = session(7)
	state.inventory.bolt = 2
	state.inventory.can = 3
	state.inventory.gear = 4
	local counts = state.inventory
	T.equal(Sales.sellAll(state, prices), 31)
	T.equal(state.coins, 38)
	T.equal(state.inventory, counts)
	for id in prices do
		T.equal(state.inventory[id], 0)
	end
end)

T.test("empty inventory sale is idempotent and does not change coins", function()
	local state = session(9)
	for _ = 1, 3 do
		T.equal(Sales.sellAll(state, prices), 0)
		T.equal(state.coins, 9)
	end
end)

T.test("replayed sell-all cannot pay twice and subsequent pickup can be sold", function()
	local state = session()
	T.equal(Inventory.add(state.inventory, "gear"), true)
	T.equal(state.coins, 0)
	T.equal(Sales.sellAll(state, prices), 5)
	T.equal(Sales.sellAll(state, prices), 0)
	T.equal(state.coins, 5)
	T.equal(Inventory.add(state.inventory, "can"), true)
	T.equal(state.coins, 5)
	T.equal(Sales.sellAll(state, prices), 3)
	T.equal(state.coins, 8)
end)

T.test("selling one player does not change another player or a new session", function()
	local first, second = session(), session(11)
	first.inventory.can = 2
	second.inventory.gear = 3
	T.equal(Sales.sellAll(first, prices), 6)
	T.equal(second.coins, 11)
	T.equal(second.inventory.gear, 3)
	T.equal(session().coins, 0)
	T.equal(session().inventory.can, 0)
end)

for _, case in {
	{ name = "negative", value = -1 },
	{ name = "fractional", value = 1.5 },
	{ name = "NaN", value = 0 / 0 },
	{ name = "infinite", value = math.huge },
	{ name = "negative infinity", value = -math.huge },
	{ name = "unsafe integer", value = MAX_SAFE + 1 },
	{ name = "string", value = "2" :: any },
	{ name = "boolean", value = true :: any },
} do
	T.test("invalid " .. case.name .. " quantity rejects entire sale without mutation", function()
		local state = session(12)
		state.inventory.bolt = 2
		state.inventory.gear = case.value
		assertRejected(state, prices)
	end)
	T.test("invalid " .. case.name .. " balance rejects sale without mutation", function()
		local state = session()
		state.coins = case.value
		state.inventory.can = 2
		assertRejected(state, prices)
	end)
	T.test("invalid " .. case.name .. " price rejects sale without mutation", function()
		local state = session(12)
		state.inventory.bolt = 2
		local invalidPrices = table.clone(prices)
		invalidPrices.gear = case.value
		assertRejected(state, invalidPrices)
	end)
end

T.test("zero price is invalid even for a zero-count inventory entry", function()
	local state = session(12)
	state.inventory.can = 2
	local invalidPrices = table.clone(prices)
	invalidPrices.gear = 0
	assertRejected(state, invalidPrices)
end)

T.test("unknown inventory id rejects sale even with zero quantity", function()
	for _, quantity in { 0, 1 } do
		local state = session(12)
		state.inventory.bolt = 2
		state.inventory["unknown"] = quantity
		assertRejected(state, prices)
	end
end)

T.test("missing catalog price rejects entire sale without mutation", function()
	local state = session(12)
	state.inventory.can = 2
	local missingPrices = table.clone(prices)
	missingPrices.can = nil
	assertRejected(state, missingPrices)
end)

T.test("quantity times price overflow rejects sale without partial clearing", function()
	local state = session(12)
	state.inventory.bolt = 2
	state.inventory.gear = MAX_SAFE
	assertRejected(state, prices)
end)

T.test("total payout overflow rejects individually safe line items", function()
	local state = session()
	state.inventory.bolt = MAX_SAFE
	state.inventory.can = 1
	assertRejected(state, prices)
end)

T.test("balance overflow rejects safe payout without consuming inventory", function()
	local state = session(MAX_SAFE)
	state.inventory.bolt = 1
	assertRejected(state, prices)
end)

T.test("maximum safe final balance succeeds exactly", function()
	local state = session(MAX_SAFE - 1)
	state.inventory.bolt = 1
	T.equal(Sales.sellAll(state, prices), 1)
	T.equal(state.coins, MAX_SAFE)
	T.equal(state.inventory.bolt, 0)
end)

T.test("maximum safe count and unit price can produce a safe payout", function()
	local state = session()
	state.inventory.bolt = MAX_SAFE
	T.equal(Sales.sellAll(state, prices), MAX_SAFE)
	T.equal(state.coins, MAX_SAFE)
	T.equal(state.inventory.bolt, 0)
end)

T.test("empty sparse inventory returns zero with valid prices", function()
	local state: Sales.Session = { coins = 7, inventory = {} }
	T.equal(Sales.sellAll(state, prices), 0)
	T.equal(state.coins, 7)
	T.equal(next(state.inventory), nil)
end)

T.test("invalid configured price is rejected even when inventory has no matching entry", function()
	local state: Sales.Session = { coins = 7, inventory = { bolt = 1 } }
	local invalidPrices = table.clone(prices)
	invalidPrices.gear = 0
	assertRejected(state, invalidPrices)
end)

T.test("empty and non-string inventory ids reject without mutation", function()
	for _, id in { "", 42 :: any } do
		local state = session(7)
		state.inventory[id] = 1
		assertRejected(state, prices)
	end
end)

T.test("empty and non-string price ids reject without mutation", function()
	for _, id in { "", 42 :: any } do
		local state = session(7)
		state.inventory.can = 1
		local invalidPrices = table.clone(prices)
		invalidPrices[id] = 1
		assertRejected(state, invalidPrices)
	end
end)

T.test("maximum safe unit price is accepted for a single item", function()
	local state: Sales.Session = { coins = 0, inventory = { bolt = 1 } }
	T.equal(Sales.sellAll(state, { bolt = MAX_SAFE }), MAX_SAFE)
	T.equal(state.coins, MAX_SAFE)
	T.equal(state.inventory.bolt, 0)
end)

T.test("map coin credits wallet directly without inventory", function()
	local state = session(4)
	T.equal(Sales.creditCoins(state, Definitions.coin.reward), true)
	T.equal(state.coins, 5)
	T.equal(state.inventory.coin, nil)
	for id in prices do
		T.equal(state.inventory[id], 0)
	end
end)

T.test("coin pickup then metal sale preserves direct coin balance without selling coin", function()
	local state = session()
	T.equal(Sales.creditCoins(state, Definitions.coin.reward), true)
	for id in prices do
		T.equal(Inventory.add(state.inventory, id), true)
	end
	T.equal(state.coins, 1)
	T.equal(state.inventory.coin, nil)
	T.equal(Sales.sellAll(state, prices), 9)
	T.equal(state.coins, 10)
	T.equal(Sales.sellAll(state, prices), 0)
	T.equal(state.coins, 10)
	T.equal(Inventory.add(state.inventory, "coin"), false)
end)

for _, case in {
	{ name = "zero", value = 0 },
	{ name = "negative", value = -1 },
	{ name = "fractional", value = 1.5 },
	{ name = "NaN", value = 0 / 0 },
	{ name = "infinite", value = math.huge },
	{ name = "negative infinity", value = -math.huge },
	{ name = "unsafe integer", value = MAX_SAFE + 1 },
	{ name = "string", value = "1" :: any },
	{ name = "boolean", value = true :: any },
	{ name = "missing", value = nil :: any },
} do
	T.test("invalid " .. case.name .. " coin credit rejects without changing wallet or inventory", function()
		local state = session(7)
		state.inventory.can = 2
		T.equal(Sales.creditCoins(state, case.value), false)
		T.equal(state.coins, 7)
		T.equal(state.inventory.can, 2)
		T.equal(state.inventory.coin, nil)
	end)
	if case.name ~= "zero" then
		T.test("invalid " .. case.name .. " wallet rejects coin credit", function()
			local state = session()
			state.coins = case.value
			state.inventory.bolt = 1
			T.equal(Sales.creditCoins(state, 1), false)
			T.equal(state.coins == case.value or (state.coins ~= state.coins and case.value ~= case.value), true)
			T.equal(state.inventory.bolt, 1)
		end)
	end
end

T.test("coin credit rejects overflow and accepts exact maximum safe balance", function()
	local state = session(MAX_SAFE)
	state.inventory.gear = 1
	T.equal(Sales.creditCoins(state, 1), false)
	T.equal(state.coins, MAX_SAFE)
	T.equal(state.inventory.gear, 1)
	state.coins = MAX_SAFE - 1
	T.equal(Sales.creditCoins(state, 1), true)
	T.equal(state.coins, MAX_SAFE)
	T.equal(state.inventory.gear, 1)
end)

T.test("maximum safe coin credit succeeds from a zero wallet", function()
	local state = session()
	T.equal(Sales.creditCoins(state, MAX_SAFE), true)
	T.equal(state.coins, MAX_SAFE)
	T.equal(state.inventory.coin, nil)
end)

return true
