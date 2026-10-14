--!strict

local T = require("./TestHarness")
local Rules = require("../src/shared/CollectionRules")
local Definitions = require("../src/shared/CollectibleDefinitions")
local Config = require("../src/shared/MagnetConfig")

local function state(): Rules.State
	return { objectId = "bolt", lifecycleId = "spawn-1", available = true }
end

local function claim(entry: Rules.State?, token: string?, distance: number?, validCharacter: boolean?)
	return Rules.claim(Definitions, entry, token or "spawn-1", {
		distance = distance or 1,
		validCharacter = if validCharacter == nil then true else validCharacter,
	}, Config.attractionRadius, Config.distanceTolerance)
end

T.test("catalog contains fifteen metals and one separate coin", function()
	local count = 0
	local metals, coins = 0, 0
	for key, definition in Definitions do
		count += 1
		if definition.kind == "Metal" then metals += 1 else coins += 1 end
		T.equal(Rules.validDefinition(key, definition), true)
		T.equal(Rules.rewardFor(Definitions, key), definition.reward)
	end
	T.equal(count, 16)
	T.equal(metals, 15)
	T.equal(coins, 1)
	T.equal(Definitions.coin.kind, "Coin")
end)

T.test("catalog unit values are exact", function()
	T.equal(Rules.rewardFor(Definitions, "bolt"), 1)
	T.equal(Rules.rewardFor(Definitions, "can"), 3)
	T.equal(Rules.rewardFor(Definitions, "gear"), 5)
	T.equal(Rules.rewardFor(Definitions, "coin"), 1)
end)

T.test("unknown reward rejected", function()
	T.equal(Rules.rewardFor(Definitions, "imaginary"), nil)
end)

T.test("invalid definitions never pay", function()
	for _, reward in { 0, -1, 1.5, math.huge, -math.huge, 0 / 0 } do
		T.equal(Rules.validDefinition("bad", { id = "bad", kind = "Metal", reward = reward }), false)
	end
	T.equal(Rules.validDefinition("bad", { id = "other", kind = "Metal", reward = 1 }), false)
	T.equal(Rules.validDefinition("", { id = "", kind = "Coin", reward = 1 }), false)
end)

T.test("unknown or missing collectible kind cannot be claimed", function()
	T.equal(Rules.validDefinition("bad", { id = "bad", reward = 1 } :: any), false)
	for _, kind in { "", "metal", "Gem", 1 :: any } do
		T.equal(Rules.validDefinition("bad", { id = "bad", kind = kind, reward = 1 }), false)
	end
end)

T.test("valid collection returns unit value and consumes spawn", function()
	local entry = state()
	local result = claim(entry)
	T.equal(result.accepted, true)
	T.equal(result.reward, 1)
	T.equal(entry.available, false)
end)

T.test("inclusive distance boundary", function()
	T.equal(claim(state(), nil, 13).accepted, true)
	T.equal(claim(state(), nil, 0).accepted, true)
end)

T.test("just outside range rejected without mutation", function()
	local entry = state()
	local result = claim(entry, nil, 13.0001)
	T.equal(result.reason, "out_of_range")
	T.equal(result.reward, 0)
	T.equal(entry.available, true)
end)

T.test("nonfinite and negative distances rejected", function()
	for _, distance in { -1, math.huge, -math.huge, 0 / 0 } do
		T.equal(claim(state(), nil, distance).accepted, false)
	end
end)

T.test("invalid range tuning rejected", function()
	for _, values in { { 0, 1 }, { -1, 1 }, { 12, -1 }, { math.huge, 0 }, { 12, 0 / 0 } } do
		T.equal(Rules.inRange(1, values[1], values[2]), false)
	end
	T.equal(Rules.inRange(1, 1e308, 1e308), false)
end)

T.test("unknown registry target rejected", function()
	T.equal(claim(nil).reason, "unknown_target")
end)

T.test("unknown definition rejected", function()
	local entry = state()
	entry.objectId = "unknown"
	T.equal(claim(entry).reason, "unknown_target")
	T.equal(entry.available, true)
end)

T.test("invalid character rejected", function()
	local entry = state()
	T.equal(claim(entry, nil, nil, false).reason, "invalid_character")
	T.equal(entry.available, true)
end)

T.test("unavailable target rejected", function()
	local entry = state()
	entry.available = false
	T.equal(claim(entry).reason, "unavailable")
end)

T.test("stale and empty tokens rejected", function()
	local entry = state()
	T.equal(claim(entry, "stale").reason, "stale_lifecycle")
	T.equal(claim(entry, "").reason, "stale_lifecycle")
	T.equal(entry.available, true)
end)

T.test("replays return unit value at most once per lifecycle", function()
	local entry = state()
	local total = 0
	for _ = 1, 100 do
		total += claim(entry).reward
	end
	T.equal(total, 1)
end)

T.test("respawn rejects old token and permits new token once", function()
	local entry = state()
	T.equal(claim(entry).reward, 1)
	entry.lifecycleId = "spawn-2"
	entry.available = true
	T.equal(claim(entry, "spawn-1").accepted, false)
	T.equal(claim(entry, "spawn-2").reward, 1)
	T.equal(claim(entry, "spawn-2").reward, 0)
end)

T.test("evaluate alone never mutates", function()
	local entry = state()
	local result = Rules.evaluate(Definitions, entry, "spawn-1", {
		validCharacter = true, distance = 1,
	}, 12, 1)
	T.equal(result.accepted, true)
	T.equal(entry.available, true)
end)

T.test("request bucket bounds flood and refills", function()
	local bucket: Rules.Bucket = { tokens = 6, updatedAt = 0 }
	local accepted = 0
	for _ = 1, 100 do
		if Rules.consumeRequest(bucket, 0, 12, 6) then
			accepted += 1
		end
	end
	T.equal(accepted, 6)
	T.equal(Rules.consumeRequest(bucket, 1, 12, 6), true)
	T.equal(bucket.tokens, 5)
end)

T.test("backwards clock does not create tokens", function()
	local bucket: Rules.Bucket = { tokens = 0, updatedAt = 10 }
	T.equal(Rules.consumeRequest(bucket, 9, 12, 6), false)
	T.equal(bucket.updatedAt, 10)
end)

T.test("invalid rate tuning safely rejected", function()
	local bucket: Rules.Bucket = { tokens = 6, updatedAt = 0 }
	T.equal(Rules.consumeRequest(bucket, 0 / 0, 12, 6), false)
	T.equal(Rules.consumeRequest(bucket, 0, 0, 6), false)
	T.equal(Rules.consumeRequest(bucket, 0, 12, 0), false)
end)

return true
