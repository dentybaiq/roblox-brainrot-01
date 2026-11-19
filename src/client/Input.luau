-- Brainrot Bazaar — input bindings.
-- All keys go through ContextActionService (never InputBegan with
-- gameProcessedEvent for movement keys — Roblox's camera owns the arrows).
-- Buying / stealing is done with ProximityPrompt (E), which Roblox handles
-- itself, so there is no binding for it here.

local ContextActionService = game:GetService("ContextActionService")

local Input = {}

local remotes = nil
local Sound = nil

function Input.init(r, sound)
	remotes = r
	Sound = sound

	-- L: lock your base.
	ContextActionService:BindAction("LockBase", function(_actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			if Sound then
				Sound.play("click")
			end
			if remotes and remotes.LockBase then
				remotes.LockBase:FireServer()
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.L)

	-- F: slap a nearby thief to make them drop what they are carrying.
	ContextActionService:BindAction("Slap", function(_actionName, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			if Sound then
				Sound.play("steal")
			end
			if remotes and remotes.Slap then
				remotes.Slap:FireServer()
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F)
end

return Input

-- Polish pass 18 Nov: reviewed; no change needed.
