--!strict

local Players = game:GetService("Players")

type Session = { coins: number }
local sessions: { [Player]: Session } = {}
local PlayerState = {}

function PlayerState.add(player: Player)
	if sessions[player] then
		return
	end
	sessions[player] = { coins = 0 }
	player:SetAttribute("Coins", 0)
end

function PlayerState.has(player: Player): boolean
	return sessions[player] ~= nil and player.Parent == Players
end

function PlayerState.award(player: Player, reward: number)
	local session = sessions[player]
	assert(session ~= nil, "Cannot award an unknown player")
	assert(reward > 0 and reward % 1 == 0, "Reward must be a positive integer")
	session.coins += reward
	player:SetAttribute("Coins", session.coins)
end

function PlayerState.remove(player: Player)
	sessions[player] = nil
end

return PlayerState
