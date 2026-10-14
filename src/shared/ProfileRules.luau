--!strict

export type Profile = { coins: number, inventory: { [string]: number }, magnetTier: number, discovered: { [string]: boolean } }
export type Lease = { owner: string, expiresAt: number }
export type Record = { version: number, data: Profile, lease: Lease? }
local Rules = {}
local legacyKeys = table.freeze({ "bolt", "can", "gear" })
local keys = table.freeze({ "bolt", "can", "gear", "washer", "nut", "screw", "nail", "chain", "lock", "spring", "battery", "circuit", "motor", "metalCrystal", "goldenCrown" })
local known: { [string]: boolean } = {}
for _, key in keys do known[key] = true end
table.freeze(known)
Rules.inventoryKeys = keys
Rules.version = 2
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
	local inventory: { [string]: number } = {}
	for _, key in keys do inventory[key] = 0 end
	return { coins = 0, inventory = inventory, magnetTier = 1, discovered = {} }
end
function Rules.clone(profile: Profile): Profile
	return { coins = profile.coins, inventory = table.clone(profile.inventory), magnetTier = profile.magnetTier,
		discovered = table.clone(profile.discovered) }
end
local function validateProfile(value: unknown, legacy: boolean): Profile?
	if typeof(value) ~= "table" then return nil end
	local raw = value :: { [any]: any }
	local allowed = if legacy then { coins = true, inventory = true, magnetTier = true }
		else { coins = true, inventory = true, magnetTier = true, discovered = true }
	if not exactKeys(raw, allowed) or not integer(raw.coins) or not integer(raw.magnetTier)
		or raw.magnetTier < 1 or raw.magnetTier > 3 or typeof(raw.inventory) ~= "table" then return nil end
	local inventory = raw.inventory :: { [any]: any }
	local inventoryKeys = if legacy then legacyKeys else keys
	local allowedInventory: { [string]: boolean } = {}
	for _, key in inventoryKeys do allowedInventory[key] = true end
	if not exactKeys(inventory, allowedInventory) then return nil end
	local profile = Rules.defaults()
	for _, key in inventoryKeys do
		if not integer(inventory[key]) then return nil end
		profile.inventory[key] = inventory[key]
	end
	if not legacy then
		if typeof(raw.discovered) ~= "table" then return nil end
		for id, discovered in raw.discovered :: { [any]: any } do
			if typeof(id) ~= "string" or not known[id] or discovered ~= true then return nil end
			profile.discovered[id] = true
		end
	end
	profile.coins = raw.coins
	profile.magnetTier = raw.magnetTier
	return profile
end
function Rules.validate(value: unknown): Profile?
	return validateProfile(value, false)
end
function Rules.decode(value: unknown): Record?
	if typeof(value) ~= "table" then return nil end
	local raw = value :: { [any]: any }
	if not exactKeys(raw, { version = true, data = true, lease = true }) or (raw.version ~= 1 and raw.version ~= 2) then return nil end
	local data = validateProfile(raw.data, raw.version == 1)
	if not data then return nil end
	local lease: Lease? = nil
	if raw.lease ~= nil then
		if typeof(raw.lease) ~= "table" then return nil end
		local lock = raw.lease :: { [any]: any }
		if not exactKeys(lock, { owner = true, expiresAt = true }) or typeof(lock.owner) ~= "string"
			or lock.owner == "" or not integer(lock.expiresAt) then return nil end
		lease = { owner = lock.owner, expiresAt = lock.expiresAt } :: Lease
	end
	return { version = 2, data = data, lease = lease }
end
local function validOperation(owner: string, now: number, duration: number): boolean
	return owner ~= "" and integer(now) and integer(duration) and duration > 0 and integer(now + duration)
end
function Rules.acquire(old: unknown, owner: string, now: number, duration: number): Record?
	if not validOperation(owner, now, duration) then return nil end
	local record: Record?
	if old == nil then record = { version = 2, data = Rules.defaults(), lease = nil } :: Record else record = Rules.decode(old) end
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
	return { version = 2, data = data, lease = if release then nil else { owner = owner, expiresAt = now + duration } }
end
return table.freeze(Rules)
