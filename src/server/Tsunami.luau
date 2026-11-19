-- Tsunami.luau
-- The Meme Tsunami: every TSUNAMI_INTERVAL seconds a warning goes out,
-- then a giant translucent blue wave sweeps the plaza from z=-80 to z=+80.
-- Players inside their own base are safe. Anyone the wave passes over
-- out in the open is swept back to SpawnLocation and drops anything
-- they are carrying.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local Steal = require(script.Parent:WaitForChild("Steal"))

local Tsunami = {}

local WAVE_SIZE = Vector3.new(170, 14, 10)
local WAVE_START_Z = -80
local WAVE_END_Z = 80

-- spawnLocation(): the SpawnLocation part, or a fallback pad position.
local function getSpawnCFrame()
	local spawn = workspace:FindFirstChild("SpawnLocation")
	if spawn ~= nil and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(0, 4, 40)
end

-- sweepPlayer(state): teleport home to spawn, drop carried brainrot,
-- brief speed penalty via a short WalkSpeed cut (restored by the next
-- carry-speed / upgrade application; here we just set it directly and
-- let the respawn/upgrade paths restore it).
local function sweepPlayer(state)
	local character = state.player.Character
	if state.carried ~= nil then
		Steal.dropCarried(state, "The tsunami swept you away! You dropped the brainrot.")
	end
	if character ~= nil then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root ~= nil then
			root.CFrame = getSpawnCFrame()
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil then
			-- Brief slow penalty after being swept.
			humanoid.WalkSpeed = (Config.BASE_WALK_SPEED + state.walkSpeedBonus) * 0.5
			task.delay(3, function()
				if humanoid.Parent ~= nil then
					humanoid.WalkSpeed = Config.BASE_WALK_SPEED + state.walkSpeedBonus
				end
			end)
		end
	end
	GameState.notify(state.player, "TSUNAMI! You got swept back to spawn!", "error")
end

-- runWave(): build the wave part and sweep it across the plaza over
-- TSUNAMI_SWEEP_SECONDS. Players the wave passes over while outside
-- their own base get swept.
local function runWave()
	local wave = Instance.new("Part")
	wave.Name = "TsunamiWave"
	wave.Size = WAVE_SIZE
	wave.Color = Color3.fromRGB(40, 140, 255)
	wave.Material = Enum.Material.Neon
	wave.Transparency = 0.4
	wave.Anchored = true
	wave.CanCollide = false
	wave.CanQuery = false
	wave.CFrame = CFrame.new(0, 7, WAVE_START_Z)
	wave.Parent = workspace

	GameState.notifyAll("TSUNAMI! Run home!", "warning")

	local swept = {}
	local startTime = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		local t = math.min(1, elapsed / Config.TSUNAMI_SWEEP_SECONDS)
		local z = WAVE_START_Z + (WAVE_END_Z - WAVE_START_Z) * t
		if wave.Parent ~= nil then
			wave.CFrame = CFrame.new(0, 7, z)
		end

		-- Anyone within 6 studs of the wave front, outside their base, is swept.
		for _, state in pairs(GameState.players) do
			if swept[state.userId] == nil and not Steal.isInOwnBase(state) then
				local character = state.player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root ~= nil and math.abs(root.Position.Z - z) < 6 then
					swept[state.userId] = true
					sweepPlayer(state)
				end
			end
		end

		if t >= 1 then
			connection:Disconnect()
			if wave.Parent ~= nil then
				wave:Destroy()
			end
		end
	end)
end

-- start(): the 90s timer loop. Pushes the countdown into GameState every
-- second so StateUpdate can carry it, warns at 10s, fires the wave at 0.
function Tsunami.start()
	task.spawn(function()
		while true do
			local remaining = Config.TSUNAMI_INTERVAL
			while remaining > 0 do
				GameState.setTsunamiIn(remaining)
				if remaining == Config.TSUNAMI_WARNING then
					GameState.notifyAll("Meme Tsunami in " .. tostring(Config.TSUNAMI_WARNING) .. "s! Get to your base!", "warning")
				end
				task.wait(1)
				remaining -= 1
			end
			GameState.setTsunamiIn(0)
			runWave()
			-- Let the wave finish crossing before the next countdown starts.
			task.wait(Config.TSUNAMI_SWEEP_SECONDS + 1)
		end
	end)
end

return Tsunami

-- Polish pass 18 Nov: reviewed; no change needed.
