--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Definitions = require(ReplicatedStorage.Shared.CollectibleDefinitions)
local Config = require(ReplicatedStorage.Shared.MagnetConfig)
local Rules = require(ReplicatedStorage.Shared.CollectionRules)
local PlayerState = require(script.Parent.PlayerStateService)

type Entry = {
	objectId: string, lifecycleId: string, available: boolean, spawnCFrame: CFrame,
}

local Collectibles = {}

local function getRemote(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing then
		assert(existing:IsA("RemoteEvent"), name .. " must be a RemoteEvent")
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

function Collectibles.start(folder: Folder)
	local existing = ReplicatedStorage:FindFirstChild(Config.remotesFolder)
	if existing then
		assert(existing:IsA("Folder"), "Remotes must be a Folder")
	end
	local remotes = if existing then existing :: Folder else Instance.new("Folder")
	remotes.Name = Config.remotesFolder
	remotes.Parent = ReplicatedStorage
	local request = getRemote(remotes, Config.requestRemote)
	local resultRemote = getRemote(remotes, Config.resultRemote)
	local registry: { [Instance]: Entry } = {}
	local buckets: { [Player]: Rules.Bucket } = {}

	for _, part in folder:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		local objectId = part:GetAttribute("ObjectId")
		assert(typeof(objectId) == "string" and Rules.rewardFor(Definitions, objectId), "Unknown collectible")
		local entry: Entry = {
			objectId = objectId, lifecycleId = HttpService:GenerateGUID(false),
			available = true, spawnCFrame = part.CFrame,
		}
		registry[part] = entry
		part:SetAttribute("LifecycleId", entry.lifecycleId)
		part:SetAttribute("Available", true)
	end

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
	folder.ChildRemoved:Connect(function(part)
		registry[part] = nil
	end)

	request.OnServerEvent:Connect(function(player: Player, target: unknown, token: unknown)
		if not PlayerState.has(player) then
			return
		end
		local now = os.clock()
		local bucket = buckets[player]
		if not bucket then
			bucket = { tokens = Config.requestBurst, updatedAt = now }
			buckets[player] = bucket
		end
		if not Rules.consumeRequest(bucket, now, Config.requestsPerSecond, Config.requestBurst) then
			return
		end
		if typeof(target) ~= "Instance" or typeof(token) ~= "string"
			or #token == 0 or #token > Config.maxLifecycleLength then
			return
		end
		if not target:IsA("BasePart") or target.Parent ~= folder then
			return
		end
		local entry = registry[target]
		if not entry then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			return
		end
		-- Anchored targets cannot be repositioned by clients. Use the server-owned spawn.
		local claim = Rules.claim(Definitions, entry, token, {
			validCharacter = true,
			distance = (root.Position - entry.spawnCFrame.Position).Magnitude,
		}, Config.attractionRadius, Config.distanceTolerance)
		if not claim.accepted then
			return
		end

		-- No yielding from validation through claim and award. Only one handler can win.
		PlayerState.award(player, claim.reward)
		target:SetAttribute("Available", false)
		target.Transparency = 1
		target.CanQuery = false
		resultRemote:FireClient(player, {
			lifecycleId = entry.lifecycleId,
			objectId = entry.objectId,
			startCFrame = entry.spawnCFrame,
		})
		task.delay(Config.respawnDelay, function()
			if registry[target] ~= entry or target.Parent ~= folder then
				return
			end
			entry.lifecycleId = HttpService:GenerateGUID(false)
			target.CFrame = entry.spawnCFrame
			target:SetAttribute("LifecycleId", entry.lifecycleId)
			target.Transparency = 0
			target.CanQuery = true
			entry.available = true
			target:SetAttribute("Available", true)
		end)
	end)
end

return Collectibles
