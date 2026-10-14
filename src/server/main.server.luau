--!strict

local Services = script.Parent.Services
local Persistence = require(Services.PersistenceService)
local World = require(Services.PrototypeWorldService)
local Collectibles = require(Services.CollectibleService)

local folder = World.create()
Collectibles.start(folder)
Persistence.start()
print("Magnet Mayhem ready — coin pickups, metal inventory and selling")
