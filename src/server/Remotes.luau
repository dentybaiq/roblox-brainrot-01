-- Remotes.luau
-- Creates the RemoteEvents under ReplicatedStorage and wires the
-- client -> server ones to Economy / Steal. The server -> client ones
-- (StateUpdate, Notify) are fired by GameState.
--
--   StateUpdate (server -> client): full player state payload (see
--     GameState.buildStatePayload)
--   Notify      (server -> client): (text, kind) toast message
--   LockBase    (client -> server): no args
--   Rebirth     (client -> server): no args
--   BuyUpgrade  (client -> server): (upgradeId: string)
--   Slap        (client -> server): (targetPlayer: Player | nil)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(script.Parent:WaitForChild("GameState"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Steal = require(script.Parent:WaitForChild("Steal"))

local Remotes = {}

local REMOTE_NAMES = { "StateUpdate", "Notify", "LockBase", "Rebirth", "BuyUpgrade", "Slap" }

-- create(): make (or reuse) every RemoteEvent, then wire the handlers.
function Remotes.create()
	local remotes = {}
	for _, name in ipairs(REMOTE_NAMES) do
		local existing = ReplicatedStorage:FindFirstChild(name)
		if existing ~= nil and existing:IsA("RemoteEvent") then
			remotes[name] = existing
		else
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = ReplicatedStorage
			remotes[name] = remote
		end
	end

	remotes.LockBase.OnServerEvent:Connect(function(player)
		Steal.lockBase(player)
	end)

	remotes.Rebirth.OnServerEvent:Connect(function(player)
		Economy.rebirth(player)
	end)

	remotes.BuyUpgrade.OnServerEvent:Connect(function(player, upgradeId)
		if typeof(upgradeId) == "string" then
			Economy.buyUpgrade(player, upgradeId)
		end
	end)

	remotes.Slap.OnServerEvent:Connect(function(player, target)
		-- The client may pass a target Player, or nothing (nearest carrier).
		if target ~= nil and typeof(target) ~= "Instance" then
			target = nil
		end
		Steal.slap(player, target)
	end)

	Remotes.events = remotes
	return remotes
end

-- get(name): fetch a created RemoteEvent (nil until create() runs).
function Remotes.get(name)
	if Remotes.events ~= nil then
		return Remotes.events[name]
	end
	return ReplicatedStorage:FindFirstChild(name)
end

return Remotes

-- Polish pass 18 Nov: reviewed; no change needed.
