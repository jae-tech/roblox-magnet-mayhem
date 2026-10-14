--!strict
local T = require("./TestHarness")
local Book = require("../src/shared/CollectionBookRules")
local Definitions = require("../src/shared/CollectibleDefinitions")
T.test("book lists every metal exactly once and excludes coins", function()
	local seen: { [string]: boolean } = {}
	local rarities: { [string]: boolean } = { Common = true, Rare = true, Epic = true, Legendary = true }
	T.equal(#Book.orderedIds, 15)
	for _, id in Book.orderedIds do
		T.equal(seen[id], nil)
		T.equal(Definitions[id].kind, "Metal")
		T.equal(rarities[Definitions[id].rarity] == true, true)
		seen[id] = true
	end
	for id, definition in Definitions do
		T.equal(seen[id] == true, definition.kind == "Metal")
	end
end)
T.test("book validates sparse known true maps and copies them", function()
	local original: Book.Discovery = { bolt = true }
	local result = Book.validate(original)
	assert(result)
	result.can = true
	T.equal(original.can, nil)
	T.equal(Book.count(result), 2)
	T.equal(Book.count({}), 0)
	for _, invalid in { false, 1, "bolt", { bolt = false }, { bolt = 1 }, { coin = true }, { unknown = true }, { [1] = true } } do
		T.equal(Book.validate(invalid), nil)
	end
	T.equal(Book.validate(nil), nil)
end)
T.test("third seventh and fifteenth unique discoveries pay exact milestones once", function()
	local discovered: Book.Discovery = {}
	local total = 0
	for i, id in Book.orderedIds do
		local before = Book.count(discovered)
		local nextMap, reward, count = Book.record(discovered, id)
		assert(nextMap and reward and count)
		T.equal(Book.count(discovered), before)
		T.equal(count, i)
		T.equal(reward, if i == 3 then 10 elseif i == 7 then 30 elseif i == 15 then 100 else 0)
		total += reward
		discovered = nextMap
		local repeated, repeatReward, repeatCount = Book.record(discovered, id)
		assert(repeated)
		T.equal(repeatReward, 0)
		T.equal(repeatCount, i)
	end
	T.equal(total, 140)
end)
T.test("reloaded discovery history cannot award completed milestones again", function()
	local original: Book.Discovery = {}
	for i = 1, 7 do original[Book.orderedIds[i]] = true end
	local restored = Book.validate(original)
	assert(restored)
	local nextMap, reward, count = Book.record(restored, Book.orderedIds[7])
	assert(nextMap)
	T.equal(reward, 0)
	T.equal(count, 7)
	local eighth, eighthReward, eighthCount = Book.record(nextMap, Book.orderedIds[8])
	assert(eighth)
	T.equal(eighthReward, 0)
	T.equal(eighthCount, 8)
end)
T.test("coin and unknown IDs cannot enter book or grant milestone rewards", function()
	local discovered = { bolt = true, can = true }
	for _, id in { "coin", "", "unknown", "BOLT", "bolt\0" } do
		local result, reward, count = Book.record(discovered, id)
		T.equal(result, nil)
		T.equal(reward, nil)
		T.equal(count, nil)
		T.equal(Book.count(discovered), 2)
	end
end)
T.test("malformed discovery state cannot advance or award rewards", function()
	for _, state in { { bolt = false }, { coin = true }, { unknown = true } } do
		local result, reward, count = Book.record(state, "gear")
		T.equal(result, nil)
		T.equal(reward, nil)
		T.equal(count, nil)
	end
end)
return true
