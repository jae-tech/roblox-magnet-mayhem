--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Magnets = require(ReplicatedStorage.Shared.MagnetDefinitions)
local Shop = require(ReplicatedStorage.Shared.ShopRules)

local Magnet = {}

function Magnet.start()
	local player = Players.LocalPlayer
	local model: Model? = nil
	local pieces: { { part: Part, offset: CFrame } } = {}
	local owner: Model? = nil
	local equippedTier = 0

	local function clear()
		if model then
			model:Destroy()
		end
		model = nil
		owner = nil
		equippedTier = 0
		table.clear(pieces)
	end

	local function create(character: Model, definition: Magnets.Definition)
		local newModel = Instance.new("Model")
		newModel.Name = "LocalMagnet"
		local function piece(size: Vector3, offset: CFrame, color: Color3)
			local part = Instance.new("Part")
			part.Size = size
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Material = Enum.Material.Metal
			part.Color = color
			part.Parent = newModel
			table.insert(pieces, { part = part, offset = offset })
		end
		local bodyColor = Color3.fromRGB(definition.color[1], definition.color[2], definition.color[3])
		local silver = Color3.fromRGB(205, 215, 225)
		piece(Vector3.new(1.4, 0.35, 0.35), CFrame.new(0, -0.6, 0), bodyColor)
		for _, side in { -1, 1 } do
			piece(Vector3.new(0.35, 1.2, 0.35), CFrame.new(side * 0.525, 0, 0), bodyColor)
			piece(Vector3.new(0.35, 0.35, 0.35), CFrame.new(side * 0.525, 0.6, 0), silver)
		end
		newModel.Parent = workspace
		model = newModel
		owner = character
		equippedTier = definition.tier
	end

	-- One lifetime connection; the disposable model is replaced on character changes.
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if player:GetAttribute("DataReady") ~= true or not character or not root or not root:IsA("BasePart")
			or not humanoid or humanoid.Health <= 0 then
			clear()
			return
		end
		local definition = Shop.definitionFor(Magnets, player:GetAttribute("MagnetTier")) or Magnets[1]
		if owner ~= character or equippedTier ~= definition.tier then
			clear()
			create(character, definition)
		end
		local base = root.CFrame * CFrame.new(1.8, 0.2, -1.2)
		for _, item in pieces do
			item.part.CFrame = base * item.offset
		end
	end)
end

return Magnet
