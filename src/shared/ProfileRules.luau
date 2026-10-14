--!strict

export type Profile = { coins: number, inventory: { [string]: number }, magnetTier: number }
export type Lease = { owner: string, expiresAt: number }
export type Record = { version: number, data: Profile, lease: Lease? }
local Rules = {}
local keys = table.freeze({ "bolt", "can", "gear" })
Rules.inventoryKeys = keys
Rules.version = 1
local function integer(value: unknown): boolean
	return typeof(value) == "number" and value >= 0 and value <= 9007199254740991 and value % 1 == 0
end
local function exactKeys(value: { [any]: any }, allowed: { [string]: boolean }): boolean
	for key in value do
		if typeof(key) ~= "string" or not allowed[key] then return false end
	end
	return true
end
function Rules.defaults(): Profile
	return { coins = 0, inventory = { bolt = 0, can = 0, gear = 0 }, magnetTier = 1 }
end
function Rules.clone(profile: Profile): Profile
	return { coins = profile.coins, inventory = table.clone(profile.inventory), magnetTier = profile.magnetTier }
end
function Rules.validate(value: unknown): Profile?
	if typeof(value) ~= "table" then return nil end
	local raw = value :: { [any]: any }
	if not exactKeys(raw, { coins = true, inventory = true, magnetTier = true })
		or not integer(raw.coins) or not integer(raw.magnetTier)
		or raw.magnetTier < 1 or raw.magnetTier > 3 or typeof(raw.inventory) ~= "table" then return nil end
	local inventory = raw.inventory :: { [any]: any }
	if not exactKeys(inventory, { bolt = true, can = true, gear = true }) then return nil end
	for _, key in keys do if not integer(inventory[key]) then return nil end end
	return { coins = raw.coins, inventory = { bolt = inventory.bolt, can = inventory.can, gear = inventory.gear }, magnetTier = raw.magnetTier }
end
function Rules.decode(value: unknown): Record?
	if typeof(value) ~= "table" then return nil end
	local raw = value :: { [any]: any }
	if not exactKeys(raw, { version = true, data = true, lease = true }) or raw.version ~= 1 then return nil end
	local data = Rules.validate(raw.data)
	if not data then return nil end
	local lease: Lease? = nil
	if raw.lease ~= nil then
		if typeof(raw.lease) ~= "table" then return nil end
		local lock = raw.lease :: { [any]: any }
		if not exactKeys(lock, { owner = true, expiresAt = true }) or typeof(lock.owner) ~= "string"
			or lock.owner == "" or not integer(lock.expiresAt) then return nil end
		lease = { owner = lock.owner, expiresAt = lock.expiresAt } :: Lease
	end
	return { version = 1, data = data, lease = lease }
end
local function validOperation(owner: string, now: number, duration: number): boolean
	return owner ~= "" and integer(now) and integer(duration) and duration > 0 and integer(now + duration)
end
function Rules.acquire(old: unknown, owner: string, now: number, duration: number): Record?
	if not validOperation(owner, now, duration) then return nil end
	local record: Record?
	if old == nil then record = { version = 1, data = Rules.defaults(), lease = nil } :: Record else record = Rules.decode(old) end
	if not record then return nil end
	local lease = record.lease
	if lease then
		if lease.owner == owner then
			-- An ambiguous retry may confirm its live token, never resurrect it.
			if lease.expiresAt <= now then return nil end
		elseif lease.expiresAt > now then return nil end
	end
	record.lease = { owner = owner, expiresAt = now + duration }
	return record
end
function Rules.save(old: unknown, owner: string, snapshot: Profile, now: number, duration: number, release: boolean): Record?
	if not validOperation(owner, now, duration) then return nil end
	local record = Rules.decode(old)
	local data = Rules.validate(snapshot)
	if not record or not data or not record.lease or record.lease.owner ~= owner or record.lease.expiresAt <= now then return nil end
	return { version = 1, data = data, lease = if release then nil else { owner = owner, expiresAt = now + duration } }
end
return table.freeze(Rules)
