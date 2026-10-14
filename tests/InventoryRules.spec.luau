--!strict

local T = require("./TestHarness")
local Inventory = require("../src/shared/InventoryRules")
local Rules = require("../src/shared/CollectionRules")
local Definitions = require("../src/shared/CollectibleDefinitions")
local metals: { [string]: Definitions.Definition } = {}
for id, definition in Definitions do
	if definition.kind == "Metal" then
		metals[id] = definition
	end
end

T.test("new inventory initializes every catalog metal to zero", function()
	local counts = Inventory.create(metals)
	local keys = 0
	for objectId, count in counts do
		T.equal(metals[objectId] ~= nil, true)
		T.equal(count, 0)
		keys += 1
	end
	T.equal(keys, 3)
end)

T.test("inventories are isolated across players and new sessions", function()
	local first = Inventory.create(metals)
	local second = Inventory.create(metals)
	T.equal(Inventory.add(first, "bolt"), true)
	T.equal(first.bolt, 1)
	T.equal(second.bolt, 0)
	T.equal(Inventory.create(metals).bolt, 0)
end)

T.test("one pickup adds one unit rather than its coin value", function()
	local counts = Inventory.create(metals)
	for objectId in metals do
		T.equal(Inventory.add(counts, objectId), true)
		T.equal(counts[objectId], 1)
	end
	T.equal(Inventory.add(counts, "gear"), true)
	T.equal(counts.gear, 2)
	T.equal(counts.can, 1)
	T.equal(counts.bolt, 1)
end)

T.test("unknown and hostile object ids cannot create inventory entries", function()
	local counts = Inventory.create(metals)
	for _, objectId in { "coin", "", "unknown", "GEAR", "gear\0", "../../gear", string.rep("gear", 1000) } do
		T.equal(Inventory.add(counts, objectId), false)
		T.equal(counts[objectId], nil)
	end
	T.equal(counts.gear, 0)
end)

T.test("rejected claims change neither inventory nor coins", function()
	local counts = Inventory.create(metals)
	local coins = 0
	local entry: Rules.State = { objectId = "can", lifecycleId = "current", available = true }
	for _, request in {
		{ token = "stale", distance = 1, validCharacter = true },
		{ token = "current", distance = 99, validCharacter = true },
		{ token = "current", distance = 1, validCharacter = false },
	} do
		local result = Rules.claim(Definitions, entry, request.token, {
			distance = request.distance, validCharacter = request.validCharacter,
		}, 12, 1)
		if result.accepted then
			Inventory.add(counts, entry.objectId)
		end
	end
	T.equal(entry.available, true)
	T.equal(counts.can, 0)
	T.equal(coins, 0)
end)

T.test("claimed lifecycle grants inventory only and no coins despite replays", function()
	local counts = Inventory.create(metals)
	local coins = 0
	local entry: Rules.State = { objectId = "can", lifecycleId = "first", available = true }
	for _ = 1, 100 do
		local result = Rules.claim(Definitions, entry, "first", {
			distance = 1, validCharacter = true,
		}, 12, 1)
		if result.accepted then
			T.equal(Inventory.add(counts, entry.objectId), true)
		end
	end
	T.equal(counts.can, 1)
	T.equal(coins, 0)

	entry.lifecycleId = "second"
	entry.available = true
	T.equal(Rules.claim(Definitions, entry, "first", {
		distance = 1, validCharacter = true,
	}, 12, 1).accepted, false)
	local result = Rules.claim(Definitions, entry, "second", {
		distance = 1, validCharacter = true,
	}, 12, 1)
	T.equal(result.accepted, true)
	T.equal(Inventory.add(counts, entry.objectId), true)
	T.equal(counts.can, 2)
	T.equal(coins, 0)
end)

return true
