--!strict

export type Definition = {
	tier: number,
	name: string,
	price: number,
	radius: number,
	color: { number },
}

-- Coin prices only. Higher tiers replace the equipped session magnet.
local definitions: { Definition } = {
	{ tier = 1, name = "Starter", price = 0, radius = 12, color = { 230, 70, 70 } },
	{ tier = 2, name = "Iron", price = 25, radius = 18, color = { 100, 175, 235 } },
	{ tier = 3, name = "Gold", price = 100, radius = 24, color = { 255, 205, 65 } },
}

for _, definition in definitions do
	table.freeze(definition.color)
	table.freeze(definition)
end

return table.freeze(definitions)
