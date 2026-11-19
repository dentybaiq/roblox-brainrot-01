-- Brainrot Bazaar — HUD.
-- Builds the whole client interface in code (ScreenGui "BrainrotGui") and
-- updates it from the server's StateUpdate payload.
--
-- Layout notes: the top-left corner is kept clear — Roblox's menu buttons
-- live there. Money sits top-centre, Rebirth top-right, base info on the
-- left, the tsunami timer bottom-centre, the upgrade shop bottom-right,
-- and transient messages in the centre of the screen.

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))

local HUD = {}

-- Threshold / costs come straight from src/shared/Config.luau (the single
-- source of truth) so the shop and the rebirth bar can never drift from
-- the server's numbers. Titles are built from the same values.
local REBIRTH_THRESHOLD = Config.REBIRTH_THRESHOLD
local SHOP = {
	{ id = "slots", title = "Base Slots +" .. tostring(Config.SLOT_UPGRADE_ADD), cost = Config.SLOT_UPGRADE_COST },
	{ id = "speed", title = "Walk Speed +" .. tostring(Config.SPEED_UPGRADE_BONUS), cost = Config.SPEED_UPGRADE_COST },
	{ id = "lock", title = "Lock Time +" .. tostring(Config.LOCK_DURATION_BONUS) .. "s", cost = Config.LOCK_DURATION_UPGRADE_COST },
}

local formatMoney = Util.formatMoney

local KIND_COLORS = {
	info = Color3.fromRGB(255, 255, 255),
	success = Color3.fromRGB(110, 255, 130),
	error = Color3.fromRGB(255, 95, 95),
	warning = Color3.fromRGB(255, 180, 40),
}

local remotes = nil
local Sound = nil
local Effects = nil

local moneyLabel = nil
local incomeLabel = nil
local rebirthButton = nil
local slotsLabel = nil
local baseTitleLabel = nil
local carryingLabel = nil
local lockButton = nil
local tsunamiLabel = nil
local notifyLabel = nil
local vignette = nil
local shopButtons = {}

local lastMoney = 0
local lastTsunamiIn = nil
local notifyTween = nil

local function makeLabel(parent, name, text, size, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextSize = size
	label.Font = Enum.Font.GothamBold
	label.TextScaled = false
	label.Parent = parent
	return label
end

local function makePanel(parent, name, size, position, anchor)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = anchor or Vector2.new(0, 0)
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	return frame
end

local function makeButton(parent, name, text, size, position, anchor)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = anchor or Vector2.new(0, 0)
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = Color3.fromRGB(45, 140, 70)
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 18
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	button.Parent = parent
	return button
end

function HUD.init(r, sound, effects)
	remotes = r
	Sound = sound
	Effects = effects

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "BrainrotGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = playerGui

	-- Full-screen red vignette, hidden until the tsunami warning flashes it.
	vignette = Instance.new("Frame")
	vignette.Name = "TsunamiVignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.Active = false
	vignette.Visible = false
	vignette.Parent = gui

	-- Top-centre: money (big) + income per second.
	local moneyPanel = makePanel(gui, "MoneyPanel", UDim2.fromOffset(340, 92),
		UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
	moneyPanel.Parent = gui
	moneyLabel = makeLabel(moneyPanel, "MoneyLabel", "$100", 36)
	moneyLabel.Size = UDim2.fromOffset(320, 52)
	moneyLabel.Position = UDim2.fromOffset(10, 4)
	moneyLabel.Parent = moneyPanel
	incomeLabel = makeLabel(moneyPanel, "IncomeLabel", "+$0/s", 20, Color3.fromRGB(110, 255, 130))
	incomeLabel.Size = UDim2.fromOffset(320, 28)
	incomeLabel.Position = UDim2.fromOffset(10, 56)
	incomeLabel.Parent = moneyPanel

	-- Top-right: Rebirth button with progress to the threshold.
	rebirthButton = makeButton(gui, "RebirthButton", "Rebirth (x1.0)\n$0 / " .. formatMoney(REBIRTH_THRESHOLD),
		UDim2.fromOffset(230, 64), UDim2.new(1, -12, 0, 12), Vector2.new(1, 0))
	rebirthButton.BackgroundColor3 = Color3.fromRGB(150, 80, 200)
	rebirthButton.TextSize = 18
	rebirthButton.MouseButton1Click:Connect(function()
		if Sound then
			Sound.play("click")
		end
		if remotes and remotes.Rebirth then
			remotes.Rebirth:FireServer()
		end
	end)

	-- Left panel: base name, slot usage, carrying status, lock button.
	local leftPanel = makePanel(gui, "BasePanel", UDim2.fromOffset(220, 210),
		UDim2.new(0, 12, 0.3, 0))
	leftPanel.Parent = gui
	baseTitleLabel = makeLabel(leftPanel, "BaseTitle", "Your Base", 20)
	baseTitleLabel.Size = UDim2.fromOffset(200, 30)
	baseTitleLabel.Position = UDim2.fromOffset(10, 8)
	baseTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	baseTitleLabel.Parent = leftPanel
	slotsLabel = makeLabel(leftPanel, "SlotsLabel", "Base: 0/" .. tostring(Config.BASE_SLOTS_START), 20)
	slotsLabel.Size = UDim2.fromOffset(200, 30)
	slotsLabel.Position = UDim2.fromOffset(10, 42)
	slotsLabel.TextXAlignment = Enum.TextXAlignment.Left
	slotsLabel.Parent = leftPanel
	carryingLabel = makeLabel(leftPanel, "CarryingLabel", "Carrying a brainrot!\nRun home!", 18,
		Color3.fromRGB(255, 210, 60))
	carryingLabel.Size = UDim2.fromOffset(200, 48)
	carryingLabel.Position = UDim2.fromOffset(10, 76)
	carryingLabel.TextXAlignment = Enum.TextXAlignment.Left
	carryingLabel.Visible = false
	carryingLabel.Parent = leftPanel
	lockButton = makeButton(leftPanel, "LockButton", "Lock Base (" .. tostring(Config.LOCK_DURATION) .. "s)",
		UDim2.fromOffset(200, 46), UDim2.fromOffset(10, 140))
	lockButton.BackgroundColor3 = Color3.fromRGB(40, 110, 200)
	lockButton.MouseButton1Click:Connect(function()
		if Sound then
			Sound.play("click")
		end
		if remotes and remotes.LockBase then
			remotes.LockBase:FireServer()
		end
	end)

	-- Bottom-centre: tsunami timer.
	local tsunamiPanel = makePanel(gui, "TsunamiPanel", UDim2.fromOffset(380, 44),
		UDim2.new(0.5, 0, 1, -14), Vector2.new(0.5, 1))
	tsunamiPanel.Parent = gui
	tsunamiLabel = makeLabel(tsunamiPanel, "TsunamiLabel", "Tsunami in " .. tostring(Config.TSUNAMI_INTERVAL) .. "s", 22)
	tsunamiLabel.Size = UDim2.fromOffset(360, 36)
	tsunamiLabel.Position = UDim2.fromOffset(10, 4)
	tsunamiLabel.Parent = tsunamiPanel

	-- Bottom-right: upgrade shop (3 buttons with costs).
	local shopPanel = makePanel(gui, "ShopPanel", UDim2.fromOffset(250, 196),
		UDim2.new(1, -12, 1, -12), Vector2.new(1, 1))
	shopPanel.Parent = gui
	local shopTitle = makeLabel(shopPanel, "ShopTitle", "Upgrades", 20)
	shopTitle.Size = UDim2.fromOffset(230, 30)
	shopTitle.Position = UDim2.fromOffset(10, 8)
	shopTitle.TextXAlignment = Enum.TextXAlignment.Left
	shopTitle.Parent = shopPanel
	for i, item in ipairs(SHOP) do
		local button = makeButton(shopPanel, "Shop_" .. item.id,
			item.title .. " — " .. formatMoney(item.cost),
			UDim2.fromOffset(230, 42), UDim2.fromOffset(10, 40 + (i - 1) * 50))
		button.BackgroundColor3 = Color3.fromRGB(200, 140, 30)
		button.TextSize = 18
		button.MouseButton1Click:Connect(function()
			if Sound then
				Sound.play("click")
			end
			if remotes and remotes.BuyUpgrade then
				remotes.BuyUpgrade:FireServer(item.id)
			end
		end)
		shopButtons[item.id] = { button = button, cost = item.cost }
	end

	-- Centre: transient message label, hidden until notify() is called.
	notifyLabel = makeLabel(gui, "NotifyLabel", "", 24)
	notifyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	notifyLabel.Position = UDim2.new(0.5, 0, 0.32, 0)
	notifyLabel.Size = UDim2.fromOffset(560, 44)
	notifyLabel.TextTransparency = 1
	notifyLabel.Parent = gui

	-- Bottom-left: keybind hints (static, so new players know the controls).
	local hintLabel = makeLabel(gui, "HintLabel", "E: Buy / Steal    L: Lock Base    F: Slap", 18,
		Color3.fromRGB(220, 220, 220))
	hintLabel.AnchorPoint = Vector2.new(0, 1)
	hintLabel.Position = UDim2.new(0, 12, 1, -14)
	hintLabel.Size = UDim2.fromOffset(360, 28)
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Parent = gui
end

-- state is the StateUpdate payload: money, incomePerSec, lifetimeEarned,
-- rebirths, multiplier, slots, slotCount, lockRemaining,
-- lockCooldownRemaining, tsunamiIn, carrying, baseName.
function HUD.update(state)
	if not moneyLabel then
		return
	end
	state = state or {}

	local money = tonumber(state.money) or 0
	local income = tonumber(state.incomePerSec) or 0
	local lifetime = tonumber(state.lifetimeEarned) or 0
	local rebirths = tonumber(state.rebirths) or 0
	local multiplier = tonumber(state.multiplier) or 1
	local slots = tonumber(state.slots) or 8
	local slotCount = tonumber(state.slotCount) or 0
	local lockRemaining = tonumber(state.lockRemaining) or 0
	local lockCooldown = tonumber(state.lockCooldownRemaining) or 0
	local tsunamiIn = tonumber(state.tsunamiIn)

	-- Money + income.
	if money > lastMoney and Effects then
		Effects.flashMoney(moneyLabel)
	end
	lastMoney = money
	moneyLabel.Text = formatMoney(money)
	incomeLabel.Text = "+" .. formatMoney(income) .. "/s"

	-- Rebirth button: current multiplier + progress to the threshold.
	local progress = math.min(lifetime, REBIRTH_THRESHOLD)
	if lifetime >= REBIRTH_THRESHOLD then
		rebirthButton.Text = "REBIRTH READY! (x" .. string.format("%.1f", multiplier) .. ")"
		rebirthButton.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
	else
		rebirthButton.Text = "Rebirth (x" .. string.format("%.1f", multiplier) .. ")\n"
			.. formatMoney(progress) .. " / " .. formatMoney(REBIRTH_THRESHOLD)
		rebirthButton.BackgroundColor3 = Color3.fromRGB(150, 80, 200)
	end

	-- Left panel: base name, slots, carrying, lock state.
	if state.baseName and state.baseName ~= "" then
		baseTitleLabel.Text = tostring(state.baseName)
	end
	slotsLabel.Text = "Base: " .. slotCount .. "/" .. slots
	carryingLabel.Visible = state.carrying == true

	if lockRemaining > 0 then
		lockButton.Text = "Locked! " .. math.ceil(lockRemaining) .. "s left"
		lockButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
	elseif lockCooldown > 0 then
		lockButton.Text = "Lock ready in " .. math.ceil(lockCooldown) .. "s"
		lockButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
	else
		lockButton.Text = "Lock Base (" .. tostring(Config.LOCK_DURATION) .. "s)  [L]"
		lockButton.BackgroundColor3 = Color3.fromRGB(40, 110, 200)
	end

	-- Tsunami timer.
	if tsunamiIn ~= nil then
		if tsunamiIn <= 10 then
			tsunamiLabel.Text = "TSUNAMI! Run home!"
			tsunamiLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
			if lastTsunamiIn ~= nil and lastTsunamiIn > 10 and Effects then
				Effects.tsunamiFlash(vignette)
			end
		else
			tsunamiLabel.Text = "Tsunami in " .. math.ceil(tsunamiIn) .. "s"
			tsunamiLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
		lastTsunamiIn = tsunamiIn
	end

	-- Dim shop buttons the player cannot afford yet.
	for _, entry in pairs(shopButtons) do
		if money >= entry.cost then
			entry.button.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			entry.button.TextColor3 = Color3.fromRGB(210, 210, 210)
		end
	end
end

-- Centre-screen message that fades out on its own.
-- kind: "info" | "success" | "error" | "warning".
function HUD.notify(text, kind)
	if not notifyLabel then
		return
	end
	if notifyTween then
		notifyTween:Cancel()
		notifyTween = nil
	end
	notifyLabel.Text = tostring(text or "")
	notifyLabel.TextColor3 = KIND_COLORS[kind] or KIND_COLORS.info
	notifyLabel.TextTransparency = 0
	local tween = TweenService:Create(notifyLabel, TweenInfo.new(1.5, Enum.EasingStyle.Quad),
		{ TextTransparency = 1 })
	notifyTween = tween
	task.delay(1.4, function()
		-- Only play this tween if it is still the latest notification.
		if notifyTween == tween then
			tween:Play()
		end
	end)
end

return HUD
