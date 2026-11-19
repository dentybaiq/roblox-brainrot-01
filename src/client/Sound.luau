-- Brainrot Bazaar — sound effects.
-- Uses only built-in Roblox sound assets (rbxasset://), so there is no
-- dependency on marketplace audio IDs that might be moderated or deleted.
-- Every play is wrapped in pcall: a bad asset must never error the client.

local SoundService = game:GetService("SoundService")

local Sound = {}

local SOUNDS = {
	buy = { id = "rbxasset://sounds/electronicpingshort.wav", pitch = 1.3, volume = 0.6 },
	steal = { id = "rbxasset://sounds/electronicpinglong.wav", pitch = 0.8, volume = 0.6 },
	error = { id = "rbxasset://sounds/button.wav", pitch = 0.6, volume = 0.7 },
	lock = { id = "rbxasset://sounds/button.wav", pitch = 1.0, volume = 0.7 },
	tsunami = { id = "rbxasset://sounds/impact_water.mp3", pitch = 1.0, volume = 0.8 },
	rebirth = { id = "rbxasset://sounds/electronicpinglong.wav", pitch = 1.5, volume = 0.6 },
	click = { id = "rbxasset://sounds/button.wav", pitch = 1.2, volume = 0.5 },
}

-- Play a named sound once. Unknown names and failed assets are ignored.
function Sound.play(name)
	local def = SOUNDS[name]
	if not def then
		return
	end
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = def.id
		sound.PlaybackSpeed = def.pitch
		sound.Volume = def.volume
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		-- Safety net in case Ended never fires for a broken asset.
		task.delay(4, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end)
end

return Sound

-- Polish pass 18 Nov: reviewed; no change needed.
