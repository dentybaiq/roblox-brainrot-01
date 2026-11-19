-- Config.luau
-- All tunable constants for Brainrot Bazaar (server-authoritative).
-- Single source of truth: every server module reads its numbers from here.

local Config = {}

-- Starting money for a fresh player (and after a rebirth reset).
Config.START_MONEY = 100

-- How often (seconds) the money tick runs.
Config.TICK_SECONDS = 1

-- Conveyor belt behaviour.
Config.CONVEYOR_SPEED = 6 -- studs per second, +X direction
Config.CONVEYOR_SPAWN_INTERVAL = 6 -- seconds between spawn attempts
Config.MAX_CONVEYOR = 6 -- max brainrots on the belt at once
Config.CONVEYOR_START_X = -70
Config.CONVEYOR_END_X = 70
Config.CONVEYOR_Y = 2 -- PrimaryPart height while riding the belt
Config.CONVEYOR_Z = 0

-- Base slots.
Config.BASE_SLOTS_START = 8
Config.SLOT_UPGRADE_COST = 2000
Config.SLOT_UPGRADE_ADD = 4
Config.MAX_SLOTS = 16

-- Walk-speed upgrade.
Config.SPEED_UPGRADE_COST = 1500
Config.SPEED_UPGRADE_BONUS = 4 -- studs/s per purchase
Config.SPEED_UPGRADE_MAX_BONUS = 12
Config.BASE_WALK_SPEED = 16

-- Base lock (defence).
Config.LOCK_DURATION = 20 -- seconds a lock lasts
Config.LOCK_DURATION_UPGRADE_COST = 1000
Config.LOCK_DURATION_BONUS = 10 -- extra seconds per purchase
Config.LOCK_DURATION_MAX_BONUS = 30
Config.LOCK_COOLDOWN = 60 -- seconds before the base can be locked again

-- Meme Tsunami.
Config.TSUNAMI_INTERVAL = 90 -- seconds between waves
Config.TSUNAMI_WARNING = 10 -- seconds of warning before the wave hits
Config.TSUNAMI_SWEEP_SECONDS = 4 -- how long the wave takes to cross the plaza

-- Rebirth.
Config.REBIRTH_THRESHOLD = 25000 -- lifetime $ earned needed to rebirth
Config.REBIRTH_MULTIPLIER = 0.5 -- +50% income per rebirth
Config.REBIRTH_MAX_MULTIPLIER = 5 -- income multiplier cap

-- Stealing.
Config.CARRY_SPEED_MULTIPLIER = 0.7 -- thief walks slower while carrying
Config.SLAP_RANGE = 8 -- studs
Config.SLAP_COOLDOWN = 3 -- seconds between slaps
Config.STEAL_RETURN_TIMEOUT = 30 -- seconds to reach your base or the brainrot returns

return Config

-- Polish pass 18 Nov: reviewed; no change needed.
