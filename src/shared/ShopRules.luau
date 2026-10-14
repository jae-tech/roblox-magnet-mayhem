--!strict

export type Definition = { tier: number, id: string, name: string, price: number, style: string, color: { number } }
export type Session = { coins: number, magnetTier: number, ownedMagnets: { [string]: boolean } }
export type Status = "purchased" | "equipped" | "insufficientCoins" | "owned" | "invalidTier"
local Shop = {}
local function integer(value: unknown): boolean
	return typeof(value) == "number" and value >= 0 and value <= 9007199254740991 and value % 1 == 0
end
function Shop.definitionFor(definitions: { Definition }, tier: unknown): Definition?
	if typeof(tier) ~= "number" or not integer(tier) or tier == 0 then return nil end
	local found: Definition? = nil
	for _, definition in definitions do
		if definition.tier == tier then
			if found or not integer(definition.price) or typeof(definition.id) ~= "string" or definition.id == "" then return nil end
			found = definition
		end
	end
	return found
end
function Shop.purchase(session: Session, definitions: { Definition }, requestedTier: unknown): Status?
	local knownIds: { [string]: boolean } = {}
	for index, definition in definitions do
		if definition.tier ~= index or Shop.definitionFor(definitions, index) == nil
			or knownIds[definition.id] or (index == 1 and definition.price ~= 0)
			or (index > 1 and definition.price == 0) then return nil end
		knownIds[definition.id] = true
	end
	for id, owned in session.ownedMagnets do
		if not knownIds[id] or owned ~= true then return nil end
	end
	if not definitions[1] or session.ownedMagnets[definitions[1].id] ~= true then return nil end
	local current = Shop.definitionFor(definitions, session.magnetTier)
	if not integer(session.coins) or not current or session.ownedMagnets[current.id] ~= true then return nil end
	local requested = Shop.definitionFor(definitions, requestedTier)
	if not requested then return "invalidTier" end
	if session.ownedMagnets[requested.id] == true then
		if session.magnetTier == requested.tier then return "owned" end
		session.magnetTier = requested.tier
		return "equipped"
	end
	if session.coins < requested.price then return "insufficientCoins" end
	-- Ownership, debit and equip are one non-yielding transaction.
	session.coins -= requested.price
	session.ownedMagnets[requested.id] = true
	session.magnetTier = requested.tier
	return "purchased"
end
return table.freeze(Shop)
