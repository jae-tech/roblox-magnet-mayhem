--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(ReplicatedStorage.Shared.CollectibleDefinitions)
local Config = require(ReplicatedStorage.Shared.MagnetConfig)

local World = {}

function World.create(): Folder
	-- Floor/spawn are serialized by Rojo, so characters cannot fall before startup.
	assert(workspace:FindFirstChild("PrototypeFloor"), "Rojo prototype floor missing")
	assert(workspace:FindFirstChild("PrototypeSpawn"), "Rojo prototype spawn missing")
	local existing = workspace:FindFirstChild(Config.collectiblesFolder)
	if existing then
		assert(existing:IsA("Folder"), "Collectibles must be a Folder")
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = Config.collectiblesFolder
	for objectId, definition in Definitions do
		local part = Instance.new("Part")
		part.Name = definition.name
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.Material = if definition.kind == "Coin" then Enum.Material.Neon else Enum.Material.Metal
		part.Color = Color3.fromRGB(definition.color[1], definition.color[2], definition.color[3])
		part.Size = Vector3.new(definition.size[1], definition.size[2], definition.size[3])
		part.Position = Vector3.new(definition.position[1], definition.position[2], definition.position[3])
		part.Shape = if definition.shape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
		part:SetAttribute("ObjectId", objectId)

		local hint = Instance.new("BillboardGui")
		hint.Name = "PickupHint"
		hint.Size = UDim2.fromOffset(170, 68)
		hint.StudsOffset = Vector3.new(0, 3, 0)
		hint.MaxDistance = 60
		hint.AlwaysOnTop = true
		hint.Parent = part
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
		text.BackgroundTransparency = 0.2
		text.TextColor3 = Color3.fromRGB(240, 245, 255)
		text.Font = Enum.Font.GothamBold
		text.TextSize = 14
		text.TextWrapped = true
		text.Parent = hint
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = text
		local currency = if definition.reward == 1 then "coin" else "coins"
		local route = if definition.kind == "Coin" then "+" .. tostring(definition.reward) .. " " .. currency .. " now"
			else "Sell: " .. tostring(definition.reward) .. " " .. currency .. " each"
		local function updateHint()
			text.Text = definition.name .. "\n"
				.. (if definition.kind == "Metal" then (definition.rarity or "Common") .. "\n" else "")
				.. (if part:GetAttribute("Available") == false then "Respawning..." else route)
		end
		part:GetAttributeChangedSignal("Available"):Connect(updateHint)
		updateHint()
		part.Parent = folder
	end
	folder.Parent = workspace
	return folder
end

return World
