--!strict

export type Definition = {
	tier: number, id: string, name: string, price: number, style: string, color: { number },
}

-- Skins change appearance only; gameplay statistics are independent upgrades.
local definitions: { Definition } = {
	{ tier = 1, id = "starter", name = "Starter", price = 0, style = "Classic", color = { 230, 70, 70 } },
	{ tier = 2, id = "iron", name = "Iron", price = 25, style = "Industrial", color = { 100, 175, 235 } },
	{ tier = 3, id = "gold", name = "Gold", price = 100, style = "Royal", color = { 255, 205, 65 } },
}
for _, definition in definitions do
	table.freeze(definition.color)
	table.freeze(definition)
end
return table.freeze(definitions)
