--!strict

-- A deterministic dynamic domain simulation, NOT Roblox networking/Studio proof.
local T = require("./TestHarness")
local Rules = require("../src/shared/CollectionRules")
local Definitions = require("../src/shared/CollectibleDefinitions")

T.test("two simulated contenders, 100 lifecycles, hostile replays", function()
	local balances = { 0, 0 }
	local entry: Rules.State = { objectId = "gear", lifecycleId = "initial", available = true }
	for generation = 1, 100 do
		local oldToken = entry.lifecycleId
		entry.lifecycleId = "spawn-" .. tostring(generation)
		entry.available = true
		local before = balances[1] + balances[2]
		for attempt = 1, 30 do
			local player = (attempt + generation) % 2 + 1
			local result = Rules.claim(Definitions, entry,
				if attempt <= 10 then oldToken else entry.lifecycleId,
				{ validCharacter = true, distance = 3 }, 12, 1)
			balances[player] += result.reward
		end
		T.equal(balances[1] + balances[2] - before, 5)
	end
	T.equal(balances[1] + balances[2], 500)
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

T.finish()
