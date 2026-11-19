-- BrainrotFactory.luau
-- Builds a brainrot Model from a character id + mutation.
-- Every brainrot is ~8-12 parts: a Body (PrimaryPart), a Head, two eyes,
-- two feet, one accessory part, a BillboardGui label and a ProximityPrompt.
-- Mutations tint the body and (for Neon/Rainbow/Golden/Diamond) add a glow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local Util = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"))

local BrainrotFactory = {}

local function newPart(name, size, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	return part
end

-- buildAccessory(char, body, head, mutationColor) -> Part or nil.
-- One signature prop per character, kept simple and chunky.
local function buildAccessory(char, mutationColor)
	local kind = char.accessory
	local part

	if kind == "bowl" then
		-- Noodle Cat: a noodle bowl on its head.
		part = newPart("Accessory", Vector3.new(1.6, 0.6, 1.6), Color3.fromRGB(220, 60, 60))
		part.Shape = Enum.PartType.Cylinder
	elseif kind == "belly" then
		-- Potato Penguin: white belly patch on the front.
		part = newPart("Accessory", Vector3.new(1.4, 1.6, 0.3), Color3.fromRGB(245, 245, 245))
	elseif kind == "toaster" then
		-- Toaster Tiger: grey toaster box on its back.
		part = newPart("Accessory", Vector3.new(1.8, 1.2, 1.0), Color3.fromRGB(150, 150, 160), Enum.Material.Metal)
	elseif kind == "sock" then
		-- Sock Monkey: a red sock on one arm.
		part = newPart("Accessory", Vector3.new(0.6, 1.4, 0.6), Color3.fromRGB(220, 40, 40))
	elseif kind == "discoball" then
		-- Disco Duck: a mirror ball floating above its head.
		part = newPart("Accessory", Vector3.new(1.0, 1.0, 1.0), Color3.fromRGB(200, 200, 220), Enum.Material.Metal)
		part.Shape = Enum.PartType.Ball
	elseif kind == "headphones" then
		-- Llama DJ: chunky headphones (a band + two cups in one bar).
		part = newPart("Accessory", Vector3.new(2.2, 0.5, 0.5), Color3.fromRGB(40, 40, 50))
	elseif kind == "helmet" then
		-- Giraffe Astronaut: white helmet sphere around the head.
		part = newPart("Accessory", Vector3.new(2.4, 2.4, 2.4), Color3.fromRGB(240, 250, 255), Enum.Material.Glass)
		part.Shape = Enum.PartType.Ball
		part.Transparency = 0.35
	elseif kind == "wizardhat" then
		-- Wizard Walrus: purple wizard hat cone.
		part = newPart("Accessory", Vector3.new(1.6, 1.8, 1.6), Color3.fromRGB(120, 40, 200))
		part.Shape = Enum.PartType.Cylinder
	elseif kind == "coffeecup" then
		-- Dragon Barista: a coffee cup in one claw.
		part = newPart("Accessory", Vector3.new(0.8, 1.0, 0.8), Color3.fromRGB(255, 255, 255))
		part.Shape = Enum.PartType.Cylinder
	elseif kind == "wrench" then
		-- Unicorn Mechanic: a silver wrench slung across its back.
		part = newPart("Accessory", Vector3.new(2.0, 0.4, 0.4), Color3.fromRGB(180, 180, 190), Enum.Material.Metal)
	elseif kind == "bun" then
		-- Golden Grandma: a grey hair bun on top.
		part = newPart("Accessory", Vector3.new(1.0, 1.0, 1.0), Color3.fromRGB(150, 150, 150))
		part.Shape = Enum.PartType.Ball
	elseif kind == "lettuce" then
		-- The Infinite Sandwich: a green lettuce layer on top.
		part = newPart("Accessory", Vector3.new(2.2, 0.4, 2.2), Color3.fromRGB(80, 200, 80))
	end

	if part ~= nil and mutationColor ~= nil then
		-- Mutations tint the accessory slightly so the glow reads at a glance.
		part.Color = mutationColor
	end
	return part
end

-- makeLabel(model, char, mutation, income): attaches the BillboardGui.
-- Line 1: name (rarity colour). Line 2: "$X/s" + mutation tag.
function BrainrotFactory.makeLabel(model, char, mutation, income)
	local rarity = BrainrotData.getRarity(char.rarity)
	local mut = BrainrotData.MUTATIONS[mutation] or BrainrotData.MUTATIONS.None

	local gui = Instance.new("BillboardGui")
	gui.Name = "BrainrotLabel"
	gui.Size = UDim2.new(0, 160, 0, 64)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = char.name
	nameLabel.TextColor3 = rarity.color
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.Parent = gui

	local incomeText = Util.formatMoney(income) .. "/s"
	if mutation ~= "None" then
		incomeText = incomeText .. "  [" .. mut.name .. "]"
	end
	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeLabel"
	incomeLabel.Size = UDim2.new(1, 0, 0.5, 0)
	incomeLabel.Position = UDim2.new(0, 0, 0.5, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = incomeText
	incomeLabel.TextColor3 = mut.color
	incomeLabel.TextScaled = true
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.TextStrokeTransparency = 0.2
	incomeLabel.Parent = gui

	gui.Parent = model
	return gui
end

-- buildBrainrot(charId, mutation) -> Model.
-- PrimaryPart is "Body". The model is anchored; movers (Conveyor/Steal)
-- reposition it by setting the PrimaryPart CFrame.
function BrainrotFactory.buildBrainrot(charId, mutation)
	local char = BrainrotData.getCharacter(charId)
	assert(char ~= nil, "BrainrotFactory: unknown character id " .. tostring(charId))
	mutation = mutation or "None"
	local mut = BrainrotData.MUTATIONS[mutation] or BrainrotData.MUTATIONS.None
	local income = BrainrotData.incomeFor(char, mutation)

	local model = Instance.new("Model")
	model.Name = char.name

	-- Mutation tint: mutated brainrots glow in their mutation colour.
	local bodyColor = char.bodyColor
	local headColor = char.headColor
	if mutation ~= "None" then
		bodyColor = mut.color:Lerp(char.bodyColor, 0.45)
		headColor = mut.color:Lerp(char.headColor, 0.45)
	end

	-- Body (PrimaryPart): 2 x 2 x 2, centred at y = 1 above the ground
	-- the model stands on (callers place PrimaryPart at slotTop + 1).
	local body = newPart("Body", Vector3.new(2, 2, 2), bodyColor)
	body.CFrame = CFrame.new(0, 1, 0)
	body.CanCollide = true
	body.Parent = model
	model.PrimaryPart = body

	-- Head: 1.6 cube sitting on top of the body.
	local head = newPart("Head", Vector3.new(1.6, 1.6, 1.6), headColor)
	head.CFrame = CFrame.new(0, 2.8, 0)
	head.Parent = model

	-- Eyes: two small dark spheres on the front of the head.
	for _, side in ipairs({ -0.4, 0.4 }) do
		local eye = newPart("Eye", Vector3.new(0.35, 0.35, 0.35), Color3.fromRGB(20, 20, 20))
		eye.Shape = Enum.PartType.Ball
		eye.CFrame = CFrame.new(side, 2.9, 0.85)
		eye.Parent = model
	end

	-- Feet: two small blocks under the body.
	for _, side in ipairs({ -0.55, 0.55 }) do
		local foot = newPart("Foot", Vector3.new(0.7, 0.4, 1.0), Color3.fromRGB(40, 40, 40))
		foot.CFrame = CFrame.new(side, 0.2, 0.2)
		foot.Parent = model
	end

	-- Accessory, positioned per kind relative to the body/head.
	local accessory = buildAccessory(char, mutation ~= "None" and mut.color or nil)
	if accessory ~= nil then
		local kind = char.accessory
		if kind == "bowl" or kind == "bun" or kind == "wizardhat" then
			accessory.CFrame = CFrame.new(0, 3.9, 0)
		elseif kind == "belly" then
			accessory.CFrame = CFrame.new(0, 1.0, 1.05)
		elseif kind == "toaster" then
			accessory.CFrame = CFrame.new(0, 1.6, -1.3)
		elseif kind == "sock" then
			accessory.CFrame = CFrame.new(1.3, 1.0, 0)
		elseif kind == "discoball" then
			accessory.CFrame = CFrame.new(0, 4.6, 0)
		elseif kind == "headphones" then
			accessory.CFrame = CFrame.new(0, 3.5, 0)
		elseif kind == "helmet" then
			accessory.CFrame = CFrame.new(0, 2.8, 0)
		elseif kind == "coffeecup" then
			accessory.CFrame = CFrame.new(1.3, 0.6, 0.4)
		elseif kind == "wrench" then
			accessory.CFrame = CFrame.new(0, 1.8, -1.2)
			accessory.CFrame = accessory.CFrame * CFrame.Angles(0, 0, math.rad(35))
		elseif kind == "lettuce" then
			accessory.CFrame = CFrame.new(0, 2.1, 0)
		end
		accessory.Parent = model
	end

	-- Mutation glow: a soft neon shell so mutated brainrots stand out.
	if mutation ~= "None" then
		local glow = newPart("Glow", Vector3.new(2.3, 2.3, 2.3), mut.color, Enum.Material.Neon)
		glow.Transparency = 0.75
		glow.CFrame = CFrame.new(0, 1, 0)
		glow.Parent = model
	end

	-- Label.
	BrainrotFactory.makeLabel(model, char, mutation, income)

	-- ProximityPrompt: the caller (Conveyor / Economy) sets ActionText
	-- ("Buy" on the belt, "Steal" on another player's base) and connects
	-- Triggered. Hold time is 0 so a single E press works.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BrainrotPrompt"
	prompt.ActionText = "Buy"
	prompt.ObjectText = char.name .. " — " .. Util.formatMoney(char.cost)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	-- Store the spawn data on the model so any module can read it back.
	model:SetAttribute("CharId", char.id)
	model:SetAttribute("Mutation", mutation)
	model:SetAttribute("Cost", char.cost)
	model:SetAttribute("Income", income)

	return model
end

return BrainrotFactory

-- Polish pass 18 Nov: reviewed; no change needed.
