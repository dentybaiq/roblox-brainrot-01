# DESIGN — Brainrot Bazaar (roblox-brainrot-01)

## Game
**Name:** Brainrot Bazaar. A 3D Steal-a-Brainrot-style game. Original characters, names and world — no copying from existing games.
**Loop:** Brainrots parade on a central conveyor. Walk up, press E to buy one (if you can afford it). It goes to a slot on your base and earns $/sec (money ticks up, HUD shows it). Buy rarer ones, upgrade your base, steal from other players (carry it home while they chase/slap you), lock your base to defend it. Every ~90s a Meme Tsunami sweeps the plaza — if you are outside your base when it hits, you are swept back to spawn and drop anything you carry. Reach $25,000 lifetime earned to Rebirth: reset money + base, gain a permanent +50% income multiplier (stacks, max x5).

## World (default.project.json) — one source of truth for positions
- Baseplate 512x20x512, top at y=0 (keep starter). Plaza: flat paved Part 160x1x160 centred at (0, 0.5, 0), light grey.
- Conveyor: a straight belt across the middle, Part 140x1x8 at (0, 0.5, 0), dark grey with lighter chevron strips. Brainrots spawn at x=-70, walk +X to x=+70, despawn. (Path is z=0, y=2 — brainrot PrimaryPart sits at y=2 so it stands on the belt.)
- Fountain at centre (0, 0, 0): basin cylinder + blue water cylinder + centre spout. (Conveyor passes UNDER/AROUND it — put the fountain at (0,0,-20) instead so it does not block the belt. Fountain at (0, 0, -20).)
- SpawnLocation at (0, 1, 40), a 8x1x8 pad. Players spawn there. CharacterAutoLoads = true (change from starter's false).
- 8 bases, one per player, arranged in a ring radius 70 around origin. Each base is a Model named "Base1".."Base8" with:
  - Floor: Part 24x2x24, top at y=1 (so Position y=0), coloured per base (see palette).
  - 16 Slot pads: Parts 4x0.5x4 named "Slot1".."Slot16", tops at y=1.25, arranged in 4 rows of 4 on the floor (local offsets: rows at z=-10, -6, +6 and +10 relative to base centre, columns at x=-9,-3,+3,+9). Slots 1-8 are the starting rows (z=-6/+6); slots 9-16 are the extra rows from the slots upgrade (z=-10/+10, still fully on the 24x24 floor — never at the edge). The server reads every pad's Position from the model, never hardcodes it; a pad-derived frame is the fallback if a pad is missing (a Model's GetPivot has no rotation without a PrimaryPart, so the pivot must NOT be used for rotated bases). Brainrots stand on slots (PrimaryPart y = slot top + ~2).
  - Gate: a Part 24x6x1 at the base edge facing the centre (the "front"), named "Gate". When locked it is solid/closed; when unlocked it is transparent/open (server toggles Transparency + CanCollide).
  - Sign: a Part 8x3x0.5 at the back of the base with a SurfaceGui + TextLabel named "SignLabel" (server writes the owner's name on it).
  - Back wall + 2 side walls: low Parts (height 4) around the base except the front (gate side).
  - Each base faces the centre: rotate the whole base Model so its front (gate) points at (0,0,0).
  - Base positions (centre of floor) and facing (yaw so front faces origin):
    - Base1 (0, 0, -70), yaw 180 (front faces +Z toward origin)
    - Base2 (49.5, 0, -49.5), yaw 135
    - Base3 (70, 0, 0), yaw 90
    - Base4 (49.5, 0, 49.5), yaw 45
    - Base5 (0, 0, 70), yaw 0
    - Base6 (-49.5, 0, 49.5), yaw -45
    - Base7 (-70, 0, 0), yaw -90
    - Base8 (-49.5, 0, -49.5), yaw -135
  - Base colours (one per base, bright and distinct): 1 Red, 2 Orange, 3 Yellow, 4 Green, 5 Blue, 6 Purple, 7 Pink, 8 Cyan.
  - IMPORTANT: the server must NOT hardcode base positions. On startup it finds Workspace bases "Base1".."Base8", reads each Slot pad's Position, and assigns bases to players in join order. The world writer and the server writer both use the positions above — they must match.
- Decorations (keep total instances low, aim < 1000): 8 trees (trunk cylinder + leaf sphere), 6 lamps (pole + glowing sphere), 3 market stalls (counter + 4 posts + awning), low perimeter walls (8 segments) bounding the plaza, a few colourful crates/barrels. Lighting: bright, cheerful (Brightness 2, warm Ambient).
- Services in default.project.json: Players (CharacterAutoLoads true), ServerScriptService/Server -> src/server, StarterPlayer/StarterPlayerScripts/Client -> src/client, ReplicatedStorage/Shared -> src/shared, ReplicatedStorage/Remotes -> src/remotes (RemoteEvents are created by the server at runtime instead — do NOT put RemoteEvent instances in the project; the server creates them. So NO src/remotes folder; server creates RemoteEvents under ReplicatedStorage at runtime).
- Project name in default.project.json: "brainrot-bazaar" (rename from "house-dodge").

## Brainrot cast (src/shared/BrainrotData.luau) — original characters
Rarities (name, colour for labels, base $/sec, cost):
- Common (white): Noodle Cat $5/s cost $50; Potato Penguin $8/s cost $100
- Rare (blue): Toaster Tiger $20/s cost $300; Sock Monkey $30/s cost $500
- Epic (purple): Disco Duck $60/s cost $1000; Llama DJ $90/s cost $1500
- Legendary (orange): Giraffe Astronaut $150/s cost $3000; Wizard Walrus $220/s cost $5000
- Mythic (red): Dragon Barista $400/s cost $10000; Unicorn Mechanic $600/s cost $15000
- Secret (gold): Golden Grandma $1000/s cost $30000; The Infinite Sandwich $1500/s cost $50000
Spawn weights (rarer = less likely): Common 40%, Rare 28%, Epic 16%, Legendary 9%, Mythic 5%, Secret 2%. Within a rarity pick uniformly.
Mutations (random on spawn, multiply $/sec): None x1 (70.5%), Neon x1.5 (15%), Rainbow x2 (8%), Golden x3 (4%), Diamond x5 (1.5%). Mutation shown in the label and as a coloured glow/part tint.
Each character: a distinct body colour + head colour + one accessory part (simple shape, e.g. Noodle Cat = orange body + bowl on head; Potato Penguin = brown body + white belly; Toaster Tiger = orange body + grey toaster box; Sock Monkey = brown body + red sock; Disco Duck = yellow body + disco ball; Llama DJ = white body + headphones; Giraffe Astronaut = yellow body + white helmet sphere; Wizard Walrus = grey body + purple hat cone; Dragon Barista = red body + coffee cup; Unicorn Mechanic = white body + wrench; Golden Grandma = gold body + grey bun; The Infinite Sandwich = tan body + lettuce green layer). Keep each brainrot to ~8-12 parts.

## Shared modules (src/shared/)
- BrainrotData.luau: RARITIES table, CHARACTERS table (id, name, rarity, cost, income, bodyColor, headColor, accessory description), MUTATIONS table (name, multiplier, colour, chance), helper functions: getCharacter(id), rollCharacter() (weighted by rarity), rollMutation(), incomeFor(char, mutation).
- Config.luau: constants — START_MONEY 100, TICK_SECONDS 1, CONVEYOR_SPEED 6 (studs/s), CONVEYOR_SPAWN_INTERVAL 6 (s), MAX_CONVEYOR 6, BASE_SLOTS_START 8, SLOT_UPGRADE_COST 2000, SLOT_UPGRADE_ADD 4, SPEED_UPGRADE_COST 1500, SPEED_UPGRADE_BONUS 4 (studs/s, max +12), LOCK_DURATION 20, LOCK_DURATION_UPGRADE_COST 1000, LOCK_DURATION_BONUS 10, LOCK_COOLDOWN 60, TSUNAMI_INTERVAL 90, TSUNAMI_WARNING 10, REBIRTH_THRESHOLD 25000, REBIRTH_MULTIPLIER 0.5 (each rebirth adds +50%), REBIRTH_MAX_MULTIPLIER 5, CARRY_SPEED_MULTIPLIER 0.7, SLAP_RANGE 8, SLAP_COOLDOWN 3, STEAL_RETURN_TIMEOUT 30 (s to reach your base or the stolen brainrot returns to its owner's base).
- Util.luau: formatMoney(n) -> "$1,234", formatTime(s) -> "1:23", clamp, etc.

## Server (src/server/) — single source of truth for state
- init.server.luau: entry. Requires GameState, Conveyor, Economy, Steal, Tsunami, Remotes. Sets up bases (find Base1..8, assign on PlayerAdded), starts loops. Keep it thin — logic lives in modules.
- GameState.luau (ModuleScript): per-player data table keyed by UserId: {money, lifetimeEarned, incomePerSec, rebirths, multiplier, slots, slotCount, base (Model), brainrots (list of {id, charId, mutation, slot}), carried (brainrot or nil), lockUntil, lockCooldownUntil, walkSpeedBonus, lockBonus}. Functions: newPlayer(player), removePlayer(player), getState(player), addMoney(player, n), recomputeIncome(player).
- BrainrotFactory.luau (ModuleScript): buildBrainrot(charId, mutation) -> Model. Creates Model with PrimaryPart Body, Head, eyes, accessory, BillboardGui label (name, rarity coloured, "$X/s", mutation tag), ProximityPrompt (ActionText "Buy"/"Steal", ObjectText name). Returns model. Also makeLabel(model, char, mutation, income).
- Conveyor.luau (ModuleScript): spawns brainrots on a timer (every CONVEYOR_SPAWN_INTERVAL if fewer than MAX_CONVEYOR on the belt), moves them +X at CONVEYOR_SPEED (CFrame on PrimaryPart, anchored, with a small bob), despawns at x>+70. Tracks conveyor brainrots {model, charId, mutation, cost, income}. Exposes getConveyorBrainrots(), removeBrainrot(model).
- Economy.luau (ModuleScript): money tick loop (every TICK_SECONDS: for each player, money += incomePerSec * multiplier; lifetimeEarned += same; fire StateUpdate). buyBrainrot(player, conveyorBrainrot): checks money >= cost, deducts, removes from conveyor, places on player's first free slot (or errors "No free slot"), sets income. rebirth(player): checks lifetimeEarned >= REBIRTH_THRESHOLD, resets money=START_MONEY, clears base brainrots, rebirths+=1, multiplier=min(1 + rebirths*REBIRTH_MULTIPLIER, REBIRTH_MAX_MULTIPLIER). buyUpgrade(player, upgradeId): "slots" (cost SLOT_UPGRADE_COST, +SLOT_UPGRADE_ADD slots, max 16), "speed" (cost SPEED_UPGRADE_COST, +SPEED_UPGRADE_BONUS, max +12), "lock" (cost LOCK_DURATION_UPGRADE_COST, +LOCK_DURATION_BONUS, max +30).
- Steal.luau (ModuleScript): stealBrainrot(player, brainrotModel): checks target base not locked and brainrot belongs to another player; removes from owner's slot, gives to thief as carried (attach to thief: weld/position above head or set PrimaryPart to follow the thief; simplest: set the brainrot's PrimaryPart CFrame above the thief's head each frame while carried, and set thief WalkSpeed * CARRY_SPEED_MULTIPLIER). placeCarried(player): when a carrying player enters their own base (touch/region check each 0.5s), place on first free slot (or drop if no slot). slap(attacker, target): if target is carrying and within SLAP_RANGE and attacker cooldown ready, target drops the carried brainrot (it returns to its original owner's first free slot, or despawns to conveyor if no slot). lockBase(player): if cooldown ready, lockUntil = now + LOCK_DURATION + lockBonus; gate closes (Transparency 0, CanCollide true); unlock when time passes (gate opens). isBaseLocked(player) helper.
- Tsunami.luau (ModuleScript): timer loop (TSUNAMI_INTERVAL). At TSUNAMI_INTERVAL - TSUNAMI_WARNING, fire warning to all clients (Notify + StateUpdate tsunamiTimer). At 0, spawn a big wave: a large translucent blue Part that sweeps across the plaza from z=-80 to z=+80 (or x=-80 to +80) over ~4s, then despawn. Any player NOT inside their own base region when the wave passes their position gets swept: teleport to SpawnLocation, drop carried brainrot (returns to original owner), brief speed penalty. Players inside their base are safe. Reset timer.
- Remotes.luau (ModuleScript): creates RemoteEvents under ReplicatedStorage: "StateUpdate" (server->client: money, incomePerSec, lifetimeEarned, rebirths, multiplier, slots, slotCount, lockRemaining, lockCooldownRemaining, tsunamiIn, carrying (bool), baseName), "Notify" (server->client: text, kind), "LockBase" (client->server), "Rebirth" (client->server), "BuyUpgrade" (client->server, upgradeId string), "Slap" (client->server). Wires OnServerEvent to Economy/Steal functions. ProximityPrompts (Buy on conveyor brainrots, Steal on other players' base brainrots) are created by BrainrotFactory/Conveyor and handled on the server via Prompt.Triggered -> Economy.buyBrainrot / Steal.stealBrainrot.

## Client (src/client/)
- Game.client.luau: entry. Requires HUD, Input, Sound, Effects. Waits for Remotes (WaitForChild). Connects StateUpdate -> HUD.update, Notify -> HUD.notify. Sets up camera (default — do not override; Roblox default third-person camera is the 3D camera).
- HUD.luau (ModuleScript): builds a ScreenGui "BrainrotGui" (ResetOnSpawn false, IgnoreGuiInset true, but keep HUD text clear of the top-left corner where Roblox menu buttons sit). Elements: top-centre money label ("$1,234" big) + income label ("+$123/s"); top-right rebirth button ("Rebirth (x1.5)" + progress to threshold); left panel: base slots ("Base: 3/8") + lock button ("Lock Base (20s)" with cooldown); bottom-centre: tsunami timer ("Tsunami in 45s" / "TSUNAMI! Run home!"); shop panel (3 upgrade buttons with costs); a message/notify label (centre, fades). All text large enough to read when a screenshot is scaled down (TextSize >= 18 for labels, >= 28 for money).
- Input.luau (ModuleScript): ContextActionService bindings — "LockBase" on KeyCode.L (fires Remotes.LockBase), "Slap" on KeyCode.F (fires Remotes.Slap). Do NOT use InputBegan with gameProcessedEvent for movement (Roblox camera takes arrows); use ContextActionService. Buying/stealing uses ProximityPrompt (E) which Roblox handles.
- Sound.luau (ModuleScript): play(name) — sounds for buy, steal, error, lock, tsunami, rebirth, click. Use SoundService with a few standard Roblox sound asset IDs wrapped in pcall (if an ID fails, it just doesn't play — never error). Keep it simple.
- Effects.luau (ModuleScript): small visual feedback helpers (e.g. flash the money label green on earn, screen shake on tsunami is optional — keep simple: a brief red vignette flash on tsunami warning). Optional but nice.

## Polish pass (18 Nov, after first publish)
- Slots 9-16 got real physical pads in default.project.json (local z=±10, on the floor) and GameState.getSlotPosition now reads pads 1-16 from the model; the old computed fallback (GetPivot CFrame, rows at z=±12) was wrong on two counts — it put upgrade brainrots half off the floor edge, and a Model without a PrimaryPart has an identity-rotation pivot, so rotated bases got wrong positions. The fallback now derives the base frame from Slot1/Slot4/Slot5.
- HUD reads all numbers from src/shared/Config.luau (rebirth threshold, shop costs/bonuses, lock duration, tsunami interval, starting slots) and formats money with shared Util.formatMoney — no more local copies that can drift from the server. Same for the client's tsunami-warning threshold (Config.TSUNAMI_WARNING) and the conveyor prompt prices (Util.formatMoney).
- Base Sign labels are centre-aligned (TextXAlignment/TextYAlignment Center). Rojo 7.7.1 cannot set a TextLabel's UDim2 Size from the project JSON (both the array form and the object form are rejected), so the label keeps its default size — noted, not forced.
- Steal.isInOwnBase uses a square check (±12 studs on both axes, matching the 24x24 floor) instead of a 13-stud radius, so a player standing in a base corner is no longer swept by the tsunami while standing on their own floor.
- Luau must compile (luau-web). Use only standard Roblox Luau + services. No require() of external code. No game:GetService("HttpService") network calls.
- Bind keys with ContextActionService or UserInputService:IsKeyDown — NOT InputBegan with gameProcessedEvent for arrows.
- main.ts must have >=1 line the agent wrote (the coordinator handles this).
- src/ must match >=80% of the place's non-empty script bytes: game.rbxl MUST be built from src/ with Rojo (never hand-edit the place).
- Keep total source small (< 4 MiB under src/, scripts < 8 MiB in place) and instances low (< 500k; aim < 2000).
- All code original, written by recorded sessions. Do not copy from existing Roblox games.
- Do NOT write PLAY.json (leave zeros — the user publishes later). Do NOT take screenshots (leave starter ones as placeholders). Do NOT publish anything.

## Files the subagents write
- Server agent: src/shared/BrainrotData.luau, src/shared/Config.luau, src/shared/Util.luau, src/server/init.server.luau, src/server/GameState.luau, src/server/BrainrotFactory.luau, src/server/Conveyor.luau, src/server/Economy.luau, src/server/Steal.luau, src/server/Tsunami.luau, src/server/Remotes.luau. (11 files)
- Client agent: src/client/Game.client.luau, src/client/HUD.luau, src/client/Input.luau, src/client/Sound.luau, src/client/Effects.luau. (5 files)
- World agent: default.project.json (full 3D world: baseplate, plaza, conveyor belt, fountain at (0,0,-20), SpawnLocation at (0,1,40), 8 bases Base1..Base8 at the positions above with Floor/Slot1-8/Gate/Sign/back+side walls, 8 trees, 6 lamps, 3 stalls, perimeter walls; Players CharacterAutoLoads true; project name "brainrot-bazaar"; services ServerScriptService/Server->src/server, StarterPlayerScripts/Client->src/client, ReplicatedStorage/Shared->src/shared).
- Each agent: write files, then REVISE at least one file (edit it again) so thinking_revised is satisfied, and verify your Luau compiles (use the kit's luau check if available, or at least a syntax sanity pass). Report the files you wrote + any problems.

<!-- Re-witness 19 Nov: reviewed under recording 01a1f2b0; no change needed. -->
