--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(ReplicatedStorage.Shared.CollectibleDefinitions)
local Inventory = require(ReplicatedStorage.Shared.InventoryRules)
local Config = require(ReplicatedStorage.Shared.MagnetConfig)
local Magnets = require(ReplicatedStorage.Shared.MagnetDefinitions)
local Book = require(ReplicatedStorage.Shared.CollectionBookRules)
local Upgrades = require(ReplicatedStorage.Shared.UpgradeDefinitions)
local Upgrade = require(ReplicatedStorage.Shared.UpgradeRules)
local Hud = {}

function Hud.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild(Config.remotesFolder)
	local sellRemote = remotes:WaitForChild(Config.sellRemote) :: RemoteEvent
	local collectionResult = remotes:WaitForChild(Config.resultRemote) :: RemoteEvent
	local saleResult = remotes:WaitForChild(Config.sellResultRemote) :: RemoteEvent
	local buyRemote = remotes:WaitForChild(Config.buyRemote) :: RemoteEvent
	local shopResult = remotes:WaitForChild(Config.buyResultRemote) :: RemoteEvent
	local bookResult = remotes:WaitForChild(Config.bookResultRemote) :: RemoteEvent
	local upgradeRemote = remotes:WaitForChild(Config.upgradeRemote) :: RemoteEvent
	local upgradeResult = remotes:WaitForChild(Config.upgradeResultRemote) :: RemoteEvent
	local old = playerGui:FindFirstChild("MagnetMayhemHUD")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MagnetMayhemHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	local alive = true
	local connections: { RBXScriptConnection } = {}
	local label = Instance.new("TextLabel")
	label.Name = "Coins"
	label.AnchorPoint = Vector2.new(0.5, 0)
	-- Reserve a 106px right dock and 12px gutters, including on short viewports.
	label.Position = UDim2.new(0.5, -59, 0, 12)
	label.Size = UDim2.new(1, -142, 0, 72)
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

	local navigation = Instance.new("Frame")
	navigation.Name = "Navigation"
	navigation.AnchorPoint = Vector2.new(0.5, 0)
	navigation.Position = UDim2.new(0.5, -59, 0, 90)
	navigation.Size = UDim2.new(1, -142, 0, 40)
	navigation.BackgroundTransparency = 1
	navigation.Parent = gui
	local navigationSize = Instance.new("UISizeConstraint")
	navigationSize.MaxSize = Vector2.new(420, 40)
	navigationSize.Parent = navigation
	local button = Instance.new("TextButton")
	button.Name = "InventoryToggle"
	button.Size = UDim2.new(1 / 3, -6, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(40, 65, 90)
	button.TextColor3 = Color3.fromRGB(240, 245, 255)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.TextWrapped = true
	button.Active = true
	button.Selectable = true
	button.Parent = navigation
	local buttonTextSize = Instance.new("UITextSizeConstraint")
	buttonTextSize.MinTextSize = 12
	buttonTextSize.MaxTextSize = 20
	buttonTextSize.Parent = button
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 10)
	buttonCorner.Parent = button
	local shopButton = Instance.new("TextButton")
	shopButton.Name = "ShopToggle"
	shopButton.Position = UDim2.new(1 / 3, 3, 0, 0)
	shopButton.Size = UDim2.new(1 / 3, -6, 1, 0)
	shopButton.BackgroundColor3 = Color3.fromRGB(90, 65, 35)
	shopButton.TextColor3 = Color3.fromRGB(255, 235, 175)
	shopButton.Font = Enum.Font.GothamBold
	shopButton.TextScaled = true
	shopButton.TextWrapped = true
	shopButton.Active = true
	shopButton.Selectable = true
	shopButton.Parent = navigation
	local shopTextSize = Instance.new("UITextSizeConstraint")
	shopTextSize.MinTextSize = 12
	shopTextSize.MaxTextSize = 20
	shopTextSize.Parent = shopButton
	local shopCorner = Instance.new("UICorner")
	shopCorner.CornerRadius = UDim.new(0, 10)
	shopCorner.Parent = shopButton
	local bookButton = Instance.new("TextButton")
	bookButton.Name = "BookToggle"
	bookButton.Position = UDim2.new(2 / 3, 6, 0, 0)
	bookButton.Size = UDim2.new(1 / 3, -6, 1, 0)
	bookButton.BackgroundColor3 = Color3.fromRGB(65, 45, 90)
	bookButton.TextColor3 = Color3.fromRGB(235, 220, 255)
	bookButton.Font = Enum.Font.GothamBold
	bookButton.TextScaled = true
	bookButton.TextWrapped = true
	bookButton.Active = true
	bookButton.Selectable = true
	bookButton.Parent = navigation
	local bookTextSize = Instance.new("UITextSizeConstraint")
	bookTextSize.MinTextSize = 12
	bookTextSize.MaxTextSize = 20
	bookTextSize.Parent = bookButton
	local bookCorner = Instance.new("UICorner")
	bookCorner.CornerRadius = UDim.new(0, 10)
	bookCorner.Parent = bookButton

	local upgradeDock = Instance.new("Frame")
	upgradeDock.Name = "UpgradeDock"
	upgradeDock.AnchorPoint = Vector2.new(1, 0.5)
	upgradeDock.Position = UDim2.new(1, -12, 0.5, 0)
	upgradeDock.Size = UDim2.fromOffset(106, 280)
	upgradeDock.BackgroundTransparency = 1
	upgradeDock.Parent = gui
	local upgradeLayout = Instance.new("UIListLayout")
	upgradeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	upgradeLayout.Padding = UDim.new(0, 8)
	upgradeLayout.Parent = upgradeDock
	local upgradeButtons: { [string]: TextButton } = {}
	local upgradeLabels: { [string]: { name: TextLabel, value: TextLabel, price: TextLabel } } = {}
	local upgradeColors: { [string]: Color3 } = {
		range = Color3.fromRGB(90, 180, 245), power = Color3.fromRGB(245, 100, 100),
		speed = Color3.fromRGB(110, 225, 150),
	}
	for index, upgradeId in Upgrade.orderedIds do
		local upgradeButton = Instance.new("TextButton")
		upgradeButton.Name = "Upgrade_" .. upgradeId
		upgradeButton.Size = UDim2.new(1, 0, 0, 88)
		upgradeButton.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
		upgradeButton.BorderSizePixel = 0
		upgradeButton.Text = ""
		upgradeButton.LayoutOrder = index
		upgradeButton.Parent = upgradeDock
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, 10)
		round.Parent = upgradeButton
		local icon = Instance.new("Frame")
		icon.Name = "Icon"
		icon.Position = UDim2.fromOffset(8, 8)
		icon.Size = UDim2.fromOffset(24, 24)
		icon.BackgroundTransparency = 1
		icon.Parent = upgradeButton
		local function iconPart(x: number, y: number, width: number, height: number, color: Color3, circular: boolean)
			local part = Instance.new("Frame")
			part.Position = UDim2.fromOffset(x, y)
			part.Size = UDim2.fromOffset(width, height)
			part.BackgroundColor3 = color
			part.BorderSizePixel = 0
			part.Parent = icon
			if circular then
				local curve = Instance.new("UICorner")
				curve.CornerRadius = UDim.new(1, 0)
				curve.Parent = part
			end
		end
		local color = upgradeColors[upgradeId]
		if upgradeId == "range" then
			iconPart(0, 0, 24, 24, color, true)
			iconPart(3, 3, 18, 18, Color3.fromRGB(35, 45, 60), true)
			iconPart(8, 8, 8, 8, color, true)
		elseif upgradeId == "power" then
			iconPart(2, 1, 5, 17, color, false)
			iconPart(17, 1, 5, 17, color, false)
			iconPart(2, 13, 20, 5, color, false)
		else
			local chevrons = Instance.new("TextLabel")
			chevrons.Size = UDim2.fromScale(1, 1)
			chevrons.BackgroundTransparency = 1
			chevrons.Text = ">>"
			chevrons.TextColor3 = color
			chevrons.Font = Enum.Font.GothamBold
			chevrons.TextSize = 22
			chevrons.Parent = icon
		end
		local function dockLabel(name: string, x: number, y: number, width: number, height: number, font: Enum.Font, textSize: number): TextLabel
			local text = Instance.new("TextLabel")
			text.Name = name
			text.Position = UDim2.fromOffset(x, y)
			text.Size = UDim2.fromOffset(width, height)
			text.BackgroundTransparency = 1
			text.TextColor3 = Color3.fromRGB(235, 245, 255)
			text.Font = font
			text.TextSize = textSize
			text.TextWrapped = true
			text.Parent = upgradeButton
			return text
		end
		upgradeLabels[upgradeId] = {
			name = dockLabel("Level", 36, 5, 64, 30, Enum.Font.GothamBold, 12),
			value = dockLabel("Value", 6, 36, 94, 20, Enum.Font.Gotham, 11),
			price = dockLabel("Price", 4, 59, 98, 25, Enum.Font.GothamBold, 12),
		}
		upgradeButtons[upgradeId] = upgradeButton
	end

	-- Fill the remaining safe viewport; scroll instead of clipping on short screens.
	local function createPanel(name: string): ScrollingFrame
		local panel = Instance.new("ScrollingFrame")
		panel.Name = name
		panel.AnchorPoint = Vector2.new(0.5, 0)
		panel.Position = UDim2.new(0.5, -59, 0, 140)
		panel.Size = UDim2.new(1, -142, 1, -152)
		panel.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
		panel.BackgroundTransparency = 0.1
		panel.BorderSizePixel = 0
		panel.CanvasSize = UDim2.fromOffset(0, 0)
		panel.AutomaticCanvasSize = Enum.AutomaticSize.None
		panel.ScrollingDirection = Enum.ScrollingDirection.Y
		panel.ScrollingEnabled = true
		panel.Active = true
		panel.ScrollBarThickness = 4
		panel.Visible = false
		panel.Parent = gui
		local panelSize = Instance.new("UISizeConstraint")
		panelSize.MaxSize = Vector2.new(420, 280)
		panelSize.Parent = panel
		local panelCorner = Instance.new("UICorner")
		panelCorner.CornerRadius = UDim.new(0, 10)
		panelCorner.Parent = panel
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 12)
		padding.PaddingBottom = UDim.new(0, 12)
		padding.PaddingLeft = UDim.new(0, 12)
		padding.PaddingRight = UDim.new(0, 12)
		padding.Parent = panel
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		layout.Parent = panel
		-- Use the real list extent, not automatic sizing of a constrained viewport.
		local function updateCanvas()
			if not alive or not panel.Visible then return end
			local height = math.ceil(layout.AbsoluteContentSize.Y + padding.PaddingTop.Offset + padding.PaddingBottom.Offset)
			panel.CanvasSize = UDim2.fromOffset(0, height)
			local maxScroll = math.max(0, height - panel.AbsoluteWindowSize.Y)
			panel.CanvasPosition = Vector2.new(0, math.clamp(panel.CanvasPosition.Y, 0, maxScroll))
		end
		table.insert(connections, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas))
		table.insert(connections, panel:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateCanvas))
		table.insert(connections, panel:GetPropertyChangedSignal("Visible"):Connect(updateCanvas))
		updateCanvas()
		return panel
	end
	local panel = createPanel("Inventory")
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 28)
	title.BackgroundTransparency = 1
	title.Text = "Inventory"
	title.TextColor3 = Color3.fromRGB(240, 245, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.LayoutOrder = 0
	title.Parent = panel
	local rows: { [string]: TextLabel } = {}
	for index, objectId in Book.orderedIds do
		local definition = Definitions[objectId]
		local row = Instance.new("TextLabel")
		row.Name = objectId
		row.Size = UDim2.new(1, 0, 0, 34)
		row.BackgroundTransparency = 1
		row.TextColor3 = Color3.fromRGB(definition.color[1], definition.color[2], definition.color[3])
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 18
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.LayoutOrder = index + 2
		row.Parent = panel
		rows[objectId] = row
	end
	local sellButton = Instance.new("TextButton")
	sellButton.Name = "SellAll"
	sellButton.Size = UDim2.new(1, 0, 0, 42)
	sellButton.Font = Enum.Font.GothamBold
	sellButton.TextColor3 = Color3.fromRGB(240, 255, 240)
	sellButton.TextScaled = true
	sellButton.LayoutOrder = 1
	sellButton.Parent = panel
	local sellCorner = Instance.new("UICorner")
	sellCorner.CornerRadius = UDim.new(0, 8)
	sellCorner.Parent = sellButton
	local sellTextSize = Instance.new("UITextSizeConstraint")
	sellTextSize.MinTextSize = 12
	sellTextSize.MaxTextSize = 18
	sellTextSize.Parent = sellButton
	local note = Instance.new("TextLabel")
	note.Name = "SessionNote"
	note.Size = UDim2.new(1, 0, 0, 32)
	note.BackgroundTransparency = 1
	note.Text = "Loading saved progress..."
	note.TextColor3 = Color3.fromRGB(170, 185, 205)
	note.Font = Enum.Font.Gotham
	note.TextSize = 12
	note.TextWrapped = true
	note.LayoutOrder = 100
	note.Parent = panel

	local shopPanel = createPanel("Shop")
	local shopTitle = Instance.new("TextLabel")
	shopTitle.Name = "Title"
	shopTitle.Size = UDim2.new(1, 0, 0, 28)
	shopTitle.BackgroundTransparency = 1
	shopTitle.Text = "Magnet Looks"
	shopTitle.TextColor3 = Color3.fromRGB(255, 235, 175)
	shopTitle.Font = Enum.Font.GothamBold
	shopTitle.TextSize = 20
	shopTitle.TextXAlignment = Enum.TextXAlignment.Left
	shopTitle.LayoutOrder = 0
	shopTitle.Parent = shopPanel
	local currentMagnet = Instance.new("TextLabel")
	currentMagnet.Name = "CurrentMagnet"
	currentMagnet.Size = UDim2.new(1, 0, 0, 36)
	currentMagnet.BackgroundTransparency = 1
	currentMagnet.TextColor3 = Color3.fromRGB(220, 230, 240)
	currentMagnet.Font = Enum.Font.Gotham
	currentMagnet.TextSize = 14
	currentMagnet.TextWrapped = true
	currentMagnet.TextXAlignment = Enum.TextXAlignment.Left
	currentMagnet.LayoutOrder = 1
	currentMagnet.Parent = shopPanel
	local buyButtons: { [number]: TextButton } = {}
	for tier, definition in Magnets do
		local description = Instance.new("TextLabel")
		description.Name = "Magnet" .. tostring(tier)
		description.Size = UDim2.new(1, 0, 0, 38)
		description.BackgroundTransparency = 1
		description.Text = definition.name .. " | Appearance only\n"
			.. (if tier == 1 then "Free starter" else tostring(definition.price) .. " coins")
		description.TextColor3 = Color3.fromRGB(definition.color[1], definition.color[2], definition.color[3])
		description.Font = Enum.Font.GothamMedium
		description.TextSize = 14
		description.TextWrapped = true
		description.TextXAlignment = Enum.TextXAlignment.Left
		description.LayoutOrder = tier * 2
		description.Parent = shopPanel
		local buyButton = Instance.new("TextButton")
		buyButton.Name = "BuyMagnet" .. tostring(tier)
		buyButton.Size = UDim2.new(1, 0, 0, 40)
		buyButton.TextColor3 = Color3.fromRGB(240, 255, 240)
		buyButton.Font = Enum.Font.GothamBold
		buyButton.TextScaled = true
		buyButton.LayoutOrder = tier * 2 + 1
		buyButton.Parent = shopPanel
		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 8)
		buyCorner.Parent = buyButton
		local buyTextSize = Instance.new("UITextSizeConstraint")
		buyTextSize.MinTextSize = 12
		buyTextSize.MaxTextSize = 18
		buyTextSize.Parent = buyButton
		buyButtons[tier] = buyButton
	end
	local shopNote = Instance.new("TextLabel")
	shopNote.Name = "SessionNote"
	shopNote.Size = UDim2.new(1, 0, 0, 40)
	shopNote.BackgroundTransparency = 1
	shopNote.Text = "Loading saved progress..."
	shopNote.TextColor3 = Color3.fromRGB(170, 185, 205)
	shopNote.Font = Enum.Font.Gotham
	shopNote.TextSize = 12
	shopNote.TextWrapped = true
	shopNote.LayoutOrder = 100
	shopNote.Parent = shopPanel

	local bookPanel = createPanel("CollectionBook")
	local bookTitle = Instance.new("TextLabel")
	bookTitle.Name = "Title"
	bookTitle.Size = UDim2.new(1, 0, 0, 28)
	bookTitle.BackgroundTransparency = 1
	bookTitle.Text = "Collection Book"
	bookTitle.TextColor3 = Color3.fromRGB(235, 220, 255)
	bookTitle.Font = Enum.Font.GothamBold
	bookTitle.TextSize = 20
	bookTitle.TextXAlignment = Enum.TextXAlignment.Left
	bookTitle.LayoutOrder = 0
	bookTitle.Parent = bookPanel
	local bookProgress = Instance.new("TextLabel")
	bookProgress.Name = "Progress"
	bookProgress.Size = UDim2.new(1, 0, 0, 28)
	bookProgress.BackgroundTransparency = 1
	bookProgress.TextColor3 = Color3.fromRGB(220, 230, 240)
	bookProgress.Font = Enum.Font.GothamBold
	bookProgress.TextSize = 16
	bookProgress.TextXAlignment = Enum.TextXAlignment.Left
	bookProgress.LayoutOrder = 1
	bookProgress.Parent = bookPanel
	local milestoneRows: { [number]: TextLabel } = {}
	for index, milestone in Book.milestones do
		local row = Instance.new("TextLabel")
		row.Name = "Milestone" .. tostring(milestone.count)
		row.Size = UDim2.new(1, 0, 0, 28)
		row.BackgroundTransparency = 1
		row.TextColor3 = Color3.fromRGB(255, 225, 120)
		row.Font = Enum.Font.Gotham
		row.TextSize = 13
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.LayoutOrder = 1 + index
		row.Parent = bookPanel
		milestoneRows[milestone.count] = row
	end
	local bookRows: { [string]: TextLabel } = {}
	for index, objectId in Book.orderedIds do
		local row = Instance.new("TextLabel")
		row.Name = objectId
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 16
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.LayoutOrder = 10 + index
		row.Parent = bookPanel
		bookRows[objectId] = row
	end
	local bookNote = Instance.new("TextLabel")
	bookNote.Name = "StorageNote"
	bookNote.Size = UDim2.new(1, 0, 0, 40)
	bookNote.BackgroundTransparency = 1
	bookNote.TextColor3 = Color3.fromRGB(170, 185, 205)
	bookNote.Font = Enum.Font.Gotham
	bookNote.TextSize = 12
	bookNote.TextWrapped = true
	bookNote.LayoutOrder = 100
	bookNote.Parent = bookPanel

	local feedbackText: string? = nil
	local feedbackVersion = 0
	local saleCoolingDown = false
	local buyCoolingDown = false
	local upgradeCoolingDown = false
	local skinAction = "Buying..."
	local function update()
		if not alive then
			return
		end
		local coinAttribute = player:GetAttribute("Coins")
		local coins = if typeof(coinAttribute) == "number" and coinAttribute >= 0
			and coinAttribute <= 9007199254740991 and coinAttribute % 1 == 0 then coinAttribute else 0
		local dataReady = player:GetAttribute("DataReady") == true
		local mode = player:GetAttribute("StorageMode")
		local status = player:GetAttribute("DataStatus")
		local storageText = if mode == "Preview" then "Preview: progress is not saved"
			elseif not dataReady then
				if status == "Error" then "Data unavailable - rejoin to retry"
				elseif status == "Closing" then "Saving before leaving..." else "Loading saved progress..."
			elseif status == "Saving" then "Saving progress..."
			elseif status == "SaveDelayed" then "Save delayed - retrying"
			elseif status == "Dirty" then "Waiting for auto-save"
			elseif status == "Saved" then "Progress saved"
			elseif status == "Ready" then "Progress loaded" else "Checking save status"
		label.Text = (if dataReady then "Coins: " .. tostring(coins) else "Coins: --")
			.. "\n" .. (feedbackText or "Pick up coins or sell metal") .. "\n" .. storageText
		note.Text = storageText
		shopNote.Text = storageText
		bookNote.Text = storageText
		local discoveries: Book.Discovery = {}
		for objectId, row in bookRows do
			local definition = Definitions[objectId]
			local discovered = dataReady and player:GetAttribute(Book.attributePrefix .. objectId) == true
			if discovered then discoveries[objectId] = true end
			local rarity = definition.rarity or "Common"
			local color = if discovered then Book.rarityColors[rarity] else { 150, 165, 185 }
			row.Text = (if discovered then definition.name else "???") .. " | " .. rarity
			row.TextColor3 = Color3.fromRGB(color[1], color[2], color[3])
		end
		local discoveredCount = Book.count(discoveries)
		bookProgress.Text = if dataReady then "Discovered: " .. tostring(discoveredCount) .. " / " .. tostring(#Book.orderedIds)
			else "Waiting for saved collection..."
		bookButton.Text = if dataReady then "Book: " .. tostring(discoveredCount) .. "/" .. tostring(#Book.orderedIds) else "Book: --"
		bookButton.BackgroundColor3 = if bookPanel.Visible then Color3.fromRGB(100, 65, 135) else Color3.fromRGB(65, 45, 90)
		for _, milestone in Book.milestones do
			milestoneRows[milestone.count].Text = tostring(milestone.count) .. " discoveries: +" .. tostring(milestone.reward) .. " coins"
				.. (if not dataReady then "" elseif discoveredCount >= milestone.count then " | Reached"
					else " | Need " .. tostring(milestone.count - discoveredCount))
		end
		local total = 0
		local saleValue = 0
		for objectId, row in rows do
			local attributeValue = player:GetAttribute(Inventory.attributePrefix .. objectId)
			local count = if typeof(attributeValue) == "number" then attributeValue else 0
			row.Text = Definitions[objectId].name .. "  x" .. tostring(count)
			total += count
			saleValue += count * Definitions[objectId].reward
		end
		button.Text = "Inventory: " .. tostring(total)
		button.BackgroundColor3 = if panel.Visible then Color3.fromRGB(55, 95, 130) else Color3.fromRGB(40, 65, 90)
		local canSell = dataReady and total > 0 and not saleCoolingDown
		sellButton.Text = if not dataReady then "Data unavailable"
			elseif saleCoolingDown then "Selling..."
			elseif total > 0 then "Sell all (+" .. tostring(saleValue) .. " coins)" else "Sell all (empty)"
		sellButton.Active = canSell
		sellButton.Selectable = canSell
		sellButton.AutoButtonColor = canSell
		sellButton.BackgroundColor3 = if canSell then Color3.fromRGB(45, 115, 65) else Color3.fromRGB(55, 65, 70)
		local tierAttribute = player:GetAttribute("MagnetTier")
		local tier = if typeof(tierAttribute) == "number" and tierAttribute >= 1
			and tierAttribute <= #Magnets and tierAttribute % 1 == 0 then tierAttribute else 1
		local equipped = Magnets[tier]
		currentMagnet.Text = if dataReady then "Equipped look: " .. equipped.name .. " | Cosmetic only"
			else "Waiting for saved magnet..."
		shopButton.Text = "Shop"
		shopButton.BackgroundColor3 = if shopPanel.Visible then Color3.fromRGB(135, 95, 45) else Color3.fromRGB(90, 65, 35)
		for targetTier, buyButton in buyButtons do
			local definition = Magnets[targetTier]
			local owned = player:GetAttribute("OwnedMagnet_" .. definition.id) == true
			local canBuy = dataReady and targetTier ~= tier and (owned or coins >= definition.price) and not buyCoolingDown
			buyButton.Text = if not dataReady then "Data unavailable"
				elseif targetTier == tier then "Equipped"
				elseif buyCoolingDown then skinAction
				elseif owned then "Equip " .. definition.name
				elseif coins < definition.price then "Need " .. tostring(definition.price - coins) .. " more coins"
				else "Buy " .. definition.name .. " (" .. tostring(definition.price) .. " coins)"
			buyButton.Active = canBuy
			buyButton.Selectable = canBuy
			buyButton.AutoButtonColor = canBuy
			buyButton.BackgroundColor3 = if canBuy then Color3.fromRGB(45, 115, 65) else Color3.fromRGB(55, 65, 70)
		end
		for upgradeId, upgradeButton in upgradeButtons do
			local definition = Upgrades[upgradeId]
			local rawLevel = player:GetAttribute("Upgrade_" .. upgradeId)
			local current = Upgrade.definitionFor(Upgrades, upgradeId, rawLevel) or definition.levels[1]
			local nextLevel = Upgrade.definitionFor(Upgrades, upgradeId, current.level + 1)
			local suffix = if upgradeId == "power" then "x" else ""
			local labels = upgradeLabels[upgradeId]
			labels.name.Text = (if upgradeId == "speed" then "Speed" else definition.name) .. " L" .. tostring(current.level)
			labels.value.Text = if dataReady then tostring(current.value) .. suffix
				.. (if nextLevel then " > " .. tostring(nextLevel.value) .. suffix else "")
				.. (if upgradeId == "range" then " studs" else "") else "--"
			labels.price.Text = if not dataReady then "Loading..."
				elseif not nextLevel then "MAX"
				elseif upgradeCoolingDown then "Upgrading..."
				elseif coins < nextLevel.price then "Need " .. tostring(nextLevel.price - coins) .. " coins"
				else tostring(nextLevel.price) .. " coins"
			local canUpgrade = dataReady and nextLevel ~= nil and coins >= nextLevel.price and not upgradeCoolingDown
			upgradeButton.Active = canUpgrade
			upgradeButton.Selectable = canUpgrade
			upgradeButton.AutoButtonColor = canUpgrade
			upgradeButton.BackgroundColor3 = if canUpgrade then Color3.fromRGB(40, 85, 65) else Color3.fromRGB(35, 45, 60)
		end
	end
	-- Subscribe before initial read so a replication update cannot be missed.
	local function showFeedback(message: string)
		if not alive then
			return
		end
		feedbackVersion += 1
		local version = feedbackVersion
		feedbackText = message
		update()
		task.delay(Config.feedbackDuration, function()
			if alive and feedbackVersion == version then
				feedbackText = nil
				update()
			end
		end)
	end
	local stateConnections: { RBXScriptConnection } = {
		player:GetAttributeChangedSignal("Coins"):Connect(update),
		player:GetAttributeChangedSignal("MagnetTier"):Connect(update),
		player:GetAttributeChangedSignal("DataReady"):Connect(update),
		player:GetAttributeChangedSignal("StorageMode"):Connect(update),
		player:GetAttributeChangedSignal("DataStatus"):Connect(update),
		collectionResult.OnClientEvent:Connect(function(payload, ...: unknown)
			if select("#", ...) ~= 0 or typeof(payload) ~= "table" or typeof(payload.lifecycleId) ~= "string"
				or typeof(payload.objectId) ~= "string" or typeof(payload.startCFrame) ~= "CFrame" then
				return
			end
			if #payload.lifecycleId == 0 or #payload.lifecycleId > Config.maxLifecycleLength then
				return
			end
			local definition = Definitions[payload.objectId]
			if not definition then
				return
			end
			if definition.kind == "Coin" then
				showFeedback(definition.name .. ": +" .. tostring(definition.reward) .. " coin")
			else
				showFeedback(definition.name .. ": +1 in inventory")
			end
		end),
		saleResult.OnClientEvent:Connect(function(payout: unknown, ...: unknown)
			if select("#", ...) ~= 0 or typeof(payout) ~= "number" or payout ~= payout or payout < 0
				or payout > 9007199254740991 or payout % 1 ~= 0 then
				return
			end
			showFeedback(if payout > 0 then "Sold metal: +" .. tostring(payout) .. " coins" else "Inventory is empty")
		end),
		shopResult.OnClientEvent:Connect(function(payload, ...: unknown)
			if select("#", ...) ~= 0 or typeof(payload) ~= "table" or typeof(payload.status) ~= "string"
				or typeof(payload.tier) ~= "number" or payload.tier < 1 or payload.tier > #Magnets
				or payload.tier % 1 ~= 0 then
				return
			end
			local definition = Magnets[payload.tier]
			if payload.status == "purchased" then
				showFeedback("Bought " .. definition.name .. " (appearance only)")
			elseif payload.status == "equipped" then
				showFeedback("Equipped " .. definition.name .. " (appearance only)")
			elseif payload.status == "insufficientCoins" then
				showFeedback("Not enough coins for " .. definition.name)
			elseif payload.status == "owned" then
				showFeedback("Already own " .. definition.name)
			elseif payload.status == "invalidTier" then
				showFeedback("Magnet unavailable")
			end
		end),
		upgradeResult.OnClientEvent:Connect(function(payload, ...: unknown)
			if select("#", ...) ~= 0 or typeof(payload) ~= "table" or typeof(payload.status) ~= "string"
				or typeof(payload.upgradeId) ~= "string" then return end
			for key in payload do
				if key ~= "status" and key ~= "upgradeId" and key ~= "level" then return end
			end
			local level = Upgrade.definitionFor(Upgrades, payload.upgradeId, payload.level)
			if not level then return end
			local name = Upgrades[payload.upgradeId].name
			if payload.status == "purchased" then
				showFeedback(name .. " upgraded to L" .. tostring(level.level))
			elseif payload.status == "insufficientCoins" then
				showFeedback("Not enough coins for " .. name)
			elseif payload.status == "owned" then
				showFeedback(name .. " level already owned")
			elseif payload.status == "maxLevel" then
				showFeedback(name .. " is at MAX")
			elseif payload.status == "locked" then
				showFeedback("Upgrade " .. name .. " one level at a time")
			end
		end),
		bookResult.OnClientEvent:Connect(function(payload, ...: unknown)
			if select("#", ...) ~= 0 or typeof(payload) ~= "table" or typeof(payload.objectId) ~= "string"
				or typeof(payload.count) ~= "number" or payload.count < 1 or payload.count > #Book.orderedIds
				or payload.count % 1 ~= 0 or typeof(payload.reward) ~= "number" then return end
			for key in payload do
				if key ~= "objectId" and key ~= "count" and key ~= "reward" then return end
			end
			local definition = Definitions[payload.objectId]
			if not definition or definition.kind ~= "Metal" then return end
			local expectedReward = 0
			for _, milestone in Book.milestones do
				if milestone.count == payload.count then expectedReward = milestone.reward end
			end
			if payload.reward ~= expectedReward then return end
			showFeedback("Discovered " .. definition.name .. " (" .. tostring(payload.count) .. "/" .. tostring(#Book.orderedIds) .. ")"
				.. (if payload.reward > 0 then " +" .. tostring(payload.reward) .. " coins" else ""))
		end),
	}
	for _, connection in stateConnections do table.insert(connections, connection) end
	for objectId in rows do
		table.insert(connections, player:GetAttributeChangedSignal(Inventory.attributePrefix .. objectId):Connect(update))
	end
	for objectId in bookRows do
		table.insert(connections, player:GetAttributeChangedSignal(Book.attributePrefix .. objectId):Connect(update))
	end
	for _, definition in Magnets do
		table.insert(connections, player:GetAttributeChangedSignal("OwnedMagnet_" .. definition.id):Connect(update))
	end
	for _, upgradeId in Upgrade.orderedIds do
		table.insert(connections, player:GetAttributeChangedSignal("Upgrade_" .. upgradeId):Connect(update))
	end
	gui.Destroying:Connect(function()
		alive = false
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	button.Activated:Connect(function()
		panel.Visible = not panel.Visible
		shopPanel.Visible = false
		bookPanel.Visible = false
		update()
	end)
	shopButton.Activated:Connect(function()
		shopPanel.Visible = not shopPanel.Visible
		panel.Visible = false
		bookPanel.Visible = false
		update()
	end)
	bookButton.Activated:Connect(function()
		bookPanel.Visible = not bookPanel.Visible
		panel.Visible = false
		shopPanel.Visible = false
		update()
	end)
	local lastSaleRequest = -math.huge
	sellButton.Activated:Connect(function()
		local now = os.clock()
		if not sellButton.Active or now - lastSaleRequest < 1 / Config.sellRequestsPerSecond then
			return
		end
		lastSaleRequest = now
		saleCoolingDown = true
		update()
		task.delay(1 / Config.sellRequestsPerSecond, function()
			if alive then
				saleCoolingDown = false
				update()
			end
		end)
		-- Displayed quantities/value are hints only. The server prices and consumes.
		-- Cooldown is local courtesy throttling; receipts never unlock it.
		sellRemote:FireServer()
	end)
	local lastBuyRequest = -math.huge
	for tier, buyButton in buyButtons do
		local requestedTier = tier
		buyButton.Activated:Connect(function()
			local now = os.clock()
			if not buyButton.Active or now - lastBuyRequest < 1 / Config.buyRequestsPerSecond then
				return
			end
			lastBuyRequest = now
			skinAction = if player:GetAttribute("OwnedMagnet_" .. Magnets[requestedTier].id) == true then "Equipping..." else "Buying..."
			buyCoolingDown = true
			update()
			task.delay(1 / Config.buyRequestsPerSecond, function()
				if alive then
					buyCoolingDown = false
					update()
				end
			end)
			-- Tier identifies a cosmetic look. The server owns price and ownership.
			buyRemote:FireServer(requestedTier)
		end)
	end
	local lastUpgradeRequest = -math.huge
	for upgradeId, upgradeButton in upgradeButtons do
		local requestedId = upgradeId
		upgradeButton.Activated:Connect(function()
			local now = os.clock()
			if not upgradeButton.Active or now - lastUpgradeRequest < 1 / Config.upgradeRequestsPerSecond then return end
			local current = Upgrade.definitionFor(Upgrades, requestedId, player:GetAttribute("Upgrade_" .. requestedId))
			if not current or not Upgrade.definitionFor(Upgrades, requestedId, current.level + 1) then return end
			lastUpgradeRequest = now
			upgradeCoolingDown = true
			update()
			task.delay(1 / Config.upgradeRequestsPerSecond, function()
				if alive then upgradeCoolingDown = false; update() end
			end)
			-- Explicit desired level makes delayed/replayed clicks idempotent on the server.
			upgradeRemote:FireServer(requestedId, current.level + 1)
		end)
	end
	update()
	gui.Parent = playerGui
end

return Hud
