-- GameState.luau
-- Server-side source of truth for per-player state.
-- Keyed by UserId. Holds money, income, rebirths, base assignment,
-- owned brainrots, carried brainrot, lock timers and upgrade bonuses.
-- Also owns the two outbound channels (StateUpdate / Notify) so other
-- server modules never have to find the RemoteEvents themselves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))

local GameState = {}

-- All live player states, keyed by UserId.
GameState.players = {}

-- Bases found in Workspace ("Base1".."Base8"), in order.
-- Filled by init.server.luau via GameState.registerBases().
GameState.bases = {}
-- Which base index is taken by which UserId.
GameState.baseOwners = {}

-- Tsunami countdown (seconds), pushed in by the Tsunami module so the
-- StateUpdate payload can carry it without a circular require.
GameState.tsunamiIn = Config.TSUNAMI_INTERVAL

function GameState.setTsunamiIn(seconds)
	GameState.tsunamiIn = seconds
end

-- ---------------------------------------------------------------------------
-- Bases
-- ---------------------------------------------------------------------------

-- registerBases(baseModels): remember the 8 base Models (already sorted
-- Base1..Base8 by the caller). Does NOT assign them yet.
function GameState.registerBases(baseModels)
	GameState.bases = baseModels
end

-- claimBase(player) -> base Model or nil. Assigns the first free base
-- in join order. Returns nil when all 8 bases are taken.
function GameState.claimBase(player)
	for i, base in ipairs(GameState.bases) do
		if GameState.baseOwners[i] == nil then
			GameState.baseOwners[i] = player.UserId
			return base
		end
	end
	return nil
end

-- releaseBase(player): free the player's base (called on leave).
function GameState.releaseBase(player)
	for i, userId in pairs(GameState.baseOwners) do
		if userId == player.UserId then
			GameState.baseOwners[i] = nil
		end
	end
end

-- getSlotPosition(state, slotIndex) -> Vector3 (top of the slot pad).
-- Slots 1-16 are read from the base Model's "Slot1".."Slot16" pads, so
-- the server never hardcodes base positions. The extra pads (9-16, from
-- the slots upgrade) sit on the floor at local z = -10 / +10, two more
-- rows inside the 24x24 floor, so a brainrot stands fully on the floor
-- instead of half off its edge.
-- If a pad is missing (older place file), slots 9-16 fall back to rows
-- computed from the base's own frame, derived from its Slot1/Slot4/Slot5
-- pads so rotated bases stay correct. (A Model's GetPivot has no rotation
-- without a PrimaryPart, so the frame must come from the pads, not the pivot.)
function GameState.getSlotPosition(state, slotIndex)
	local base = state.base
	if base == nil then
		return Vector3.new(0, 1.25, 0)
	end
	local pad = base:FindFirstChild("Slot" .. tostring(slotIndex))
	if pad and pad:IsA("BasePart") then
		-- Pad is 0.5 tall; its top is Position.y + 0.25.
		return pad.Position + Vector3.new(0, 0.25, 0)
	end
	if slotIndex <= 8 then
		return Vector3.new(0, 1.25, 0)
	end
	-- Fallback (pad missing): extra rows at local z = -10 / +10.
	-- Slot1 is near-right (+9, +6), Slot4 near-left (-9, +6),
	-- Slot5 far-right (+9, -6), so +X runs left->right and +Z far->near.
	local function padPos(name)
		local p = base:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			return p.Position
		end
		return nil
	end
	local s1 = padPos("Slot1")
	local s4 = padPos("Slot4")
	local s5 = padPos("Slot5")
	if s1 == nil or s4 == nil or s5 == nil then
		return Vector3.new(0, 1.25, 0)
	end
	local xDir = s1 - s4
	local zDir = s1 - s5
	if xDir.Magnitude < 1 or zDir.Magnitude < 1 then
		return Vector3.new(0, 1.25, 0)
	end
	xDir = xDir / xDir.Magnitude
	zDir = zDir / zDir.Magnitude
	-- Slot1 sits at local (+9, +6), so the base centre (origin) is
	-- 9 studs back along +X and 6 back along +Z from Slot1.
	local origin = s1 - xDir * 9 - zDir * 6
	local columns = { -9, -3, 3, 9 }
	local extra = slotIndex - 8 -- 1..8
	local row = math.floor((extra - 1) / 4) -- 0 = far row, 1 = near row
	local col = columns[((extra - 1) % 4) + 1]
	local localOffset = Vector3.new(col, 0, row == 0 and -10 or 10)
	local floorPart = base:FindFirstChild("Floor")
	local floorTopY = 1
	if floorPart and floorPart:IsA("BasePart") then
		floorTopY = floorPart.Position.Y + floorPart.Size.Y / 2
	end
	local worldPos = origin + xDir * localOffset.X + zDir * localOffset.Z
	return Vector3.new(worldPos.X, floorTopY + 0.25, worldPos.Z)
end

-- getBaseCentre(state) -> Vector3. Used for "is the player home?" checks.
function GameState.getBaseCentre(state)
	if state.base == nil then
		return Vector3.new(0, 0, 0)
	end
	return state.base:GetPivot().Position
end

-- ---------------------------------------------------------------------------
-- Player lifecycle
-- ---------------------------------------------------------------------------

-- newPlayer(player, base) -> state table.
function GameState.newPlayer(player, base)
	local state = {
		player = player,
		userId = player.UserId,
		money = Config.START_MONEY,
		lifetimeEarned = 0,
		incomePerSec = 0,
		rebirths = 0,
		multiplier = 1,
		slots = Config.BASE_SLOTS_START, -- unlocked slot count (max 16)
		slotCount = 0, -- brainrots currently placed
		base = base,
		-- brainrots: list of { model, charId, mutation, income, slot, ownerUserId }
		brainrots = {},
		carried = nil, -- { model, charId, mutation, income, ownerUserId, carriedSince }
		lockUntil = 0, -- os.time() when the lock expires (0 = not locked)
		lockCooldownUntil = 0,
		gateClosed = false, -- mirrors the physical Gate part; set by Steal
		lockBonus = 0, -- extra lock seconds from upgrades
		walkSpeedBonus = 0, -- extra studs/s from upgrades
		lastSlapAt = 0, -- os.clock() of the last slap, for the cooldown
	}
	GameState.players[player.UserId] = state

	-- Write the owner's name on the base sign, if the world has one.
	if base ~= nil then
		local signLabel = base:FindFirstChild("SignLabel", true)
		if signLabel and signLabel:IsA("TextLabel") then
			signLabel.Text = player.Name .. "'s Base"
		end
	end

	return state
end

-- removePlayer(player): drop state, free the base. The caller destroys
-- the player's placed brainrot models separately (they live under the base).
function GameState.removePlayer(player)
	local state = GameState.players[player.UserId]
	if state ~= nil and state.carried ~= nil then
		-- A leaver's carried brainrot goes back to its owner (handled by
		-- Steal.dropCarried before this is called); here we just clear it.
		state.carried = nil
	end
	GameState.players[player.UserId] = nil
	GameState.releaseBase(player)
end

function GameState.getState(player)
	if player == nil then
		return nil
	end
	return GameState.players[player.UserId]
end

function GameState.getStateByUserId(userId)
	return GameState.players[userId]
end

-- ---------------------------------------------------------------------------
-- Money / income
-- ---------------------------------------------------------------------------

-- addMoney(player, amount): adds (or removes, if negative) money.
-- Never lets money go below 0.
function GameState.addMoney(player, amount)
	local state = GameState.getState(player)
	if state == nil then
		return false
	end
	state.money = math.max(0, state.money + amount)
	return true
end

-- recomputeIncome(player): sums owned brainrots' $/sec into incomePerSec.
-- The rebirth multiplier is applied at tick time, not here, so this stays
-- a clean sum of the base's earning power.
function GameState.recomputeIncome(player)
	local state = GameState.getState(player)
	if state == nil then
		return 0
	end
	local total = 0
	for _, entry in ipairs(state.brainrots) do
		total += entry.income
	end
	state.incomePerSec = total
	state.slotCount = #state.brainrots
	return total
end

-- effectiveIncomePerSec(state): income after the rebirth multiplier.
function GameState.effectiveIncomePerSec(state)
	return math.floor(state.incomePerSec * state.multiplier + 0.5)
end

-- ---------------------------------------------------------------------------
-- Outbound channels (StateUpdate / Notify)
-- ---------------------------------------------------------------------------

local function getRemote(name)
	return ReplicatedStorage:FindFirstChild(name)
end

-- buildStatePayload(state) -> table the client HUD consumes.
function GameState.buildStatePayload(state)
	local now = os.time()
	return {
		money = state.money,
		incomePerSec = GameState.effectiveIncomePerSec(state),
		lifetimeEarned = state.lifetimeEarned,
		rebirths = state.rebirths,
		multiplier = state.multiplier,
		slots = state.slots,
		slotCount = state.slotCount,
		lockRemaining = math.max(0, state.lockUntil - now),
		lockCooldownRemaining = math.max(0, state.lockCooldownUntil - now),
		tsunamiIn = GameState.tsunamiIn,
		carrying = state.carried ~= nil,
		baseName = state.base and state.base.Name or "",
	}
end

-- broadcastState(player): push this player's current state to their client.
function GameState.broadcastState(player)
	local state = GameState.getState(player)
	if state == nil then
		return
	end
	local remote = getRemote("StateUpdate")
	if remote ~= nil then
		remote:FireClient(player, GameState.buildStatePayload(state))
	end
end

-- broadcastAllStates(): push every player's state (used after global
-- events such as the tsunami warning tick).
function GameState.broadcastAllStates()
	for _, state in pairs(GameState.players) do
		GameState.broadcastState(state.player)
	end
end

-- notify(player, text, kind): send a toast to one player.
-- kind is a short tag the client styles: "info" | "success" | "error" | "warning".
function GameState.notify(player, text, kind)
	local remote = getRemote("Notify")
	if remote ~= nil then
		remote:FireClient(player, text, kind or "info")
	end
end

-- notifyAll(text, kind): send a toast to every player.
function GameState.notifyAll(text, kind)
	local remote = getRemote("Notify")
	if remote ~= nil then
		remote:FireAllClients(text, kind or "info")
	end
end

return GameState
