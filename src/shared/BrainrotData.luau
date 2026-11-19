-- BrainrotData.luau
-- The brainrot cast: 12 original characters, 6 rarities, 5 mutations.
-- All names, stats and colours here are original to Brainrot Bazaar.
-- Shared module: the server rolls spawns from this, the client reads it
-- for labels/shop text. No gameplay logic lives here, only data + rolls.

local BrainrotData = {}

-- Rarity definitions. `weight` is the spawn chance (out of 100).
-- `color` is used for name labels; `income`/`cost` are per-character below.
BrainrotData.RARITIES = {
	Common = {
		name = "Common",
		color = Color3.fromRGB(255, 255, 255),
		weight = 40,
	},
	Rare = {
		name = "Rare",
		color = Color3.fromRGB(80, 160, 255),
		weight = 28,
	},
	Epic = {
		name = "Epic",
		color = Color3.fromRGB(190, 90, 255),
		weight = 16,
	},
	Legendary = {
		name = "Legendary",
		color = Color3.fromRGB(255, 150, 40),
		weight = 9,
	},
	Mythic = {
		name = "Mythic",
		color = Color3.fromRGB(255, 60, 60),
		weight = 5,
	},
	Secret = {
		name = "Secret",
		color = Color3.fromRGB(255, 215, 0),
		weight = 2,
	},
}

-- Ordered list of rarity keys, used when rolling a weighted rarity.
BrainrotData.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

-- Mutations multiply a brainrot's $/sec. `chance` is a percentage (out of 100).
BrainrotData.MUTATIONS = {
	None = {
		name = "None",
		multiplier = 1,
		color = Color3.fromRGB(255, 255, 255),
		chance = 70.5,
	},
	Neon = {
		name = "Neon",
		multiplier = 1.5,
		color = Color3.fromRGB(0, 255, 200),
		chance = 15,
	},
	Rainbow = {
		name = "Rainbow",
		multiplier = 2,
		color = Color3.fromRGB(255, 80, 220),
		chance = 8,
	},
	Golden = {
		name = "Golden",
		multiplier = 3,
		color = Color3.fromRGB(255, 215, 0),
		chance = 4,
	},
	Diamond = {
		name = "Diamond",
		multiplier = 5,
		color = Color3.fromRGB(120, 220, 255),
		chance = 1.5,
	},
}

BrainrotData.MUTATION_ORDER = { "None", "Neon", "Rainbow", "Golden", "Diamond" }

-- Characters. `accessory` describes the one signature prop part the
-- factory builds (shape + colour are set in BrainrotFactory).
-- bodyColor / headColor are the main build colours.
BrainrotData.CHARACTERS = {
	NoodleCat = {
		id = "NoodleCat",
		name = "Noodle Cat",
		rarity = "Common",
		cost = 50,
		income = 5,
		bodyColor = Color3.fromRGB(255, 170, 60),
		headColor = Color3.fromRGB(255, 200, 120),
		accessory = "bowl", -- noodle bowl on the head
	},
	PotatoPenguin = {
		id = "PotatoPenguin",
		name = "Potato Penguin",
		rarity = "Common",
		cost = 100,
		income = 8,
		bodyColor = Color3.fromRGB(150, 100, 50),
		headColor = Color3.fromRGB(60, 60, 70),
		accessory = "belly", -- white belly patch
	},
	ToasterTiger = {
		id = "ToasterTiger",
		name = "Toaster Tiger",
		rarity = "Rare",
		cost = 300,
		income = 20,
		bodyColor = Color3.fromRGB(255, 140, 40),
		headColor = Color3.fromRGB(255, 180, 90),
		accessory = "toaster", -- grey toaster box on its back
	},
	SockMonkey = {
		id = "SockMonkey",
		name = "Sock Monkey",
		rarity = "Rare",
		cost = 500,
		income = 30,
		bodyColor = Color3.fromRGB(140, 90, 50),
		headColor = Color3.fromRGB(180, 120, 70),
		accessory = "sock", -- red sock on one arm
	},
	DiscoDuck = {
		id = "DiscoDuck",
		name = "Disco Duck",
		rarity = "Epic",
		cost = 1000,
		income = 60,
		bodyColor = Color3.fromRGB(255, 220, 40),
		headColor = Color3.fromRGB(255, 240, 120),
		accessory = "discoball", -- mirror ball held above its head
	},
	LlamaDJ = {
		id = "LlamaDJ",
		name = "Llama DJ",
		rarity = "Epic",
		cost = 1500,
		income = 90,
		bodyColor = Color3.fromRGB(240, 240, 240),
		headColor = Color3.fromRGB(255, 255, 255),
		accessory = "headphones", -- chunky DJ headphones
	},
	GiraffeAstronaut = {
		id = "GiraffeAstronaut",
		name = "Giraffe Astronaut",
		rarity = "Legendary",
		cost = 3000,
		income = 150,
		bodyColor = Color3.fromRGB(255, 210, 80),
		headColor = Color3.fromRGB(255, 230, 140),
		accessory = "helmet", -- white astronaut helmet sphere
	},
	WizardWalrus = {
		id = "WizardWalrus",
		name = "Wizard Walrus",
		rarity = "Legendary",
		cost = 5000,
		income = 220,
		bodyColor = Color3.fromRGB(160, 160, 170),
		headColor = Color3.fromRGB(190, 190, 200),
		accessory = "wizardhat", -- purple wizard hat cone
	},
	DragonBarista = {
		id = "DragonBarista",
		name = "Dragon Barista",
		rarity = "Mythic",
		cost = 10000,
		income = 400,
		bodyColor = Color3.fromRGB(220, 50, 50),
		headColor = Color3.fromRGB(255, 90, 60),
		accessory = "coffeecup", -- coffee cup in one claw
	},
	UnicornMechanic = {
		id = "UnicornMechanic",
		name = "Unicorn Mechanic",
		rarity = "Mythic",
		cost = 15000,
		income = 600,
		bodyColor = Color3.fromRGB(245, 245, 255),
		headColor = Color3.fromRGB(255, 255, 255),
		accessory = "wrench", -- silver wrench across its back
	},
	GoldenGrandma = {
		id = "GoldenGrandma",
		name = "Golden Grandma",
		rarity = "Secret",
		cost = 30000,
		income = 1000,
		bodyColor = Color3.fromRGB(255, 205, 60),
		headColor = Color3.fromRGB(255, 220, 130),
		accessory = "bun", -- grey hair bun
	},
	InfiniteSandwich = {
		id = "InfiniteSandwich",
		name = "The Infinite Sandwich",
		rarity = "Secret",
		cost = 50000,
		income = 1500,
		bodyColor = Color3.fromRGB(220, 180, 110),
		headColor = Color3.fromRGB(240, 210, 150),
		accessory = "lettuce", -- green lettuce layer
	},
}

-- Characters grouped by rarity, for uniform picks inside a rarity.
local byRarity = {}
for _id, char in pairs(BrainrotData.CHARACTERS) do
	byRarity[char.rarity] = byRarity[char.rarity] or {}
	table.insert(byRarity[char.rarity], char)
end
BrainrotData.BY_RARITY = byRarity

-- getCharacter(id) -> character table or nil.
function BrainrotData.getCharacter(id)
	return BrainrotData.CHARACTERS[id]
end

-- getRarity(name) -> rarity table or nil.
function BrainrotData.getRarity(name)
	return BrainrotData.RARITIES[name]
end

-- rollCharacter() -> character table.
-- Weighted by rarity (Common 40% ... Secret 2%), uniform inside a rarity.
function BrainrotData.rollCharacter()
	local roll = math.random() * 100
	local acc = 0
	local pickedRarity = "Common"
	for _, rarityName in ipairs(BrainrotData.RARITY_ORDER) do
		acc += BrainrotData.RARITIES[rarityName].weight
		if roll < acc then
			pickedRarity = rarityName
			break
		end
	end
	local pool = BrainrotData.BY_RARITY[pickedRarity]
	return pool[math.random(1, #pool)]
end

-- rollMutation() -> mutation key ("None", "Neon", "Rainbow", "Golden", "Diamond").
function BrainrotData.rollMutation()
	local roll = math.random() * 100
	local acc = 0
	for _, mutationName in ipairs(BrainrotData.MUTATION_ORDER) do
		acc += BrainrotData.MUTATIONS[mutationName].chance
		if roll < acc then
			return mutationName
		end
	end
	return "None"
end

-- incomeFor(char, mutation) -> $/sec after the mutation multiplier.
function BrainrotData.incomeFor(char, mutation)
	local mut = BrainrotData.MUTATIONS[mutation] or BrainrotData.MUTATIONS.None
	return math.floor(char.income * mut.multiplier + 0.5)
end

return BrainrotData

-- Polish pass 18 Nov: reviewed; no change needed.
