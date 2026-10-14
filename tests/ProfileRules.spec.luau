--!strict
local H = require("./TestHarness")
local Rules = require("../src/shared/ProfileRules")
local function profile(): Rules.Profile
	local p = Rules.defaults()
	p.coins, p.magnetTier = 125, 3
	p.inventory.bolt, p.inventory.can, p.inventory.gear = 2, 3, 4
	p.discovered.bolt = true
	return p
end
H.test("profile defaults independently initialize each player", function()
	local a, b = Rules.defaults(), Rules.defaults()
	a.inventory.bolt = 7
	H.equal(b.inventory.bolt, 0)
	H.equal(b.coins, 0)
	H.equal(b.magnetTier, 1)
end)
H.test("profile clone separates nested inventory", function()
	local original = profile()
	local clone = Rules.clone(original)
	clone.inventory.gear = 0
	H.equal(original.inventory.gear, 4)
end)
H.test("profile validates and copies complete saved progress", function()
	local original = profile()
	local decoded = Rules.validate(original)
	assert(decoded)
	H.equal(decoded.coins, 125)
	H.equal(decoded.magnetTier, 3)
	decoded.inventory.can = 0
	H.equal(original.inventory.can, 3)
end)
for _, value in { -1, 0.5, math.huge, 0 / 0, 9007199254740992 } do
	H.test("profile rejects unsafe coin/count " .. tostring(value), function()
		local p = profile()
		p.coins = value
		H.equal(Rules.validate(p), nil)
		p.coins = 0
		p.inventory.bolt = value
		H.equal(Rules.validate(p), nil)
	end)
end
for _, tier in { 0, 4, 1.5 } do
	H.test("profile rejects unsupported magnet tier " .. tostring(tier), function()
		local p = profile()
		p.magnetTier = tier
		H.equal(Rules.validate(p), nil)
	end)
end
H.test("profile rejects missing and unknown inventory or payload keys", function()
	local p: any = profile()
	p.inventory.bolt = nil
	H.equal(Rules.validate(p), nil)
	p.inventory.bolt = 0
	p.inventory.coin = 1
	H.equal(Rules.validate(p), nil)
	p.inventory.coin = nil
	p.reward = 999
	H.equal(Rules.validate(p), nil)
end)
H.test("profile rejects nonnumeric fields instead of defaulting", function()
	H.equal(Rules.validate({ coins = "125", inventory = { bolt = 0, can = 0, gear = 0 }, magnetTier = 1 }), nil)
	H.equal(Rules.validate(false), nil)
	H.equal(Rules.validate(nil), nil)
end)
H.test("acquire initializes only a truly absent record", function()
	local record = Rules.acquire(nil, "owner", 100, 180)
	assert(record and record.lease)
	H.equal(record.data.coins, 0)
	H.equal(record.lease.expiresAt, 280)
	H.equal(Rules.acquire({}, "owner", 100, 180), nil)
	H.equal(Rules.acquire({ version = 3, data = profile() }, "owner", 100, 180), nil)
end)
H.test("acquire resumes saved data without mutating stored record", function()
	local old = { version = 2, data = profile() }
	local result = Rules.acquire(old, "owner", 100, 180)
	assert(result)
	result.data.inventory.bolt = 0
	H.equal(old.data.inventory.bolt, 2)
	H.equal(result.data.coins, 125)
end)
H.test("acquire rejects another live owner and permits expired takeover", function()
	local old = { version = 2, data = profile(), lease = { owner = "old", expiresAt = 200 } }
	H.equal(Rules.acquire(old, "new", 199, 180), nil)
	local result = Rules.acquire(old, "new", 200, 180)
	assert(result and result.lease)
	H.equal(result.lease.owner, "new")
end)
H.test("acquire confirms ambiguous same-token retry but never resurrects expired token", function()
	local old = { version = 2, data = profile(), lease = { owner = "same", expiresAt = 200 } }
	assert(Rules.acquire(old, "same", 199, 180))
	H.equal(Rules.acquire(old, "same", 200, 180), nil)
end)
H.test("save requires exact live ownership including at expiry boundary", function()
	local old = { version = 2, data = profile(), lease = { owner = "owner", expiresAt = 200 } }
	H.equal(Rules.save(old, "other", profile(), 100, 180, false), nil)
	H.equal(Rules.save(old, "owner", profile(), 200, 180, false), nil)
	H.equal(Rules.save({ version = 2, data = profile() }, "owner", profile(), 100, 180, false), nil)
	H.equal(Rules.save(nil, "owner", profile(), 100, 180, false), nil)
end)
H.test("save copies snapshot and renews lease without mutating prior record", function()
	local old = { version = 2, data = profile(), lease = { owner = "owner", expiresAt = 200 } }
	local snapshot = profile()
	snapshot.coins = 321
	local saved = Rules.save(old, "owner", snapshot, 110, 180, false)
	assert(saved and saved.lease)
	H.equal(saved.data.coins, 321)
	H.equal(saved.lease.expiresAt, 290)
	H.equal(old.data.coins, 125)
	snapshot.inventory.bolt = 100
	H.equal(saved.data.inventory.bolt, 2)
end)
H.test("release stores progress and removes lease", function()
	local old = { version = 2, data = profile(), lease = { owner = "owner", expiresAt = 200 } }
	local saved = Rules.save(old, "owner", profile(), 110, 180, true)
	assert(saved)
	H.equal(saved.lease, nil)
	H.equal(saved.data.coins, 125)
	assert(Rules.acquire(saved, "next", 110, 180))
end)
H.test("malformed snapshots and lease records cancel writes", function()
	local old = { version = 2, data = profile(), lease = { owner = "owner", expiresAt = 200 } }
	local bad = profile()
	bad.inventory.gear = -1
	H.equal(Rules.save(old, "owner", bad, 110, 180, false), nil)
	H.equal(Rules.decode({ version = 2, data = profile(), lease = { owner = "", expiresAt = 200 } }), nil)
	H.equal(Rules.decode({ version = 2, data = profile(), lease = { owner = "owner", expiresAt = math.huge } }), nil)
	H.equal(Rules.decode({ version = 2, data = profile(), unexpected = true }), nil)
end)
H.test("invalid operation parameters reject all mutations", function()
	for _, args in { { "", 100, 180 }, { "owner", -1, 180 }, { "owner", 100, 0 }, { "owner", 100, 0.5 } } do
		H.equal(Rules.acquire(nil, args[1] :: string, args[2] :: number, args[3] :: number), nil)
	end
end)
H.test("version one migrates progress and lease without inventing discoveries", function()
	local old = { version = 1, data = { coins = 125, inventory = { bolt = 2, can = 3, gear = 4 }, magnetTier = 3 }, lease = { owner = "owner", expiresAt = 200 } }
	local decoded = Rules.decode(old)
	assert(decoded and decoded.lease)
	H.equal(decoded.version, 2)
	H.equal(decoded.data.coins, 125)
	H.equal(decoded.data.magnetTier, 3)
	H.equal(decoded.data.inventory.gear, 4)
	H.equal(decoded.lease.owner, "owner")
	H.equal(decoded.lease.expiresAt, 200)
	H.equal(next(decoded.data.discovered), nil)
	for _, id in Rules.inventoryKeys do
		H.equal(decoded.data.inventory[id], old.data.inventory[id] or 0)
	end
	decoded.data.inventory.bolt = 9
	H.equal(old.data.inventory.bolt, 2)
	local acquired = Rules.acquire(old, "owner", 100, 180)
	assert(acquired)
	H.equal(acquired.version, 2)
end)
H.test("malformed version one does not migrate or default", function()
	local old: any = { version = 1, data = { coins = 1, inventory = { bolt = 0, can = 0 }, magnetTier = 1 } }
	H.equal(Rules.decode(old), nil)
	old.data.inventory.gear = -1
	H.equal(Rules.decode(old), nil)
	old.data.inventory.gear = 0
	old.data.discovered = {}
	H.equal(Rules.decode(old), nil)
	H.equal(Rules.decode({ version = 3, data = profile() }), nil)
end)
H.test("version two discovery is required sparse known true-only map", function()
	local p: any = profile()
	p.discovered = nil
	H.equal(Rules.validate(p), nil)
	for _, invalid in { { bolt = false }, { bolt = 1 }, { coin = true }, { unknown = true }, { [1] = true } } do
		p.discovered = invalid
		H.equal(Rules.validate(p), nil)
	end
	p.discovered = {}
	assert(Rules.validate(p))
end)
H.test("defaults clones decode and saves separate discovery maps", function()
	local a, b = Rules.defaults(), Rules.defaults()
	a.discovered.bolt = true
	H.equal(b.discovered.bolt, nil)
	local clone = Rules.clone(a)
	clone.discovered.can = true
	H.equal(a.discovered.can, nil)
	local validated = Rules.validate(a)
	assert(validated)
	validated.discovered.gear = true
	H.equal(a.discovered.gear, nil)
	local old = { version = 2, data = a, lease = { owner = "owner", expiresAt = 200 } }
	local saved = Rules.save(old, "owner", a, 100, 180, true)
	assert(saved)
	saved.data.discovered.can = true
	H.equal(a.discovered.can, nil)
end)
H.test("profile inventory schema exactly covers the collection book catalog", function()
	local Book = require("../src/shared/CollectionBookRules")
	local defaults = Rules.defaults()
	H.equal(#Rules.inventoryKeys, #Book.orderedIds)
	H.equal(#Rules.inventoryKeys, 15)
	local count = 0
	for _, id in Book.orderedIds do H.equal(defaults.inventory[id], 0) end
	for _ in defaults.inventory do count += 1 end
	H.equal(count, 15)
end)
return true
