--!strict

local Players = game:GetService("Players")
local Hud = {}

function Hud.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("MagnetMayhemHUD")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MagnetMayhemHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	local label = Instance.new("TextLabel")
	label.Name = "Coins"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 12)
	label.Size = UDim2.new(0.75, 0, 0, 72)
	label.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	label.BackgroundTransparency = 0.15
	label.TextColor3 = Color3.fromRGB(255, 225, 120)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui
	local size = Instance.new("UISizeConstraint")
	size.MaxSize = Vector2.new(420, 72)
	size.Parent = label
	local textSize = Instance.new("UITextSizeConstraint")
	textSize.MinTextSize = 12
	textSize.MaxTextSize = 22
	textSize.Parent = label
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	local function update()
		local coins = player:GetAttribute("Coins")
		label.Text = "Coins: " .. tostring(if typeof(coins) == "number" then coins else 0)
			.. "\nWalk near metal to collect"
	end
	-- Subscribe before initial read so a replication update cannot be missed.
	player:GetAttributeChangedSignal("Coins"):Connect(update)
	update()
	gui.Parent = playerGui
end

return Hud
