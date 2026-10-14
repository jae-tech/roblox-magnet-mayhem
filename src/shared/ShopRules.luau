--!strict

export type Definition = {
	tier: number, name: string, price: number, radius: number, color: { number },
}
export type Session = { coins: number, magnetTier: number }
export type Status = "purchased" | "insufficientCoins" | "owned" | "locked" | "invalidTier"

local MAX_SAFE_INTEGER = 9007199254740991
local Shop = {}

local function validInteger(value: unknown): boolean
	return typeof(value) == "number" and value >= 0 and value <= MAX_SAFE_INTEGER
		and value % 1 == 0
end

local function validDefinition(definition: Definition): boolean
	return validInteger(definition.tier) and definition.tier > 0
		and validInteger(definition.price)
		and typeof(definition.radius) == "number" and definition.radius > 0
		and definition.radius < math.huge
end

function Shop.definitionFor(definitions: { Definition }, tier: unknown): Definition?
	if not validInteger(tier) or typeof(tier) ~= "number" or tier == 0 then
		return nil
	end
	local found: Definition? = nil
	for _, definition in definitions do
		if definition.tier == tier then
			if found ~= nil or not validDefinition(definition) then
				return nil
			end
			found = definition
		end
	end
	return found
end

-- The catalog, balance and tier are server-owned. Validate before either write.
function Shop.purchase(session: Session, definitions: { Definition }, requestedTier: unknown): Status?
	if not validInteger(session.coins) or not validInteger(session.magnetTier)
		or Shop.definitionFor(definitions, session.magnetTier) == nil then
		return nil
	end
	for index, definition in definitions do
		if not validDefinition(definition) or definition.tier ~= index
			or (index == 1 and definition.price ~= 0)
			or (index > 1 and definition.price == 0) then
			return nil
		end
	end
	local requested = Shop.definitionFor(definitions, requestedTier)
	if requested == nil then
		return "invalidTier"
	end
	if requested.tier <= session.magnetTier then
		return "owned"
	end
	if requested.tier ~= session.magnetTier + 1 then
		return "locked"
	end
	if session.coins < requested.price then
		return "insufficientCoins"
	end
	-- No yield: replays observe the upgraded tier and cannot charge again.
	session.coins -= requested.price
	session.magnetTier = requested.tier
	return "purchased"
end

return table.freeze(Shop)
