-- Conveyor.luau
-- The central belt: spawns brainrots on a timer, walks them +X along z=0,
-- despawns them at the far end. Tracks every brainrot currently on the
-- belt. Buying is handled through the prompt's Triggered event, which
-- calls the buy handler set by init (Economy.buyBrainrot) — Conveyor
-- never touches player money itself.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))
local BrainrotFactory = require(script.Parent:WaitForChild("BrainrotFactory"))

local Conveyor = {}

-- Active belt brainrots: { model, charId, mutation, cost, income, phase }
Conveyor.brainrots = {}

-- Called when a player presses E on a belt brainrot. Set by init.server
-- to Economy.buyBrainrot. Kept as a setter so Conveyor never requires
-- Economy (that would be a circular require: Economy requires Conveyor).
local buyHandler = nil
function Conveyor.setBuyHandler(fn)
	buyHandler = fn
end

function Conveyor.getConveyorBrainrots()
	return Conveyor.brainrots
end

-- removeBrainrot(model): take a brainrot off the belt (bought or despawned).
-- Destroys the model. Returns true if it was on the belt.
function Conveyor.removeBrainrot(model)
	for i, entry in ipairs(Conveyor.brainrots) do
		if entry.model == model then
			table.remove(Conveyor.brainrots, i)
			model:Destroy()
			return true
		end
	end
	return false
end

-- findEntry(model) -> belt entry or nil.
function Conveyor.findEntry(model)
	for _, entry in ipairs(Conveyor.brainrots) do
		if entry.model == model then
			return entry
		end
	end
	return nil
end

-- returnBrainrot(charId, mutation): put a brainrot back on the belt
-- (used when a stolen brainrot has nowhere to return to). It joins the
-- belt at a random x so it does not stack on top of a fresh spawn.
function Conveyor.returnBrainrot(charId, mutation)
	if #Conveyor.brainrots >= Config.MAX_CONVEYOR then
		return nil
	end
	local char = BrainrotData.getCharacter(charId)
	if char == nil then
		return nil
	end
	local model = BrainrotFactory.buildBrainrot(char.id, mutation)
	local income = BrainrotData.incomeFor(char, mutation)
	model:PivotTo(CFrame.new(
		math.random(Config.CONVEYOR_START_X, 0),
		Config.CONVEYOR_Y,
		Config.CONVEYOR_Z
	))
	model.Parent = workspace

	local prompt = model.PrimaryPart:FindFirstChild("BrainrotPrompt")
	if prompt ~= nil then
		prompt.ActionText = "Buy"
		prompt.ObjectText = char.name .. " — " .. Util.formatMoney(char.cost)
		prompt.Triggered:Connect(function(player)
			if buyHandler ~= nil then
				buyHandler(player, model)
			end
		end)
	end

	local entry = {
		model = model,
		charId = char.id,
		mutation = mutation,
		cost = char.cost,
		income = income,
		phase = math.random() * math.pi * 2,
	}
	table.insert(Conveyor.brainrots, entry)
	return entry
end

-- spawnOne(): roll a character + mutation, build the model, put it at the
-- start of the belt and wire its Buy prompt.
local function spawnOne()
	local char = BrainrotData.rollCharacter()
	local mutation = BrainrotData.rollMutation()
	local model = BrainrotFactory.buildBrainrot(char.id, mutation)
	local income = BrainrotData.incomeFor(char, mutation)

	model:PivotTo(CFrame.new(Config.CONVEYOR_START_X, Config.CONVEYOR_Y, Config.CONVEYOR_Z))
	model.Parent = workspace

	local prompt = model.PrimaryPart:FindFirstChild("BrainrotPrompt")
	if prompt ~= nil then
		prompt.ActionText = "Buy"
		prompt.ObjectText = char.name .. " — " .. Util.formatMoney(char.cost)
		prompt.Triggered:Connect(function(player)
			if buyHandler ~= nil then
				buyHandler(player, model)
			end
		end)
	end

	local entry = {
		model = model,
		charId = char.id,
		mutation = mutation,
		cost = char.cost,
		income = income,
		phase = math.random() * math.pi * 2, -- random bob phase so they don't sync
	}
	table.insert(Conveyor.brainrots, entry)
	return entry
end

-- start(): spawn timer + movement loop.
function Conveyor.start()
	-- Spawn loop: one attempt every CONVEYOR_SPAWN_INTERVAL, capped.
	task.spawn(function()
		while true do
			task.wait(Config.CONVEYOR_SPAWN_INTERVAL)
			if #Conveyor.brainrots < Config.MAX_CONVEYOR then
				spawnOne()
			end
		end
	end)

	-- Movement loop: Heartbeat moves every belt brainrot +X at
	-- CONVEYOR_SPEED with a small vertical bob. Despawn past +70.
	RunService.Heartbeat:Connect(function(deltaTime)
		for i = #Conveyor.brainrots, 1, -1 do
			local entry = Conveyor.brainrots[i]
			local model = entry.model
			if model.Parent == nil then
				-- Destroyed elsewhere (bought); drop the stale entry.
				table.remove(Conveyor.brainrots, i)
			else
				local pos = model:GetPivot().Position
				local newX = pos.X + Config.CONVEYOR_SPEED * deltaTime
				if newX > Config.CONVEYOR_END_X then
					table.remove(Conveyor.brainrots, i)
					model:Destroy()
				else
					-- Bob: ±0.15 studs, each brainrot on its own phase.
					entry.phase += deltaTime * 3
					local bobY = Config.CONVEYOR_Y + math.sin(entry.phase) * 0.15
					model:PivotTo(CFrame.new(newX, bobY, Config.CONVEYOR_Z))
				end
			end
		end
	end)
end

return Conveyor
