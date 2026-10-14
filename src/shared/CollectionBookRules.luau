--!strict

export type Discovery = { [string]: boolean }
export type Receipt = { objectId: string, count: number, reward: number }

local Book = { attributePrefix = "Discovered_" }
Book.orderedIds = table.freeze({
	"bolt", "can", "gear", "washer", "nut", "screw", "nail", "chain",
	"lock", "spring", "battery", "circuit", "motor", "metalCrystal", "goldenCrown",
})
local rarityColors: { [string]: { number } } = {
	Common = table.freeze({ 170, 180, 190 }), Rare = table.freeze({ 80, 150, 220 }),
	Epic = table.freeze({ 180, 110, 235 }), Legendary = table.freeze({ 255, 205, 65 }),
}
Book.rarityColors = table.freeze(rarityColors)
Book.milestones = table.freeze({
	table.freeze({ count = 3, reward = 10 }),
	table.freeze({ count = 7, reward = 30 }),
	table.freeze({ count = 15, reward = 100 }),
})
local known: { [string]: boolean } = {}
for _, id in Book.orderedIds do known[id] = true end
table.freeze(known)

function Book.validate(value: unknown): Discovery?
	if typeof(value) ~= "table" then return nil end
	local result: Discovery = {}
	for id, discovered in value :: { [any]: any } do
		if typeof(id) ~= "string" or not known[id] or discovered ~= true then return nil end
		result[id] = true
	end
	return result
end

function Book.count(discovered: Discovery): number
	local count = 0
	for _, id in Book.orderedIds do
		if discovered[id] == true then count += 1 end
	end
	return count
end

-- Pure copy-on-record: rewards exist only on the first crossing, never on load.
function Book.record(discovered: Discovery, objectId: string): (Discovery?, number?, number?)
	local copy = Book.validate(discovered)
	if not copy or not known[objectId] then return nil, nil, nil end
	local count = Book.count(copy)
	if copy[objectId] then return copy, 0, count end
	copy[objectId] = true
	count += 1
	local reward = 0
	for _, milestone in Book.milestones do
		if milestone.count == count then reward = milestone.reward end
	end
	return copy, reward, count
end

return table.freeze(Book)
