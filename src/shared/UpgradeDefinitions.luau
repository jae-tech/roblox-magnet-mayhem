--!strict

export type Level = { level: number, price: number, value: number }
export type Definition = { id: string, name: string, levels: { Level } }
local definitions: { [string]: Definition } = {}
local function define(id: string, name: string, values: { number }, prices: { number })
	local levels: { Level } = {}
	for index, value in values do
		local entry: Level = { level = index - 1, price = prices[index], value = value }
		levels[index] = entry
		table.freeze(entry)
	end
	local definition: Definition = { id = id, name = name, levels = levels }
	table.freeze(levels)
	definitions[id] = definition
	table.freeze(definition)
end
define("range", "Range", { 12, 18, 24, 30, 36, 42 }, { 0, 25, 100, 250, 500, 1000 })
define("power", "Power", { 1, 1.25, 1.5, 2, 2.5, 3 }, { 0, 20, 60, 150, 350, 700 })
define("speed", "Move speed", { 16, 18, 20, 22, 24, 26 }, { 0, 20, 60, 150, 350, 700 })
return table.freeze(definitions)
