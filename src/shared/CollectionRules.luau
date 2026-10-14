--!strict

-- Dictionary value types are invariant in Luau. Mirror the scalar definition shape
-- so callers can pass the real catalog without casts or a Roblox-dependent require.
export type Definition = {
	id: string, name: string, kind: string, reward: number,
	color: { number }, size: { number }, shape: string, position: { number },
	rarity: string,
}
type RewardDefinition = { id: string, kind: string, reward: number }
export type State = { objectId: string, lifecycleId: string, available: boolean }
export type Facts = { validCharacter: boolean, distance: number }
export type Result = { accepted: boolean, reward: number, reason: string }
export type Bucket = { tokens: number, updatedAt: number }

local Rules = {}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function Rules.validDefinition(key: string, definition: RewardDefinition): boolean
	return key ~= "" and definition.id == key and finite(definition.reward)
		and definition.reward > 0 and definition.reward % 1 == 0
		and (definition.kind == "Metal" or definition.kind == "Coin")
end

function Rules.rewardFor(definitions: { [string]: Definition }, objectId: string): number?
	local definition = definitions[objectId]
	if not definition or not Rules.validDefinition(objectId, definition) then
		return nil
	end
	return definition.reward
end

function Rules.inRange(distance: number, radius: number, tolerance: number): boolean
	local limit = radius + tolerance
	return finite(distance) and finite(radius) and finite(tolerance) and finite(limit)
		and distance >= 0 and radius > 0 and tolerance >= 0 and distance <= limit
end

local function rejected(reason: string): Result
	return { accepted = false, reward = 0, reason = reason }
end

function Rules.evaluate(
	definitions: { [string]: Definition },
	state: State?,
	lifecycleId: string,
	facts: Facts,
	radius: number,
	tolerance: number
): Result
	if not state then
		return rejected("unknown_target")
	end
	local reward = Rules.rewardFor(definitions, state.objectId)
	if not reward then
		return rejected("unknown_target")
	end
	if state.lifecycleId ~= lifecycleId or lifecycleId == "" then
		return rejected("stale_lifecycle")
	end
	if not state.available then
		return rejected("unavailable")
	end
	if not facts.validCharacter then
		return rejected("invalid_character")
	end
	if not Rules.inRange(facts.distance, radius, tolerance) then
		return rejected("out_of_range")
	end
	return { accepted = true, reward = reward, reason = "accepted" }
end

-- This whole function is synchronous: claim precedes any external side effect.
function Rules.claim(
	definitions: { [string]: Definition },
	state: State?,
	lifecycleId: string,
	facts: Facts,
	radius: number,
	tolerance: number
): Result
	local result = Rules.evaluate(definitions, state, lifecycleId, facts, radius, tolerance)
	if result.accepted and state then
		state.available = false
	end
	return result
end

-- Token bucket bounds work per player; time is supplied by the server, never client.
function Rules.consumeRequest(bucket: Bucket, now: number, rate: number, burst: number): boolean
	if not finite(now) or not finite(rate) or not finite(burst) or rate <= 0 or burst < 1 then
		return false
	end
	local elapsed = math.max(0, now - bucket.updatedAt)
	bucket.tokens = math.min(burst, bucket.tokens + elapsed * rate)
	bucket.updatedAt = math.max(now, bucket.updatedAt)
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

return table.freeze(Rules)
