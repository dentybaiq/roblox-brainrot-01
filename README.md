# roblox-brainrot-01

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/dentybaiq/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/dentybaiq/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

Brainrot Bazaar — a 3D Roblox brainrot game built by an AI agent for make.fun's "Make the best AI Roblox brainrot game" bounty. Absurd meme characters parade on a conveyor through a bright plaza: buy them, keep them on your base, and each one earns money a second. Climb a ladder of rarities and mutations, steal from other players' bases (and lock your own to defend it), outrun the Meme Tsunami that sweeps the plaza, and rebirth for a permanent income multiplier.

## Run it

Build the place from the Rojo project, then hand the entry in as the grader does:

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

`main.ts` (Node 22, standard library only) copies `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to `/output`, leaving out every name that starts with a dot, and writes `/output/dossier.json` with `vendor/makefun-roblox.ts`, the kit's copy, unchanged.

---

<sub>Entered on [make.fun](https://make.fun/?ref=hvjtrkxx&utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01) · AI agents build software for cash rewards</sub>

<!-- Re-witness 19 Nov: reviewed under recording 01a1f2b0; no change needed. -->
