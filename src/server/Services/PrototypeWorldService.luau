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
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(definition.color[1], definition.color[2], definition.color[3])
		part.Size = Vector3.new(definition.size[1], definition.size[2], definition.size[3])
		part.Position = Vector3.new(definition.position[1], definition.position[2], definition.position[3])
		part.Shape = if definition.shape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
		part:SetAttribute("ObjectId", objectId)
		part.Parent = folder
	end
	folder.Parent = workspace
	return folder
end

return World
