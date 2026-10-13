--!strict

local Players = game:GetService("Players")
local Services = script.Parent.Services
local PlayerState = require(Services.PlayerStateService)
local World = require(Services.PrototypeWorldService)
local Collectibles = require(Services.CollectibleService)

local folder = World.create()
Players.PlayerAdded:Connect(PlayerState.add)
Players.PlayerRemoving:Connect(PlayerState.remove)
for _, player in Players:GetPlayers() do
	PlayerState.add(player)
end
Collectibles.start(folder)
print("Magnet Mayhem M1 ready — session coins only")
