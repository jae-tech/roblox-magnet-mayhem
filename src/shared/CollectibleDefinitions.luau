--!strict

export type Definition = {
	id: string,
	name: string,
	kind: string,
	rarity: string,
	reward: number,
	color: { number },
	size: { number },
	shape: string,
	position: { number },
}

-- Scalar data keeps this module runnable in standalone Luau as well as Studio.
local definitions: { [string]: Definition } = {
	bolt = {
		id = "bolt", name = "Bolt", kind = "Metal", rarity = "Common", reward = 1,
		color = { 170, 180, 190 }, size = { 1, 1, 2 }, shape = "Block",
		position = { -20, 1.5, -24 },
	},
	can = {
		id = "can", name = "Can", kind = "Metal", rarity = "Common", reward = 3,
		color = { 80, 150, 220 }, size = { 2, 1.5, 1.5 }, shape = "Cylinder",
		position = { 0, 1.5, -24 },
	},
	gear = {
		id = "gear", name = "Gear", kind = "Metal", rarity = "Rare", reward = 5,
		color = { 210, 175, 80 }, size = { 0.6, 2.5, 2.5 }, shape = "Cylinder",
		position = { 20, 1.5, -24 },
	},
	washer = {
		id = "washer", name = "Washer", kind = "Metal", rarity = "Common", reward = 2,
		color = { 170, 180, 190 }, size = { 1.5, 1.5, 1.5 }, shape = "Block",
		position = { -40, 1.5, -24 },
	},
	nut = {
		id = "nut", name = "Nut", kind = "Metal", rarity = "Common", reward = 2,
		color = { 170, 180, 190 }, size = { 1.5, 1.5, 1.5 }, shape = "Block",
		position = { 40, 1.5, -24 },
	},
	screw = {
		id = "screw", name = "Screw", kind = "Metal", rarity = "Common", reward = 1,
		color = { 170, 180, 190 }, size = { 1.5, 1.5, 1.5 }, shape = "Block",
		position = { -20, 1.5, -44 },
	},
	nail = {
		id = "nail", name = "Nail", kind = "Metal", rarity = "Common", reward = 1,
		color = { 170, 180, 190 }, size = { 1.5, 1.5, 1.5 }, shape = "Block",
		position = { 0, 1.5, -44 },
	},
	chain = {
		id = "chain", name = "Chain", kind = "Metal", rarity = "Rare", reward = 8,
		color = { 80, 150, 220 }, size = { 1.5, 1.5, 1.5 }, shape = "Block",
		position = { 20, 1.5, -44 },
	},
	lock = {
		id = "lock", name = "Lock", kind = "Metal", rarity = "Rare", reward = 10,
		color = { 80, 150, 220 }, size = { 1.5, 1.5, 1.5 }, shape = "Block",
		position = { -40, 1.5, 0 },
	},
	spring = {
		id = "spring", name = "Spring", kind = "Metal", rarity = "Rare", reward = 12,
		color = { 80, 150, 220 }, size = { 1.5, 1.5, 1.5 }, shape = "Block",
		position = { 40, 1.5, 0 },
	},
	battery = {
		id = "battery", name = "Battery", kind = "Metal", rarity = "Epic", reward = 18,
		color = { 180, 110, 235 }, size = { 1.5, 1.5, 1.5 }, shape = "Block",
		position = { -40, 1.5, 24 },
	},
	circuit = {
		id = "circuit", name = "Circuit", kind = "Metal", rarity = "Epic", reward = 22,
		color = { 180, 110, 235 }, size = { 1.5, 1.5, 1.5 }, shape = "Block",
		position = { 40, 1.5, 24 },
	},
	motor = {
		id = "motor", name = "Motor", kind = "Metal", rarity = "Epic", reward = 30,
		color = { 180, 110, 235 }, size = { 1.5, 1.5, 1.5 }, shape = "Block",
		position = { -20, 1.5, 44 },
	},
	metalCrystal = {
		id = "metalCrystal", name = "Metal Crystal", kind = "Metal", rarity = "Legendary", reward = 45,
		color = { 255, 205, 65 }, size = { 1.5, 1.5, 1.5 }, shape = "Block",
		position = { 0, 1.5, 44 },
	},
	goldenCrown = {
		id = "goldenCrown", name = "Golden Crown", kind = "Metal", rarity = "Legendary", reward = 60,
		color = { 255, 205, 65 }, size = { 1.5, 1.5, 1.5 }, shape = "Block",
		position = { 20, 1.5, 44 },
	},
	coin = {
		id = "coin", name = "Coin", kind = "Coin", rarity = "Currency", reward = 1,
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
