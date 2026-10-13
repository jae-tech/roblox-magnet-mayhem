--!strict

local Controllers = script.Parent.Controllers
local Hud = require(Controllers.HudController)
local Magnet = require(Controllers.MagnetController)
local Attraction = require(Controllers.AttractionController)

Hud.start()
Magnet.start()
Attraction.start()
