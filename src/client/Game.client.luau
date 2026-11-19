-- Brainrot Bazaar — client entry point.
-- Thin bootstrap: requires the client modules, waits for the server's
-- RemoteEvents, and wires them to the HUD. The camera is left alone on
-- purpose: Roblox's default third-person camera is the game's 3D camera.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local HUD = require(script.Parent:WaitForChild("HUD"))
local Input = require(script.Parent:WaitForChild("Input"))
local Sound = require(script.Parent:WaitForChild("Sound"))
local Effects = require(script.Parent:WaitForChild("Effects"))

local player = Players.LocalPlayer

-- The server creates these RemoteEvents under ReplicatedStorage at runtime.
local REMOTE_NAMES = { "StateUpdate", "Notify", "LockBase", "Rebirth", "BuyUpgrade", "Slap" }

local remotes = {}
for _, name in ipairs(REMOTE_NAMES) do
	remotes[name] = ReplicatedStorage:WaitForChild(name)
end

HUD.init(remotes, Sound, Effects)
Input.init(remotes, Sound)

-- Play the tsunami warning sound once, when the timer crosses into the
-- last 10 seconds (HUD handles the visual warning itself).
local lastTsunamiIn = nil

remotes.StateUpdate.OnClientEvent:Connect(function(state)
	if typeof(state) ~= "table" then
		return
	end
	HUD.update(state)
	local tsunamiIn = state.tsunamiIn
	if typeof(tsunamiIn) == "number" and lastTsunamiIn ~= nil then
		if lastTsunamiIn > Config.TSUNAMI_WARNING and tsunamiIn <= Config.TSUNAMI_WARNING then
			Sound.play("tsunami")
		end
	end
	if typeof(tsunamiIn) == "number" then
		lastTsunamiIn = tsunamiIn
	end
end)

local KIND_SOUNDS = {
	success = "buy",
	error = "error",
	warning = "tsunami",
	info = "click",
}

remotes.Notify.OnClientEvent:Connect(function(text, kind)
	HUD.notify(text, kind)
	Sound.play(KIND_SOUNDS[kind] or "click")
end)

HUD.notify("Welcome to Brainrot Bazaar! Buy brainrots, guard your base!", "info")
