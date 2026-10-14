--!strict
local T = require("./TestHarness")
local Rules = require("../src/shared/UpgradeRules")
local Catalog = require("../src/shared/UpgradeDefinitions")
local function state(coins: number): any
	return { coins = coins, upgrades = { range = 0, power = 0, speed = 0 }, magnetTier = 3, ownedMagnets = { starter = true, gold = true } }
end
for _, id in Rules.orderedIds do
	T.test(id .. " exact next-level price debits only that stat", function()
		local price = Catalog[id].levels[2].price
		local s = state(price)
		T.equal(Rules.purchase(s, Catalog, id, 1), "purchased")
		T.equal(s.coins, 0)
		for _, other in Rules.orderedIds do T.equal(s.upgrades[other], if other == id then 1 else 0) end
		T.equal(s.magnetTier, 3)
		T.equal(s.ownedMagnets.gold, true)
	end)
	T.test(id .. " insufficient balance leaves level and balance untouched", function()
		local s = state(Catalog[id].levels[2].price - 1)
		local coins = s.coins
		T.equal(Rules.purchase(s, Catalog, id, 1), "insufficientCoins")
		T.equal(s.coins, coins)
		T.equal(s.upgrades[id], 0)
	end)
	T.test(id .. " skips lock and replays cannot buy a second level", function()
		local s = state(10000)
		T.equal(Rules.purchase(s, Catalog, id, 2), "locked")
		T.equal(s.coins, 10000)
		T.equal(Rules.purchase(s, Catalog, id, 1), "purchased")
		local coins = s.coins
		T.equal(Rules.purchase(s, Catalog, id, 1), "owned")
		T.equal(Rules.purchase(s, Catalog, id, 0), "owned")
		T.equal(s.coins, coins)
		T.equal(s.upgrades[id], 1)
	end)
	T.test(id .. " reaches exact cap without charging beyond cap", function()
		local s = state(10000)
		local total = 0
		for level = 1, 5 do
			total += Catalog[id].levels[level + 1].price
			T.equal(Rules.purchase(s, Catalog, id, level), "purchased")
		end
		T.equal(s.coins, 10000 - total)
		T.equal(Rules.purchase(s, Catalog, id, 6), "maxLevel")
		T.equal(s.coins, 10000 - total)
	end)
	for _, value in { -1, 1.5, math.huge, 0/0, 9007199254740992, "1", true, {} } do
		T.test(id .. " malformed requested level " .. tostring(value) .. " rejects", function()
			local s = state(10000)
			T.equal(Rules.purchase(s, Catalog, id, value), "invalidUpgrade")
			T.equal(s.coins, 10000)
			T.equal(s.upgrades[id], 0)
		end)
	end
end
T.test("unknown upgrade cannot debit or add a level", function()
	local s = state(10000)
	T.equal(Rules.purchase(s, Catalog, "coins", 1), "invalidUpgrade")
	T.equal(s.upgrades.coins, nil)
	T.equal(s.coins, 10000)
end)
T.test("missing desired level cannot mutate", function()
	local s = state(10000)
	T.equal(Rules.purchase(s, Catalog, "range", nil), "invalidUpgrade")
	T.equal(s.coins, 10000)
end)
T.test("catalog preserves independent configured stat ladders", function()
	local expected: { [string]: { number } } = { range = { 12, 18, 24, 30, 36, 42 }, power = { 1, 1.25, 1.5, 2, 2.5, 3 }, speed = { 16, 18, 20, 22, 24, 26 } }
	for _, id in Rules.orderedIds do
		T.equal(#Catalog[id].levels, 6)
		for index, value in expected[id] do
			local entry = Rules.definitionFor(Catalog, id, index - 1)
			assert(entry)
			T.equal(entry.value, value)
			T.equal(entry.level, index - 1)
		end
	end
end)
for _, invalid in { 0, -1, math.huge, 0/0, "18" } do
	T.test("nonpositive or nonfinite catalog value " .. tostring(invalid) .. " cannot charge", function()
		local catalog: any = table.clone(Catalog)
		catalog.range = table.clone(Catalog.range)
		catalog.range.levels = table.clone(Catalog.range.levels)
		catalog.range.levels[2] = table.clone(Catalog.range.levels[2])
		catalog.range.levels[2].value = invalid
		local s = state(10000)
		T.equal(Rules.definitionFor(catalog, "range", 1), nil)
		T.equal(Rules.purchase(s, catalog, "range", 1), nil)
		T.equal(s.coins, 10000)
		T.equal(s.upgrades.range, 0)
	end)
end
for _, invalid in { 0, -1, 0.5, math.huge, 0/0, 9007199254740992, "25" } do
	T.test("invalid catalog price " .. tostring(invalid) .. " cannot charge", function()
		local catalog: any = table.clone(Catalog)
		catalog.range = table.clone(Catalog.range)
		catalog.range.levels = table.clone(Catalog.range.levels)
		catalog.range.levels[2] = table.clone(Catalog.range.levels[2])
		catalog.range.levels[2].price = invalid
		local s = state(10000)
		T.equal(Rules.definitionFor(catalog, "range", 1), nil)
		T.equal(Rules.purchase(s, catalog, "range", 1), nil)
		T.equal(s.coins, 10000)
		T.equal(s.upgrades.range, 0)
	end)
end
T.test("missing intermediate entry is not a legitimate maximum", function()
	local catalog: any = table.clone(Catalog)
	catalog.range = table.clone(Catalog.range)
	catalog.range.levels = table.clone(Catalog.range.levels)
	catalog.range.levels[2] = nil
	local s = state(10000)
	T.equal(Rules.purchase(s, catalog, "range", 1), nil)
	T.equal(s.coins, 10000)
	T.equal(s.upgrades.range, 0)
end)
return true
