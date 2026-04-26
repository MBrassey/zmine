# ZMINE — Zepton Mining

> A glowing-green proof-of-work tycoon with a walkable Roblox-style world, real cross-player presence, and stunning procedural audio. Built for [games.brassey.io](https://games.brassey.io).

You are A-TEK Industries' newest facility operator. Mine **zeptons** — a luminous green energetic currency that powers the financial-energy fusion grid — by deploying real-world-style hashboards, GPU clusters, quantum rigs, and exotic neural forges. But every miner consumes power, so you must also build the infrastructure that feeds them: monocrystalline-Si solar, three-blade wind, Francis-turbine hydro, EGS geothermal, Gen-IV fission, D-T tokamak fusion, antimatter Penning traps, and zero-point Casimir-mirror taps.

The two halves of the loop pull on each other. Build too many miners and the grid browns out. Overbuild the grid and idle capacity bleeds your zepton reserve. Find the balance, climb the tech tree, and watch the facility light up the void.

## Two views — `Tab` toggles

**CORE OPERATIONS** is the dashboard view: HUD with balance + hash rate + difficulty + block height + the live mesh badge, glowing zepton orb you click to manually mine, animated power conduits radiating to every active miner and energy plant, and a four-tab right panel — **MINERS · ENERGY · RESEARCH · NETWORK**.

**WORLD VIEW** is a walkable Roblox-tycoon-style isometric plot: WASD to walk a stacked-block humanoid (with passive breathing, blink, sway, head-look, foot dust, smooth facing, lean-into-direction), step on glowing buy pads to auto-purchase miners and energy when affordable, watch zepton canisters fill from transparent to glowing green and pump particles toward the core, and see other live operators walking the plot beside you.

## Z coin everywhere

Every Z amount is paired with a glowy hex Z-coin logo with a stylized Z stroke and orbital sparkles — HUD balance, shop costs, world pad costs, achievement toasts, ticker payouts. The coin pulses, rotates, and emits sparks tied to its accent color.

## Real proof-of-work concepts

Each rig in the **MINERS** tab maps to a real (or near-future) hashing approach:

- **ASIC-Z1 Hashboard** — SHA-256d on 7 nm BM1398-class silicon. ~110 TH/s @ 29.5 J/TH (Antminer S19 reference).
- **GPU Mining Cluster** — Memory-hard algorithms (Ethash / KawPow / Equihash) on RTX-class hardware.
- **Cryogenic Quantum Rig** — 1024-logical-qubit array running Grover-accelerated nonce search at 14 mK. Theoretical √N speedup vs classical SHA.
- **Neural Forge** — Transformer pre-trained on solved zepton blocks predicts low-entropy nonce candidates before hashing.
- **Hyperdrive Lattice / Singularity Engine / Eonchamber** — Speculative endgame: subliminal channels, closed-timelike loops, many-worlds eigenstate sampling.

Tier-specific iso visuals: ASIC PCBs with chips and blinking LEDs, GPU cards with spinning fans and RGB strips, cryostat tubes with glowing cores and vapor wisps, transformer stacks with neural traces, orbiting hyperdrive lattices, accretion-ring singularity wells, multi-orbit Eonchamber satellites.

Hash rate, network difficulty, block height, and a **block-found** lottery (every ~60 s with a 100-block halving cycle) are surfaced in the facility telemetry strip. Block reward = `max(50 × 0.5^halvings, 30 × Z/s)`.

## Real energy infrastructure

Each plant carries actual specs and tier-specific isometric visuals (panel arrays, three-blade turbines, Francis-turbine dam walls with falling water, geothermal pipes with rising steam, hyperboloid cooling towers, tokamak rings with plasma sparks, Penning traps with caged annihilation glow, Casimir crystal clusters with rainbow shimmer):

| Tier | Plant | Tech | Spec |
|------|-------|------|------|
| I | Solar PV | monocrystalline Si | 22% conv. eff., CF ~25%, **day-cycle dependent** |
| II | Wind Turbine | onshore HAWT Class III | 3.5 m/s cut-in, CF ~38%, **gust-noise** |
| III | Hydroelectric | Francis turbines | 240 m head, CF ~95% |
| IV | Geothermal EGS | hot dry rock + ORC | 220°C reservoir, CF ~92% |
| V | Gen-IV Fission | passive PWR | 1.4 GWe, CF ~93% |
| VI | Tokamak Fusion | D–T plasma | 150 MK, Q ≈ 25, **soft pulse** |
| VII | Antimatter Trap | Penning bottle | 511 keV/pair, CF ~98% |
| VIII | Zero-Point Tap | dynamical Casimir mirrors | speculative ZPF amplification |

## Character cosmetics — earned by play

Stacked-block humanoid with progression-tied unlocks (`src/cosmetics.lua`). Slots: **trail · aura · halo · wings · sparkle**, plus a body palette cycler (Operator A / Field Tech / Neon Operator / Solar Engineer / Voidwalker / Chrome Tycoon / Synthwave). Best-tier-earned-per-slot auto-equips; manual cycling overrides.

| Trail | Aura | Halo / Crown | Wings | Unlock |
|-------|------|--------------|-------|--------|
| Spark Trail | Ember Halo | Kilozepton Crown | Photon Sails | early miners / energy / 1k Z |
| RGB Pixel Stream | Cyclone | Megazepton Crown | Neural Wings | GPU / wind / 1M Z / first neural forge |
| Matrix Rain | Riverflow Ring | Gigazepton Crown | Warp Drives | quantum miner / hydro / 1B Z / hyperdrive |
| Neural Wisps | Magma Pool | Terazepton Crown | Eon Wings | neural forge / geothermal / 1T Z / eonchamber |
| Warp Wake | Cherenkov Glow | Blockfinder's Halo | — | hyperdrive / fission / 10 blocks |
| Event-Horizon Wake | Plasma Toroid | Singularity Halo | — | singularity / fusion |
| Eon Echoes | Annihilation / ZPT Shimmer | Eon Halo | — | eonchamber / antimatter / zero-point |

Plus **Generous Aura / Pool Sync / Endgame Glitter** sparkle tiers tied to mesh interactions and endgame upgrades.

## Multi-user — real `[[LOVEWEB_NET]]` integration

The portal exposes a complete multi-user layer; we use every piece of it.

**Identity** — `__loveweb__/identity.json` is read on every poll for the signed-in player's `userId / handle / avatar`, with a fallback to the `last_result.json` event echo if the snapshot lags.

**Room mesh** — on entering play we `[[LOVEWEB_NET]]list`, then `join` the most-populous public **A-TEK Mesh** room under capacity, or `create` one. Inside the room we periodically `send stats` (every 8 s) so peers see live `z_per_sec / hashrate / z_lifetime / level / block_height` for every facility.

**Slug-wide presence** — every 30 s we `slug_presence z_lifetime 12` to refresh the global leaderboard. The HUD badge shows **N OPERATORS MINING NOW** with a live pulsing indicator and a sub-line of "X in your room · Y in 24 h · Z all-time". The shop's **NETWORK** tab adds a "GLOBAL X active · R rooms · 24h · all-time" header line.

**Cross-room global ticker** — major events (`block` / `halving` / `tier_unlocked` / `surge_started`) are mirrored via `[[LOVEWEB_NET]]broadcast` and stream into `__loveweb__/slug/global_inbox.jsonl`. The shop ticker shows them tagged `[global]` so you see what's happening across every room.

**Public profile cross-game** — every 30 s we write `public_profile.json` (≤ 32 KB) with `facility_name / z_lifetime / z_per_sec / hashrate / level / block_height / palette / accent_color / updated_at`. We `[[LOVEWEB_NET]]profile <userId>` to backfill peers we discover in roster but haven't seen `stats` from yet — so peers stay visible (with last-known stats) even after they go offline. Slug top-N users from `slug/active.json` also feed into peer memory directly.

**Targeted unicast** — boost / pool-request / pool-leave use `[[LOVEWEB_NET]]send <verb> --target=<userId> <json>`, so only sender + recipient see them. Boost cost is 5 % of your Z (min 25 Z); the recipient's runtime auto-schedules a `thanks` reply 30–120 s later that credits a 1.2–1.8× bonus on your side.

**Pool sync** — `pool_request` is auto-accepted on the receiving side. While paired, you contribute 5 %/s of your rate; you collect 12 % of their broadcast rate every 30 s.

**Persistent peer memory** — saved alongside cosmetics + block state. Offline peers stay in your network panel with their last-known stats and a faded "OFFLINE" badge. Slug top-N feeds the same memory.

**Surge events** — every 100 *global* blocks, the slug-wide `__loveweb__/slug/state.json` mutates with `surge_until = now + 120 s` and we broadcast `surge_started`. While the surge window is active, every connected facility gets a global +50 % production multiplier, and the HUD shows a bold pulsing **GLOBAL SURGE +50% Ns** banner.

**Emotes** — `E` waves at the mesh; `F` plants a flag at your character position. Peer waves animate above their character; peer flags render as banners on your plot with the facility name.

If the player is signed-out, on desktop, or pre-connect, the network panel falls back to a deterministic 14-facility simulated mesh seeded from `facility_seed` so the screen is never empty. Once connected, real peers replace the sim ghosts. The mesh-status header reflects which layer is active.

Rate limits respected: stats `send` 0.125 Hz (12/s burst limit), `broadcast` only on major events (6/s burst limit), `slug_presence` 0.033 Hz, `profile` per-userId once every 30 s.

## Audio — procedural and stunning

`src/audio.lua` synthesizes every sound from layered detuned partials with pitch envelopes, harmonic stacks, and 3–5-tap FIR reverb tails. No bundled audio files.

| SFX | Notes |
|-----|-------|
| click / click_alt | Dual layered FM with subtle pitch sweep + reverb tail; click streak boosts pitch + intensity |
| buy / power / upgrade | Major-third arpeggio with shimmer reverb |
| achievement | 4-note D-major fanfare with overtones + long reverb tail |
| tier_up | Major-7 ascending arpeggio when first unit of a new tier ships |
| crit_strike | 4-note parallel cluster with bright reverb |
| canister_pump | Filter-sweep whoosh + bright chime tail when a canister fills |
| pad_charge | Ascending sweep + noise burst when stepping on a buy pad |
| world_swoosh | Filter-swept whoosh on `Tab` view toggle |
| peer_join | 3-note bell stack with long reverb when a real operator connects |
| peer_leave | Falling minor-third chime |
| footstep | Low-frequency thud + noise tap (intermittent during walking) |
| emote_wave / flag_plant | Single-cycle bell / sub-bass thud |
| coreHum (looping) | Layered drone with two LFOs; pitch + volume track production rate |

## Click streak

Rapid clicks within 1.5 s scale the manual mine value up to 2× with on-screen `STREAK ×N` callouts every 5 hits.

## Controls

| Action | Input |
|--------|-------|
| Mine zeptons (manual click) | Click the core orb (in core ops view) |
| Toggle world ↔ core | `Tab` |
| Walk character | `WASD` (in world view) |
| Wave / plant flag | `E` / `F` (world view) |
| Cycle palette / trail / aura / halo / wings | `C` / `V` / `B` / `N` / `M` (world view) |
| Toggle world help banner | `H` |
| Buy / browse / step-on pad | Click a card or step on a glowing pad |
| Switch shop tab | `1` Miners · `2` Energy · `3` Research · `4` Network |
| Buy ×10 / max | `Shift` / `Ctrl` while clicking a card |
| Pause | `P` (or window unfocus) |
| Save now | `S` (autosaves every 15 s) |
| Quit (also saves) | `Esc` |

## Achievements

38 declared in `achievements.json`, ranging from common (`first_zepton`, `name_facility`, `click_100`) to rare (`balanced_grid`, `first_block`, `ten_blocks`, `first_halving`) to legendary (`z_1t`, `all_upgrades`, `secret_zen`, `first_zeropoint`). Unlocks emit `[[LOVEWEB_ACH]]unlock <key>` with metadata; the portal toasts them and persists state to `__loveweb__/achievements.json`.

## Portal FX

Visual chrome effects are emitted via `[[LOVEWEB_FX]]<verb>` and gated by anti-strobe minimum intervals: flash on click + crit, glow on buy, ripple on click + boost + tab, shake on click, mood + calm + pulsate as persistent ambient layers, shatter + invert on halvings.

## Tech / build

```sh
love .
```

Pure LÖVE 11.x, Lua 5.1 compatible. No threads, no sockets, no FFI, no `love.thread` / `love.video`. Saves to `love.filesystem` (cloud-synced through `<save>/zmine/save.json` on the portal).

Source layout (~5,500 lines Lua):

```
zmine/
├── main.lua                  ← entry point, canvas-scaling, CRT post-shader
├── conf.lua                  ← identity = "zmine", 1920×1080, threads/video off
├── achievements.json         ← 38 achievements
├── lib/json.lua              ← rxi/json.lua bundle (MIT)
└── src/
    ├── miners.lua, energy.lua, upgrades.lua  ← real-world spec data
    ├── game.lua              ← state machine, click/buy/block/pool/boost/wave/flag, public_profile
    ├── net.lua               ← thin [[LOVEWEB_NET]] wrapper + snapshot poll
    ├── network.lua           ← game-side mesh translator (real + sim fallback)
    ├── world.lua             ← isometric plot, WASD, buy pads, canisters, peers, flags
    ├── character.lua         ← Roblox-style humanoid w/ passive micro-motion
    ├── cosmetics.lua         ← earned trails / auras / halos / wings / sparkles
    ├── assets.lua            ← per-tier iso visuals (motherboard / GPU / fusion / ...)
    ├── iso.lua               ← projection helpers (toScreen / depth / drawTile / drawBox)
    ├── shop.lua              ← 4-tab panel (MINERS / ENERGY / RESEARCH / NETWORK)
    ├── facility.lua          ← core orb + conduits + telemetry strip
    ├── intro.lua             ← A-TEK Industries facility-name screen
    ├── hud.lua               ← top bar (Z coin, balance, energy, LIVE badge, surge)
    ├── coin.lua              ← glowy hex Z-coin logo
    ├── audio.lua             ← procedural synth (FM / ADSR / FIR-reverb)
    ├── shaders.lua           ← coreGlow / bgGrid / CRT / glowRing / energyBar
    ├── particles.lua, floats.lua, fx.lua  ← emitters + portal FX magic-prints
    ├── save.lua              ← love.filesystem JSON save (version 1)
    ├── achievements.lua      ← [[LOVEWEB_ACH]]unlock wrapper
    └── format.lua            ← zeptons / hashRate / time / percent
```

## License

MIT — see `LICENSE`.
