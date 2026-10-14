--!strict

export type Session = { coins: number, inventory: { [string]: number } }
export type Prices = { [string]: number }

local MAX_SAFE_INTEGER = 9007199254740991
local Sales = {}

local function validInteger(value: unknown): boolean
	return typeof(value) == "number" and value >= 0 and value <= MAX_SAFE_INTEGER
		and value % 1 == 0
end

-- A coin pickup credits the wallet directly and never creates inventory.
-- Reward comes from the server catalog, not a remote argument.
function Sales.creditCoins(session: Session, reward: number): boolean
	if not validInteger(session.coins) or not validInteger(reward) or reward == 0 then
		return false
	end
	local balance = session.coins + reward
	if not validInteger(balance) then
		return false
	end
	session.coins = balance
	return true
end

-- Validate the whole sale before mutating either inventory or balance.
-- Quantities and prices are server-owned; callers supply no client data here.
function Sales.sellAll(session: Session, prices: Prices): number?
	if not validInteger(session.coins) then
		return nil
	end
	for objectId, price in prices do
		if typeof(objectId) ~= "string" or objectId == ""
			or not validInteger(price) or price == 0 then
			return nil
		end
	end
	local total = 0
	for objectId, count in session.inventory do
		local price = prices[objectId]
		if typeof(objectId) ~= "string" or objectId == ""
			or price == nil or not validInteger(count) then
			return nil
		end
		local value = count * price
		if not validInteger(value) then
			return nil
		end
		total += value
		if not validInteger(total) then
			return nil
		end
	end
	local balance = session.coins + total
	if not validInteger(balance) then
		return nil
	end
	if total == 0 then
		return 0
	end

	-- Synchronous consume-and-credit: a repeated request sees an empty inventory.
	for objectId in session.inventory do
		session.inventory[objectId] = 0
	end
	session.coins = balance
	return total
end

return table.freeze(Sales)
