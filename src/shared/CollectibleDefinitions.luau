--!strict

export type Definition = {
	id: string,
	name: string,
	kind: string,
	reward: number,
	color: { number },
	size: { number },
	shape: string,
	position: { number },
}

-- Scalar data keeps this module runnable in standalone Luau as well as Studio.
local definitions: { [string]: Definition } = {
	bolt = {
		id = "bolt", name = "Bolt", kind = "Metal", reward = 1,
		color = { 170, 180, 190 }, size = { 1, 1, 2 }, shape = "Block",
		position = { -20, 1.5, -24 },
	},
	can = {
		id = "can", name = "Can", kind = "Metal", reward = 3,
		color = { 80, 150, 220 }, size = { 2, 1.5, 1.5 }, shape = "Cylinder",
		position = { 0, 1.5, -24 },
	},
	gear = {
		id = "gear", name = "Gear", kind = "Metal", reward = 5,
		color = { 210, 175, 80 }, size = { 0.6, 2.5, 2.5 }, shape = "Cylinder",
		position = { 20, 1.5, -24 },
	},
	coin = {
		id = "coin", name = "Coin", kind = "Coin", reward = 1,
		color = { 255, 235, 45 }, size = { 0.4, 2, 2 }, shape = "Cylinder",
		position = { 0, 1.5, 24 },
	},
}

for _, definition in definitions do
	table.freeze(definition.color)
	table.freeze(definition.size)
	table.freeze(definition.position)
	table.freeze(definition)
end

return table.freeze(definitions)
