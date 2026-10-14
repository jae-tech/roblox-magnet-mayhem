--!strict

export type Level = { level: number, price: number, value: number }
export type Definition = { id: string, name: string, levels: { Level } }
export type Session = { coins: number, upgrades: { [string]: number } }
export type Status = "purchased" | "insufficientCoins" | "owned" | "locked" | "invalidUpgrade" | "maxLevel"
local Rules = {}
Rules.orderedIds = table.freeze({ "range", "power", "speed" })
local function integer(value: unknown): boolean
	return typeof(value) == "number" and value >= 0 and value <= 9007199254740991 and value % 1 == 0
end
function Rules.definitionFor(catalog: { [string]: Definition }, id: unknown, level: unknown): Level?
	if typeof(id) ~= "string" or typeof(level) ~= "number" or not integer(level) then return nil end
	local definition = catalog[id]
	if not definition or definition.id ~= id then return nil end
	local entry = definition.levels[level + 1]
	if not entry or entry.level ~= level or not integer(entry.price)
		or (level == 0 and entry.price ~= 0) or (level > 0 and entry.price == 0)
		or typeof(entry.value) ~= "number" or not (entry.value > 0 and entry.value < math.huge) then return nil end
	return entry
end
function Rules.purchase(session: Session, catalog: { [string]: Definition }, id: unknown, level: unknown): Status?
	if not integer(session.coins) or typeof(id) ~= "string" then return nil end
	local current = session.upgrades[id]
	if not current or not Rules.definitionFor(catalog, id, current) then return "invalidUpgrade" end
	if typeof(level) ~= "number" or not integer(level) then return "invalidUpgrade" end
	if not Rules.definitionFor(catalog, id, current + 1) then
		-- A present but invalid next entry is a configuration error, not a cap.
		if current ~= 5 or catalog[id].levels[current + 2] ~= nil then return nil end
		return "maxLevel"
	end
	local requested = Rules.definitionFor(catalog, id, level)
	if not requested then return "invalidUpgrade" end
	if level <= current then return "owned" end
	if level ~= current + 1 then return "locked" end
	if session.coins < requested.price then return "insufficientCoins" end
	session.coins -= requested.price
	session.upgrades[id] = level
	return "purchased"
end
return table.freeze(Rules)
