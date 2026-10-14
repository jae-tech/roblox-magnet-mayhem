--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Profiles = require(ReplicatedStorage.Shared.ProfileRules)
local Config = require(script.Parent.PersistenceConfig)
local State = require(script.Parent.PlayerStateService)

type Runtime = {
	player: Player, token: string, key: string, closing: boolean, loading: boolean,
	saving: boolean, closed: boolean, acquired: boolean, failed: boolean,
	leaseDeadline: number, savedRevision: number, nextSave: number,
	closeDeadline: number?,
}
local runtimes: { [Player]: Runtime } = {}
local userOwners: { [string]: Runtime } = {}
local store: GlobalDataStore? = nil
local preview = false
local shutdown = false
local Service = {}

local function fail(runtime: Runtime, message: string)
	runtime.failed = true
	State.freeze(runtime.player)
	runtime.player:SetAttribute("DataStatus", "Error")
	warn("Magnet Mayhem storage: " .. message)
	if runtime.player.Parent == Players then
		runtime.player:Kick("Your data could not be safely loaded or saved. Please rejoin. " .. message)
	end
end

-- A callback can run repeatedly. Only pure record transforms happen inside it.
local function update(runtime: Runtime, acquiring: boolean, snapshot: Profiles.Profile?, release: boolean, deadline: number): (Profiles.Record?, boolean)
	local backend = store
	if not backend then return nil, false end
	local attempts = if acquiring then Config.loadAttempts else Config.saveAttempts
	for attempt = 1, attempts do
		if os.clock() >= deadline then return nil, false end
		if acquiring and (runtime.closing or shutdown) then return nil, false end
		local ok, result = pcall(function()
			return backend:UpdateAsync(runtime.key, function(old: unknown, keyInfo: DataStoreKeyInfo?)
				if os.clock() >= deadline or (acquiring and (runtime.closing or shutdown)) then return nil end
				if not acquiring and not release and (runtime.closing or runtime.failed or os.clock() >= runtime.leaseDeadline) then return nil end
				local now = os.time()
				local record: Profiles.Record?
				if acquiring then
					record = Profiles.acquire(old, runtime.token, now, Config.leaseSeconds)
				else
					if not snapshot then return nil end
					record = Profiles.save(old, runtime.token, snapshot, now, Config.leaseSeconds, release)
				end
				if not record then return nil end
				local userIds = if keyInfo then keyInfo:GetUserIds() else { runtime.player.UserId }
				local metadata = if keyInfo then keyInfo:GetMetadata() else {}
				return record, userIds, metadata
			end)
		end)
		if ok then
			-- nil is a deliberate CAS cancellation, not a transient exception.
			return Profiles.decode(result), result == nil
		end
		warn("Magnet Mayhem storage request failed: " .. tostring(result))
		if attempt < attempts then
			local delaySeconds = math.min(attempt, 2)
			if os.clock() + delaySeconds >= deadline then return nil, false end
			task.wait(delaySeconds)
		end
	end
	return nil, false
end

local function operationDeadline(runtime: Runtime): number
	return math.min(os.clock() + Config.operationDeadlineSeconds, runtime.closeDeadline or math.huge)
end

local function save(runtime: Runtime, release: boolean): boolean
	if runtime.saving or not runtime.acquired then return false end
	if not release and (runtime.closing or runtime.failed or not State.has(runtime.player)) then return false end
	local snapshot, revision = State.snapshot(runtime.player)
	if not snapshot or revision == nil then return false end
	runtime.saving = true
	if not release then State.setDataStatus(runtime.player, "Saving") end
	local record, rejected = update(runtime, false, snapshot, release, operationDeadline(runtime))
	runtime.saving = false
	if runtime.closed and userOwners[runtime.key] == runtime then userOwners[runtime.key] = nil end
	if not record then
		if rejected and not release and not runtime.closing then
			fail(runtime, "Storage ownership could not be confirmed.")
		end
		if not release and not runtime.closing and not runtime.failed then
			State.setDataStatus(runtime.player, "SaveDelayed")
		end
		return false
	end
	runtime.savedRevision = revision
	if release then
		runtime.acquired = false
		return true
	end
	-- Never revive a locally expired/frozen session after an API yield.
	if runtime.closing or runtime.failed then return true end
	local lease = record.lease
	local deadline = if lease then os.clock() + math.max(0, lease.expiresAt - os.time() - Config.leaseSafetyMargin) else 0
	if not State.renewLease(runtime.player, deadline) then
		fail(runtime, "The storage session lease expired.")
		return false
	end
	runtime.leaseDeadline = deadline
	local _, currentRevision = State.snapshot(runtime.player)
	State.setDataStatus(runtime.player, if currentRevision == revision then "Saved" else "Dirty")
	return true
end

local function close(runtime: Runtime)
	if runtime.closing then return end
	runtime.closing = true
	runtime.closeDeadline = os.clock() + Config.closeDeadlineSeconds
	State.freeze(runtime.player)
	while (runtime.loading or runtime.saving) and os.clock() < (runtime.closeDeadline :: number) do task.wait(0.05) end
	if runtime.acquired and not runtime.loading and not runtime.saving then
		if not save(runtime, true) then warn("Magnet Mayhem: final save not confirmed for " .. runtime.key) end
	end
	State.remove(runtime.player)
	runtime.closed = true
	if runtimes[runtime.player] == runtime then runtimes[runtime.player] = nil end
	if not runtime.loading and not runtime.saving and userOwners[runtime.key] == runtime then userOwners[runtime.key] = nil end
end

local function load(player: Player)
	if shutdown or runtimes[player] then return end
	player:SetAttribute("DataReady", false)
	player:SetAttribute("StorageMode", if preview then "Preview" else "Persistent")
	player:SetAttribute("DataStatus", "Loading")
	local runtime: Runtime = {
		player = player, token = HttpService:GenerateGUID(false), key = tostring(player.UserId),
		closing = false, loading = true, saving = false, closed = false, acquired = false,
		failed = false, leaseDeadline = 0, savedRevision = 0,
		nextSave = os.clock() + Config.autosaveSeconds + (math.abs(player.UserId) % 15),
	}
	if userOwners[runtime.key] then
		runtime.loading = false
		fail(runtime, "An earlier session is still closing on this server.")
		return
	end
	runtimes[player] = runtime
	userOwners[runtime.key] = runtime
	if preview then
		runtime.loading = false
		if player.Parent == Players and not runtime.closing then
			State.add(player, Profiles.defaults(), { mode = "Preview" })
		end
		return
	end
	if not store then
		runtime.loading = false
		fail(runtime, "Storage initialization failed.")
		return
	end
	local record = update(runtime, true, nil, false, operationDeadline(runtime))
	runtime.loading = false
	if not record or not record.lease or record.lease.owner ~= runtime.token then
		if not runtime.closing then fail(runtime, "Load failed, data is invalid, or another session owns this profile.") end
		if runtime.closed and userOwners[runtime.key] == runtime then userOwners[runtime.key] = nil end
		return
	end
	runtime.acquired = true
	runtime.leaseDeadline = os.clock() + math.max(0, record.lease.expiresAt - os.time() - Config.leaseSafetyMargin)
	if runtime.closing or shutdown or player.Parent ~= Players or runtimes[player] ~= runtime then
		-- An orphan acquisition may release only its own saved payload and token.
		-- Retain local ownership while this cleanup request yields, even after close times out.
		runtime.saving = true
		update(runtime, false, record.data, true, operationDeadline(runtime))
		runtime.saving = false
		runtime.acquired = false
		if runtime.closed and userOwners[runtime.key] == runtime then userOwners[runtime.key] = nil end
		return
	end
	if runtime.leaseDeadline <= os.clock() then fail(runtime, "Loaded lease already expired."); return end
	State.add(player, record.data, { mode = "Persistent", leaseDeadline = runtime.leaseDeadline })
end

function Service.start()
	-- Decide Preview before touching DataStoreService; API-disabled Studio is safe.
	preview = RunService:IsStudio() and not Config.allowStudioDataStore
	if not preview then
		local ok, backend = pcall(function()
			local dataStores = game:GetService("DataStoreService")
			return dataStores:GetDataStore(if RunService:IsStudio() then Config.studioStore else Config.productionStore)
		end)
		if ok then store = backend else warn("Magnet Mayhem storage initialization: " .. tostring(backend)) end
	end
	Players.PlayerAdded:Connect(function(player) task.spawn(load, player) end)
	Players.PlayerRemoving:Connect(function(player)
		local runtime = runtimes[player]
		if runtime then close(runtime) else State.remove(player) end
	end)
	for _, player in Players:GetPlayers() do task.spawn(load, player) end
	task.spawn(function()
		while not shutdown do
			task.wait(1)
			for _, runtime in runtimes do
				if not preview and not runtime.loading and not runtime.closing and not runtime.failed then
					if os.clock() >= runtime.leaseDeadline or not State.has(runtime.player) then
						fail(runtime, "The storage session lease expired.")
					elseif not runtime.saving and os.clock() >= runtime.nextSave then
						runtime.nextSave = os.clock() + Config.autosaveSeconds
						task.spawn(save, runtime, false)
					end
				end
			end
		end
	end)
	game:BindToClose(function()
		shutdown = true
		local deadline = os.clock() + Config.closeDeadlineSeconds
		local closing = {}
		for _, runtime in runtimes do
			table.insert(closing, runtime)
			-- Freeze synchronously before spawning any I/O.
			State.freeze(runtime.player)
			task.spawn(close, runtime)
		end
		while os.clock() < deadline do
			local pending = false
			for _, runtime in closing do if not runtime.closed then pending = true; break end end
			if not pending then break end
			task.wait(0.05)
		end
	end)
end
return Service
