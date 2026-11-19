-- Steal.luau
-- Stealing, carrying, slapping and base locks.
-- A stolen brainrot is carried above the thief's head (the model is
-- repositioned every frame) until the thief reaches their own base,
-- gets slapped, runs out of time, or gets swept by the tsunami.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local Economy = require(script.Parent:WaitForChild("Economy"))
local Conveyor = require(script.Parent:WaitForChild("Conveyor"))

local Steal = {}

-- isInOwnBase(state): true when the player is standing on their base
-- floor (24x24, so within 12 studs of the centre on both axes).
-- A square check, not a circle: the floor's corners sit ~17 studs out,
-- so a radius check would wrongly sweep a player standing in a corner.
function Steal.isInOwnBase(state)
	local character = state.player.Character
	if character == nil then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return false
	end
	local centre = GameState.getBaseCentre(state)
	return math.abs(root.Position.X - centre.X) <= 12
		and math.abs(root.Position.Z - centre.Z) <= 12
end

-- ---------------------------------------------------------------------------
-- Base lock
-- ---------------------------------------------------------------------------

-- isBaseLocked(state): true while the lock timer is running.
function Steal.isBaseLocked(state)
	if state == nil then
		return false
	end
	return os.time() < state.lockUntil
end

-- setGate(state, closed): solid + visible when closed, see-through and
-- walk-through when open.
local function setGate(state, closed)
	if state.base == nil then
		return
	end
	local gate = state.base:FindFirstChild("Gate")
	if gate ~= nil and gate:IsA("BasePart") then
		gate.Transparency = closed and 0 or 1
		gate.CanCollide = closed
	end
	state.gateClosed = closed
end

-- lockBase(player): lock your own base for LOCK_DURATION + lockBonus.
-- Stealing from a locked base is blocked, and the gate physically closes.
function Steal.lockBase(player)
	local state = GameState.getState(player)
	if state == nil then
		return
	end
	local now = os.time()
	if now < state.lockCooldownUntil then
		local remaining = state.lockCooldownUntil - now
		GameState.notify(player, "Lock is on cooldown! " .. tostring(remaining) .. "s left.", "error")
		return
	end
	if Steal.isBaseLocked(state) then
		GameState.notify(player, "Your base is already locked!", "error")
		return
	end
	local duration = Config.LOCK_DURATION + state.lockBonus
	state.lockUntil = now + duration
	state.lockCooldownUntil = now + duration + Config.LOCK_COOLDOWN
	setGate(state, true)
	GameState.notify(player, "Base locked for " .. tostring(duration) .. "s!", "success")
	GameState.broadcastState(player)
end

-- ---------------------------------------------------------------------------
-- Carrying
-- ---------------------------------------------------------------------------

-- slowThief(state, carrying): WalkSpeed x0.7 while carrying, normal after.
local function applyCarrySpeed(state, carrying)
	local character = state.player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local baseSpeed = Config.BASE_WALK_SPEED + state.walkSpeedBonus
	humanoid.WalkSpeed = carrying and (baseSpeed * Config.CARRY_SPEED_MULTIPLIER) or baseSpeed
end

-- findOwnerEntry(model) -> owner state, entry or nil, nil.
local function findOwnerEntry(model)
	for _, ownerState in pairs(GameState.players) do
		local entry = Economy.findEntryByModel(ownerState, model)
		if entry ~= nil then
			return ownerState, entry
		end
	end
	return nil, nil
end

-- stealBrainrot(player, brainrotModel): pick up a brainrot from another
-- player's base. Blocked when the target base is locked.
function Steal.stealBrainrot(player, brainrotModel)
	local state = GameState.getState(player)
	if state == nil then
		return
	end
	if state.carried ~= nil then
		GameState.notify(player, "You're already carrying a brainrot!", "error")
		return
	end
	local ownerState, entry = findOwnerEntry(brainrotModel)
	if entry == nil then
		GameState.notify(player, "That brainrot is gone!", "error")
		return
	end
	if ownerState.userId == state.userId then
		GameState.notify(player, "That's your own brainrot!", "error")
		return
	end
	if Steal.isBaseLocked(ownerState) then
		GameState.notify(player, "That base is locked! Come back later.", "error")
		return
	end

	-- Take it off the owner's base (model stays alive, now carried).
	for i, e in ipairs(ownerState.brainrots) do
		if e == entry then
			table.remove(ownerState.brainrots, i)
			break
		end
	end
	GameState.recomputeIncome(ownerState.player)

	state.carried = {
		model = entry.model,
		charId = entry.charId,
		mutation = entry.mutation,
		income = entry.income,
		ownerUserId = ownerState.userId,
		carriedSince = os.clock(),
	}
	applyCarrySpeed(state, true)

	local char = BrainrotData.getCharacter(entry.charId)
	local displayName = char and char.name or entry.charId
	GameState.notify(player, "You stole " .. displayName .. "! Run home in " .. tostring(Config.STEAL_RETURN_TIMEOUT) .. "s!", "warning")
	GameState.notify(ownerState.player, player.Name .. " stole your " .. displayName .. "! Slap them!", "error")
	GameState.broadcastState(player)
	GameState.broadcastState(ownerState.player)
end

-- dropCarried(state, reason): the carried brainrot goes back to its
-- original owner's first free slot. If the owner has no slot (or left),
-- it returns to the conveyor belt instead of vanishing.
function Steal.dropCarried(state, reason)
	local carried = state.carried
	if carried == nil then
		return
	end
	state.carried = nil
	applyCarrySpeed(state, false)

	local ownerState = GameState.getStateByUserId(carried.ownerUserId)
	local returned = false
	if ownerState ~= nil then
		-- Remove the old model and place a fresh copy on the owner's base.
		if carried.model ~= nil and carried.model.Parent ~= nil then
			carried.model:Destroy()
		end
		local placed = Economy.placeOnSlot(ownerState, carried.charId, carried.mutation, carried.income, carried.ownerUserId)
		returned = placed ~= nil
	end
	if not returned then
		-- Owner gone or base full: send it back out on the conveyor.
		if carried.model ~= nil and carried.model.Parent ~= nil then
			carried.model:Destroy()
		end
		Conveyor.returnBrainrot(carried.charId, carried.mutation)
	end

	if reason ~= nil and reason ~= "" then
		GameState.notify(state.player, reason, "warning")
	end
	GameState.broadcastState(state.player)
	if ownerState ~= nil then
		GameState.broadcastState(ownerState.player)
	end
end

-- placeCarried(state): called when a carrying player reaches their own
-- base. The brainrot becomes theirs on the first free slot.
function Steal.placeCarried(state)
	local carried = state.carried
	if carried == nil then
		return false
	end
	if #state.brainrots >= state.slots then
		-- No room at home: it slips away back to its owner.
		Steal.dropCarried(state, "No free slot! The brainrot escaped back home.")
		return false
	end
	if carried.model ~= nil and carried.model.Parent ~= nil then
		carried.model:Destroy()
	end
	local placed = Economy.placeOnSlot(state, carried.charId, carried.mutation, carried.income, state.userId)
	state.carried = nil
	applyCarrySpeed(state, false)
	if placed ~= nil then
		GameState.notify(state.player, "Stolen brainrot secured! It now earns for you.", "success")
		GameState.broadcastState(state.player)
		return true
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Slap
-- ---------------------------------------------------------------------------

-- slap(attacker, target): knock the brainrot out of a nearby thief's hands.
-- `target` may be nil, in which case the nearest carrying player in range
-- is slapped. Attacker cooldown: SLAP_COOLDOWN seconds.
function Steal.slap(attacker, target)
	local attackerState = GameState.getState(attacker)
	if attackerState == nil then
		return
	end
	local now = os.clock()
	if now - attackerState.lastSlapAt < Config.SLAP_COOLDOWN then
		return
	end
	local attackerRoot = attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
	if attackerRoot == nil then
		return
	end

	-- Resolve the target: explicit player, or nearest carrier in range.
	local targetState = nil
	if target ~= nil then
		targetState = GameState.getState(target)
	else
		local bestDistance = Config.SLAP_RANGE
		for _, candidate in pairs(GameState.players) do
			if candidate.carried ~= nil and candidate.userId ~= attackerState.userId then
				local root = candidate.player.Character and candidate.player.Character:FindFirstChild("HumanoidRootPart")
				if root ~= nil then
					local d = (root.Position - attackerRoot.Position).Magnitude
					if d <= bestDistance then
						bestDistance = d
						targetState = candidate
					end
				end
			end
		end
	end

	if targetState == nil or targetState.carried == nil then
		return
	end
	local targetRoot = targetState.player.Character and targetState.player.Character:FindFirstChild("HumanoidRootPart")
	if targetRoot == nil then
		return
	end
	if (targetRoot.Position - attackerRoot.Position).Magnitude > Config.SLAP_RANGE then
		GameState.notify(attacker, "Too far away to slap!", "error")
		return
	end

	attackerState.lastSlapAt = now
	local stolenChar = BrainrotData.getCharacter(targetState.carried.charId)
	local stolenName = stolenChar and stolenChar.name or targetState.carried.charId
	Steal.dropCarried(targetState, "You got slapped! The brainrot went home.")
	GameState.notify(attacker, "SLAP! " .. targetState.player.Name .. " dropped " .. stolenName .. "!", "success")
end

-- ---------------------------------------------------------------------------
-- Loops
-- ---------------------------------------------------------------------------

function Steal.start()
	-- Carry follow: every frame, hover the carried model above the thief.
	RunService.Heartbeat:Connect(function()
		for _, state in pairs(GameState.players) do
			local carried = state.carried
			if carried ~= nil then
				local character = state.player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local head = character and character:FindFirstChild("Head")
				if humanoid == nil or humanoid.Health <= 0 or head == nil then
					-- Thief died / respawned: drop the brainrot.
					Steal.dropCarried(state, "You died and dropped the brainrot!")
				elseif carried.model ~= nil and carried.model.Parent ~= nil then
					local target = head.Position + Vector3.new(0, 3.5, 0)
					carried.model:PivotTo(CFrame.new(target))
				end
			end
		end
	end)

	-- Slow loop (0.5s): lock expiry, steal timeout, auto-place at home.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, state in pairs(GameState.players) do
				-- Lock expired: open the gate.
				if state.gateClosed and not Steal.isBaseLocked(state) then
					setGate(state, false)
					GameState.notify(state.player, "Your base lock expired.", "info")
					GameState.broadcastState(state.player)
				end
				-- Carrying: timeout or arrived home.
				if state.carried ~= nil then
					if os.clock() - state.carried.carriedSince > Config.STEAL_RETURN_TIMEOUT then
						Steal.dropCarried(state, "Too slow! The brainrot returned to its owner.")
					elseif Steal.isInOwnBase(state) then
						Steal.placeCarried(state)
					end
				end
			end
		end
	end)
end

return Steal
