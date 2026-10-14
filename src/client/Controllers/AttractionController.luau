--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.MagnetConfig)
local Definitions = require(ReplicatedStorage.Shared.CollectibleDefinitions)
local Upgrades = require(ReplicatedStorage.Shared.UpgradeDefinitions)
local Upgrade = require(ReplicatedStorage.Shared.UpgradeRules)

type Pending = { token: string, sentAt: number }
type Ghost = { part: Part, start: CFrame, startedAt: number, duration: number, character: Model }
local Attraction = {}

function Attraction.start()
	local player = Players.LocalPlayer
	local folder = workspace:WaitForChild(Config.collectiblesFolder)
	local remotes = ReplicatedStorage:WaitForChild(Config.remotesFolder)
	local request = remotes:WaitForChild(Config.requestRemote) :: RemoteEvent
	local result = remotes:WaitForChild(Config.resultRemote) :: RemoteEvent
	local pending: { [BasePart]: Pending } = {}
	local ghosts: { [string]: Ghost } = {}
	local lastScan = 0
	local radius = Upgrades.range.levels[1].value
	local power = Upgrades.power.levels[1].value
	local function updateStats()
		local range = Upgrade.definitionFor(Upgrades, "range", player:GetAttribute("Upgrade_range"))
		local force = Upgrade.definitionFor(Upgrades, "power", player:GetAttribute("Upgrade_power"))
		radius = if range then range.value else Upgrades.range.levels[1].value
		power = if force then force.value else Upgrades.power.levels[1].value
	end
	player:GetAttributeChangedSignal("Upgrade_range"):Connect(updateStats)
	player:GetAttributeChangedSignal("Upgrade_power"):Connect(updateStats)
	updateStats()

	local function getRoot(): BasePart?
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			return root
		end
		return nil
	end

	local function clear()
		table.clear(pending)
		for token, ghost in ghosts do
			ghost.part:Destroy()
			ghosts[token] = nil
		end
	end
	player.CharacterRemoving:Connect(clear)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("BasePart") then
			pending[child] = nil
		end
	end)

	result.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.lifecycleId) ~= "string"
			or typeof(payload.objectId) ~= "string" or typeof(payload.startCFrame) ~= "CFrame" then
			return
		end
		local definition = Definitions[payload.objectId]
		local root = getRoot()
		local character = player.Character
		if not definition or not root or not character or ghosts[payload.lifecycleId] then
			return
		end
		for target, entry in pending do
			if entry.token == payload.lifecycleId then
				pending[target] = nil
			end
		end
		-- Build a disposable presentation part: never clone/move the authoritative part.
		local ghost = Instance.new("Part")
		ghost.Name = "AttractionGhost"
		ghost.Anchored = true
		ghost.CanCollide = false
		ghost.CanTouch = false
		ghost.CanQuery = false
		ghost.Material = if definition.kind == "Coin" then Enum.Material.Neon else Enum.Material.Metal
		ghost.Size = Vector3.new(definition.size[1], definition.size[2], definition.size[3])
		ghost.Color = Color3.fromRGB(definition.color[1], definition.color[2], definition.color[3])
		ghost.Shape = if definition.shape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
		ghost.CFrame = payload.startCFrame
		ghost.Parent = workspace
		ghosts[payload.lifecycleId] = {
			part = ghost, start = payload.startCFrame, startedAt = os.clock(), character = character,
			duration = Config.animationDuration / power,
		}
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local root = getRoot()
		if not root or player:GetAttribute("DataReady") ~= true then
			clear()
			return
		end
		local destination = root.CFrame * CFrame.new(0, 0.1, -1.6)
		local prop = workspace:FindFirstChild("LocalMagnet")
		local handle = prop and prop:IsA("Model") and prop:FindFirstChild("Bridge")
		if handle and handle:IsA("BasePart") then destination = handle.CFrame end
		for token, ghost in ghosts do
			local progress = math.clamp((now - ghost.startedAt) / ghost.duration, 0, 1)
			if ghost.character ~= player.Character or not ghost.part.Parent or progress >= 1 then
				ghost.part:Destroy()
				ghosts[token] = nil
			else
				local eased = TweenService:GetValue(progress, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				ghost.part.CFrame = ghost.start:Lerp(destination, eased)
				ghost.part.Transparency = progress * 0.5
			end
		end
		if now - lastScan < Config.scanInterval / power then
			return
		end
		lastScan = now
		for target, entry in pending do
			if target.Parent ~= folder or target:GetAttribute("LifecycleId") ~= entry.token
				or target:GetAttribute("Available") ~= true or now - entry.sentAt >= Config.requestRetryDelay then
				pending[target] = nil
			end
		end
		for _, target in folder:GetChildren() do
			if not target:IsA("BasePart") or target:GetAttribute("Available") ~= true or pending[target] then
				continue
			end
			local token = target:GetAttribute("LifecycleId")
			if typeof(token) == "string" and (root.Position - target.Position).Magnitude <= radius then
				pending[target] = { token = token, sentAt = now }
				request:FireServer(target, token)
			end
		end
	end)
end

return Attraction
