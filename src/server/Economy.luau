-- Economy.luau
-- Money, buying, rebirths and base upgrades.
-- The money tick is the only place money is ever granted passively;
-- every purchase checks funds first and deducts before placing anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local Conveyor = require(script.Parent:WaitForChild("Conveyor"))
local BrainrotFactory = require(script.Parent:WaitForChild("BrainrotFactory"))

local Economy = {}

-- Called when a player presses E on a brainrot sitting on another
-- player's base. Set by init.server to Steal.stealBrainrot — kept as a
-- setter so Economy never requires Steal (Steal requires Economy).
local stealHandler = nil
function Economy.setStealHandler(fn)
	stealHandler = fn
end

-- ---------------------------------------------------------------------------
-- Slot placement
-- ---------------------------------------------------------------------------

-- findFreeSlot(state) -> slot index (1..state.slots) or nil when full.
local function findFreeSlot(state)
	local used = {}
	for _, entry in ipairs(state.brainrots) do
		used[entry.slot] = true
	end
	for i = 1, state.slots do
		if not used[i] then
			return i
		end
	end
	return nil
end

-- placeOnSlot(state, charId, mutation, income, ownerUserId) -> entry or nil.
-- Builds the brainrot model, stands it on the first free slot pad of the
-- owner's base, wires its Steal prompt, and registers it in GameState.
-- Returns nil (and destroys the model) when the base is full.
function Economy.placeOnSlot(state, charId, mutation, income, ownerUserId)
	local slot = findFreeSlot(state)
	if slot == nil then
		return nil
	end
	local model = BrainrotFactory.buildBrainrot(charId, mutation)
	local slotPos = GameState.getSlotPosition(state, slot)
	-- Body (PrimaryPart) is 2 studs tall, so its centre sits 1 stud above
	-- the pad top. Face the brainrot toward the plaza centre (0,0,0) so
	-- visitors see its face: eyes are on the model's local +Z side.
	local faceYaw = math.atan2(-slotPos.X, -slotPos.Z)
	model:PivotTo(CFrame.new(slotPos.X, slotPos.Y + 1, slotPos.Z) * CFrame.Angles(0, faceYaw, 0))
	model.Parent = workspace

	-- The prompt on a placed brainrot is a Steal prompt, not a Buy prompt.
	local prompt = model.PrimaryPart:FindFirstChild("BrainrotPrompt")
	if prompt ~= nil then
		prompt.ActionText = "Steal"
		prompt.ObjectText = BrainrotData.getCharacter(charId).name
		prompt.Triggered:Connect(function(player)
			if stealHandler ~= nil then
				stealHandler(player, model)
			end
		end)
	end

	local entry = {
		model = model,
		charId = charId,
		mutation = mutation,
		income = income,
		slot = slot,
		ownerUserId = ownerUserId or state.userId,
	}
	table.insert(state.brainrots, entry)
	GameState.recomputeIncome(state.player)
	return entry
end

-- removeFromBase(state, entry): unregisters + destroys a placed brainrot.
function Economy.removeFromBase(state, entry)
	for i, e in ipairs(state.brainrots) do
		if e == entry then
			table.remove(state.brainrots, i)
			break
		end
	end
	if entry.model ~= nil and entry.model.Parent ~= nil then
		entry.model:Destroy()
	end
	GameState.recomputeIncome(state.player)
end

-- findEntryByModel(state, model) -> entry or nil.
function Economy.findEntryByModel(state, model)
	for _, entry in ipairs(state.brainrots) do
		if entry.model == model then
			return entry
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Money tick
-- ---------------------------------------------------------------------------

function Economy.startMoneyLoop()
	task.spawn(function()
		while true do
			task.wait(Config.TICK_SECONDS)
			for _, state in pairs(GameState.players) do
				local earn = GameState.effectiveIncomePerSec(state) * Config.TICK_SECONDS
				if earn > 0 then
					state.money += earn
					state.lifetimeEarned += earn
				end
				GameState.broadcastState(state.player)
			end
		end
	end)
end

-- ---------------------------------------------------------------------------
-- Buying from the conveyor
-- ---------------------------------------------------------------------------

-- buyBrainrot(player, conveyorModel): the conveyor prompt handler.
function Economy.buyBrainrot(player, conveyorModel)
	local state = GameState.getState(player)
	if state == nil then
		return
	end
	local entry = Conveyor.findEntry(conveyorModel)
	if entry == nil then
		GameState.notify(player, "That brainrot is already gone!", "error")
		return
	end
	if state.money < entry.cost then
		GameState.notify(player, "Not enough money! Need $" .. tostring(entry.cost) .. ".", "error")
		return
	end
	if #state.brainrots >= state.slots then
		GameState.notify(player, "No free slot! Upgrade your base for more slots.", "error")
		return
	end

	state.money -= entry.cost
	-- Take it off the belt first so nobody else can buy the same one.
	Conveyor.removeBrainrot(conveyorModel)

	local placed = Economy.placeOnSlot(state, entry.charId, entry.mutation, entry.income, state.userId)
	if placed == nil then
		-- Base filled between the check and the placement: refund in full.
		state.money += entry.cost
		GameState.notify(player, "No free slot! Money refunded.", "error")
		return
	end

	local char = BrainrotData.getCharacter(entry.charId)
	GameState.notify(player, "Bought " .. char.name .. " for $" .. tostring(entry.cost) .. "!", "success")
	GameState.broadcastState(player)
end

-- ---------------------------------------------------------------------------
-- Rebirth
-- ---------------------------------------------------------------------------

function Economy.rebirth(player)
	local state = GameState.getState(player)
	if state == nil then
		return
	end
	if state.lifetimeEarned < Config.REBIRTH_THRESHOLD then
		local remaining = Config.REBIRTH_THRESHOLD - state.lifetimeEarned
		GameState.notify(player, "Need $" .. tostring(remaining) .. " more lifetime earned to Rebirth.", "error")
		return
	end
	if state.carried ~= nil then
		GameState.notify(player, "Put down what you're carrying before you Rebirth!", "error")
		return
	end

	-- Clear the base.
	for _, entry in ipairs(state.brainrots) do
		if entry.model ~= nil and entry.model.Parent ~= nil then
			entry.model:Destroy()
		end
	end
	state.brainrots = {}

	state.money = Config.START_MONEY
	state.rebirths += 1
	state.multiplier = math.min(1 + state.rebirths * Config.REBIRTH_MULTIPLIER, Config.REBIRTH_MAX_MULTIPLIER)
	GameState.recomputeIncome(player)

	GameState.notify(player, "REBIRTH! Income is now x" .. tostring(state.multiplier) .. " forever.", "success")
	GameState.broadcastState(player)
end

-- ---------------------------------------------------------------------------
-- Upgrades
-- ---------------------------------------------------------------------------

-- applyWalkSpeed(state): (re)applies the player's walk speed from their
-- upgrade bonus. Called after a speed purchase and on character respawn.
function Economy.applyWalkSpeed(state)
	local character = state.player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.WalkSpeed = Config.BASE_WALK_SPEED + state.walkSpeedBonus
	end
end

function Economy.buyUpgrade(player, upgradeId)
	local state = GameState.getState(player)
	if state == nil then
		return
	end

	if upgradeId == "slots" then
		if state.slots >= Config.MAX_SLOTS then
			GameState.notify(player, "Slots are already maxed out!", "error")
			return
		end
		if state.money < Config.SLOT_UPGRADE_COST then
			GameState.notify(player, "Not enough money for +slots!", "error")
			return
		end
		state.money -= Config.SLOT_UPGRADE_COST
		state.slots = math.min(state.slots + Config.SLOT_UPGRADE_ADD, Config.MAX_SLOTS)
		GameState.notify(player, "Base upgraded! You now have " .. tostring(state.slots) .. " slots.", "success")
	elseif upgradeId == "speed" then
		if state.walkSpeedBonus >= Config.SPEED_UPGRADE_MAX_BONUS then
			GameState.notify(player, "Speed is already maxed out!", "error")
			return
		end
		if state.money < Config.SPEED_UPGRADE_COST then
			GameState.notify(player, "Not enough money for +speed!", "error")
			return
		end
		state.money -= Config.SPEED_UPGRADE_COST
		state.walkSpeedBonus = math.min(state.walkSpeedBonus + Config.SPEED_UPGRADE_BONUS, Config.SPEED_UPGRADE_MAX_BONUS)
		Economy.applyWalkSpeed(state)
		GameState.notify(player, "Speed upgraded! Walk speed +" .. tostring(Config.SPEED_UPGRADE_BONUS) .. ".", "success")
	elseif upgradeId == "lock" then
		if state.lockBonus >= Config.LOCK_DURATION_MAX_BONUS then
			GameState.notify(player, "Lock duration is already maxed out!", "error")
			return
		end
		if state.money < Config.LOCK_DURATION_UPGRADE_COST then
			GameState.notify(player, "Not enough money for +lock time!", "error")
			return
		end
		state.money -= Config.LOCK_DURATION_UPGRADE_COST
		state.lockBonus = math.min(state.lockBonus + Config.LOCK_DURATION_BONUS, Config.LOCK_DURATION_MAX_BONUS)
		GameState.notify(player, "Lock upgraded! Your lock now lasts +" .. tostring(Config.LOCK_DURATION_BONUS) .. "s.", "success")
	else
		GameState.notify(player, "Unknown upgrade!", "error")
		return
	end

	GameState.broadcastState(player)
end

return Economy

-- Polish pass 18 Nov: reviewed; no change needed.
