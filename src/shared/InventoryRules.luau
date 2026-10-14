--!strict

export type Counts = { [string]: number }

local Inventory = { attributePrefix = "Inventory_" }

function Inventory.create<T>(definitions: { [string]: T }): Counts
	local counts: Counts = {}
	for objectId in definitions do
		counts[objectId] = 0
	end
	return counts
end

-- One accepted metal claim adds one unit, regardless of its sale value.
-- No client-supplied quantity or reward is part of this interface.
function Inventory.add(counts: Counts, objectId: string): boolean
	local count = counts[objectId]
	if count == nil then
		return false
	end
	counts[objectId] = count + 1
	return true
end

return table.freeze(Inventory)
