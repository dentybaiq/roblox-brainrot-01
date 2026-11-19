-- init.server.luau
-- Entry point for Brainrot Bazaar (server). Thin by design: it finds the
-- 8 bases in Workspace, creates the RemoteEvents, wires the modules
-- together, assigns bases in join order and starts the game loops.
-- All gameplay logic lives in the sibling modules.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- World layout FIRST: re-apply every static world part's CFrame.
-- Rojo 7.7.1 writes CFrame into the place file but Studio still renders
-- the world at the origin (baseplate only), so this makes Play mode
-- correct. Must run before anything reads part positions (GameState
-- slot pads, base pivots, spawn).
local WorldLayout = require(script:WaitForChild("WorldLayout"))
WorldLayout.apply()

local GameState = require(script:WaitForChild("GameState"))
local Conveyor = require(script:WaitForChild("Conveyor"))
local Economy = require(script:WaitForChild("Economy"))
local Steal = require(script:WaitForChild("Steal"))
local Tsunami = require(script:WaitForChild("Tsunami"))
local Remotes = require(script:WaitForChild("Remotes"))

-- ---------------------------------------------------------------------------
-- Bases: find Workspace "Base1".."Base8" (sorted, in order). The server
-- never hardcodes base positions — slot pads are read from the models.
-- ---------------------------------------------------------------------------

local function findBases()
	local bases = {}
	for i = 1, 8 do
		local base = Workspace:FindFirstChild("Base" .. tostring(i))
		if base ~= nil and base:IsA("Model") then
			table.insert(bases, base)
		else
			warn("[Brainrot Bazaar] Missing base model: Base" .. tostring(i))
		end
	end
	return bases
end

GameState.registerBases(findBases())

-- ---------------------------------------------------------------------------
-- Wiring: RemoteEvents first (GameState fires through them), then the
-- cross-module handlers that would otherwise be circular requires.
-- ---------------------------------------------------------------------------

Remotes.create()
Conveyor.setBuyHandler(Economy.buyBrainrot)
Economy.setStealHandler(Steal.stealBrainrot)

-- ---------------------------------------------------------------------------
-- Players
-- ---------------------------------------------------------------------------

local function onCharacterAdded(player, character)
	-- Re-apply the walk-speed bonus after every (re)spawn.
	local state = GameState.getState(player)
	if state ~= nil then
		Economy.applyWalkSpeed(state)
	end
end

local function onPlayerAdded(player)
	local base = GameState.claimBase(player)
	if base == nil then
		player:Kick("All 8 bases are taken — try again later!")
		return
	end

	local state = GameState.newPlayer(player, base)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	-- In case the character already exists by the time we connect.
	if player.Character ~= nil then
		onCharacterAdded(player, player.Character)
	end

	GameState.broadcastState(player)
	GameState.notify(player, "Welcome to Brainrot Bazaar! Buy brainrots off the conveyor (press E).", "info")
end

local function onPlayerRemoving(player)
	local state = GameState.getState(player)
	if state ~= nil then
		-- Hand any carried brainrot back before the player leaves.
		if state.carried ~= nil then
			Steal.dropCarried(state, "")
		end
		-- Clear their placed brainrots from the base.
		for _, entry in ipairs(state.brainrots) do
			if entry.model ~= nil and entry.model.Parent ~= nil then
				entry.model:Destroy()
			end
		end
		state.brainrots = {}
		-- Re-open their gate so the base is clean for the next player.
		if state.base ~= nil then
			local gate = state.base:FindFirstChild("Gate")
			if gate ~= nil and gate:IsA("BasePart") then
				gate.Transparency = 1
				gate.CanCollide = false
			end
			local signLabel = state.base:FindFirstChild("SignLabel", true)
			if signLabel and signLabel:IsA("TextLabel") then
				signLabel.Text = "Empty Base"
			end
		end
	end
	GameState.removePlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
-- Players already in-game when this script runs (Studio play-solo edge).
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- ---------------------------------------------------------------------------
-- Game loops
-- ---------------------------------------------------------------------------

Conveyor.start()
Economy.startMoneyLoop()
Steal.start()
Tsunami.start()

print("[Brainrot Bazaar] Server started with " .. tostring(#GameState.bases) .. " bases.")

-- Polish pass 18 Nov: reviewed; no change needed.
