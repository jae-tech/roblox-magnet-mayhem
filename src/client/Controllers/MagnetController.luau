--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Magnet = {}

function Magnet.start()
	local player = Players.LocalPlayer
	local model: Model? = nil
	local pieces: { { part: Part, offset: CFrame } } = {}
	local owner: Model? = nil

	local function clear()
		if model then
			model:Destroy()
		end
		model = nil
		owner = nil
		table.clear(pieces)
	end

	local function create(character: Model)
		local newModel = Instance.new("Model")
		newModel.Name = "LocalStarterMagnet"
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
		local red = Color3.fromRGB(230, 70, 70)
		local silver = Color3.fromRGB(205, 215, 225)
		piece(Vector3.new(1.4, 0.35, 0.35), CFrame.new(0, -0.6, 0), red)
		for _, side in { -1, 1 } do
			piece(Vector3.new(0.35, 1.2, 0.35), CFrame.new(side * 0.525, 0, 0), red)
			piece(Vector3.new(0.35, 0.35, 0.35), CFrame.new(side * 0.525, 0.6, 0), silver)
		end
		newModel.Parent = workspace
		model = newModel
		owner = character
	end

	-- One lifetime connection; the disposable model is replaced on character changes.
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
			clear()
			return
		end
		if owner ~= character then
			clear()
			create(character)
		end
		local base = root.CFrame * CFrame.new(1.8, 0.2, -1.2)
		for _, item in pieces do
			item.part.CFrame = base * item.offset
		end
	end)
end

return Magnet
