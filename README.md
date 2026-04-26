# ZMINE — Zepton Mining

> A glowing-green proof-of-work tycoon with a walkable Roblox-style world, real cross-player presence, layered procedural audio, and a full ladder of cosmetic unlocks. Built for [games.brassey.io](https://games.brassey.io).

You are A-TEK Industries' newest facility operator. Mine **zeptons** — a luminous green energetic currency — by deploying real-world-style hashboards, GPU clusters, quantum rigs, and exotic neural forges. Every miner consumes power, so you also build the infrastructure that feeds them: monocrystalline-Si solar, three-blade wind, Francis-turbine hydro, EGS geothermal, Gen-IV fission, D–T tokamak fusion, antimatter Penning traps, and zero-point Casimir-mirror taps.

Build too many miners and the grid browns out — the HUD bar turns red and shows the throttle %. Overbuild the grid and idle capacity bleeds your zepton reserve. Find the balance, climb the tech tree, and watch the facility — and the global mesh — light up.

## Two views — `Tab` toggles

**CORE OPERATIONS** is the dashboard view: HUD with Z-coin balance + Z/s rate + hash rate + block height + uptime + LIVE-mesh badge + GLOBAL SURGE banner; a giant glowing zepton orb you click to manually mine; animated power conduits radiating to every active miner and energy plant; a 4-tab right panel — **MINERS · ENERGY · RESEARCH · NETWORK**.

**WORLD VIEW** is a walkable isometric plot. Your **Roblox-tycoon-style stacked-block humanoid** has passive breathing / idle blink / sway / head-look / hand twitch / foot dust / smooth facing / lean-into-direction / full walk cycle. WASD walks. Step on a glowing buy pad to auto-purchase a miner or energy plant; **hold the pad longer to buy ×10 (≥1.5 s) or MAX (≥3 s)** with on-pad hint text. Zepton canisters fill from transparent to glowing green and pump particles toward the core. Other live operators walk the plot beside you, with name tags and waving hands when they emote.

The HUD's **`[ TAB ] ↹ ENTER WORLD`** pill makes the toggle obvious from the very first session.

## Z-coin everywhere

Every Z amount is paired with a glowy hex Z-coin logo (stylized Z stroke + orbital sparkles + rim halo + specular highlight). It pulses, rotates, and emits sparks tied to its accent color. Used in HUD balance, all shop costs, world pad costs, achievement toasts, ticker payouts, and the network panel.

## First-of-tier celebrations

The first time you buy a unit of any miner / energy tier — **the first GPU cluster, the first fusion core** — fires a distinct chord (`Audio.tier`), a hum-duck, an `Fx.shatter` + `Fx.zoom` + `Fx.glow` + `Fx.ripple` combo, and a 2.5 s "✦ TIER N UNLOCKED" float at the core. Crossing into a new visual era is marked.

## Real proof-of-work concepts

Each rig in the **MINERS** tab carries real (or near-future) hashing flavor:

- **ASIC-Z1 Hashboard** — SHA-256d on 7 nm BM1398-class silicon. ~110 TH/s @ 29.5 J/TH (Antminer S19 reference).
- **GPU Mining Cluster** — Memory-hard algorithms (Ethash / KawPow / Equihash) on RTX-class hardware.
- **Cryogenic Quantum Rig** — 1024-logical-qubit array running Grover-accelerated nonce search at 14 mK.
- **Neural Forge** — Transformer pre-trained on solved zepton blocks predicting low-entropy nonce candidates.
- **Hyperdrive Lattice / Singularity Engine / Eonchamber** — Speculative endgame: subliminal channels, closed-timelike loops, many-worlds eigenstate sampling.

Tier-specific iso visuals: ASIC PCBs with chips and blinking LEDs, GPU cards with spinning fans and RGB strips, cryostat tubes with glowing cores and vapor wisps, transformer stacks with neural traces, orbiting hyperdrive lattices, accretion-ring singularity wells, multi-orbit Eonchamber satellites.

Hash rate and block height are first-class HUD chips. A **block-found lottery** fires every ~60 s; reward = `(50 + Z/s × 30) × 0.5^halvings`, halving every 100 personal blocks (the deflationary mechanic the UI advertises is real — **both** the floor and the rate-tied component halve, so reward genuinely curves down). Block plays a unique chord (`Audio.block`), full-screen pulse, 0.05 zoom, gold ripple. Halving is its own sub-bass hit + chroma + invert + shatter — the loudest moment in the game.

## Real energy infrastructure

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

Tier-specific iso visuals: tilted PV panel arrays w/ sun glint, three-blade turbines, Francis-turbine dam walls w/ falling water, geothermal pipes w/ rising steam, hyperboloid cooling towers w/ billowing plume, tokamak rings w/ orbiting plasma sparks, Penning traps w/ caged annihilation glow, Casimir crystal clusters w/ rainbow shimmer.

When demand exceeds supply the HUD energy bar turns red and overlays **"THROTTLING N%"** so the brownout state is unambiguous.

## Click streak

Rapid clicks within 1.5 s scale the manual mine value up to 2× *and* multiply the streak-amplified `click_pct` component (so a 20-streak click at 0.5 % click_pct adds 10 % of your current Z/s — meaningful at scale, not cosmetic). High-streak clicks layer a sub-octave miner pulse for body and stay below a pitch ceiling so they feel powerful, not shrill. `STREAK ×N` callouts every 5 hits.

## Character cosmetics — earned by play

Stacked-block humanoid with progression-tied unlocks (`src/cosmetics.lua`). Slots: **trail · aura · halo · wings · sparkle**, plus a body palette cycler (Operator A / Field Tech / Neon Operator / Solar Engineer / Voidwalker / Chrome Tycoon / Synthwave). Best-tier-earned-per-slot auto-equips; manual cycling overrides via `C / V / B / N / M`.

| Trail | Aura | Halo / Crown | Wings |
|-------|------|--------------|-------|
| Spark Trail | Ember Halo | Kilozepton Crown | Photon Sails |
| Zepton Drip | Cyclone | Megazepton Crown | Neural Wings |
| RGB Pixel Stream | Riverflow Ring | Gigazepton Crown | Warp Drives |
| Matrix Rain | Magma Pool | Terazepton Crown | Eon Wings |
| Neural Wisps | Cherenkov Glow | Blockfinder's Halo | — |
| Warp Wake | Plasma Toroid | Singularity Halo | — |
| Event-Horizon Wake | Annihilation / Plasma / ZPT Shimmer | Eon Halo | — |
| Eon Echoes | — | — | — |

Cosmetic unlock is celebrated in **both** views (not just world): chord + hum-duck + flash + glow + ripple + shatter + a 50-particle burst on the character (world) AND the orb (core ops) + a "✦ NAME" float at the core. You'll never miss an unlock.

## Multi-user — real `[[LOVEWEB_NET]]` integration

The portal exposes a complete multi-user layer; we use every piece of it.

**Identity** — `__loveweb__/identity.json` is read on every poll for the signed-in player's `userId / handle / avatar`, refreshed *before* each event-poll batch so target-filtering of inbound boost / wave / pool can't race against the first poll on connect.

**Room mesh** — on entering play we `[[LOVEWEB_NET]]list`, then `join` the most-populous public **A-TEK Mesh** room under capacity, or `create` one. Inside the room we periodically `send stats` (every 8 s) so peers see live `z_per_sec / hashrate / z_lifetime / level / block_height` for every facility. Mode flip-flops are smoothed with 2-tick hysteresis so a single status blip during reconnect doesn't wipe the snapshot list.

**Slug-wide presence** — every 30 s we `slug_presence z_lifetime 12` to refresh the global leaderboard. The HUD pulsing `LIVE ON GAMES.BRASSEY.IO` badge shows **N OPERATORS MINING NOW** with a sub-line of `(you+X) in your room · Y in 24h · Z all-time`. The shop **NETWORK** tab has a global summary line above the room list.

**Cross-room global ticker** — major events (`block` / `halving` / `tier_unlocked` / `surge_started`) are mirrored via `[[LOVEWEB_NET]]broadcast` and stream into `__loveweb__/slug/global_inbox.jsonl`. The shop ticker tags them `[global]`. The `_broadcastedNewTiers` set is **persisted across save/load** so a reload doesn't republish every owned tier as "newly unlocked".

**Public profile cross-game** — every 30 s we write `public_profile.json` (≤ 32 KB) with `facility_name / z_lifetime / z_per_sec / hashrate / level / block_height / palette / accent_color / updated_at`. We `[[LOVEWEB_NET]]profile <userId>` to backfill peers we discover in roster but haven't seen `stats` from yet — so peers stay visible (with last-known stats) even after they go offline. Slug top-N users from `slug/active.json` also feed into `peer_memory` directly.

**Targeted unicast** — boost / pool_request / pool_leave / thanks use `[[LOVEWEB_NET]]send <verb> --target=<userId> <json>`, so only sender + recipient see them. Boost cost is 5 % of your Z (min 25 Z) and is shown right on the BOOST button label as `−<amount>`. The recipient's runtime auto-schedules a `thanks` reply 30–120 s later that credits a 1.2–1.8× bonus on your side, **capped at `max(50, your_z_per_sec × 60)`** so a malicious peer can't claim `paid: 1e18` and mint zeptons on your leaderboard.

**Pool sync** — `pool_request` is auto-accepted on the receiving side. While paired, you contribute 5 %/s of your rate; you collect 12 % of their broadcast rate every 30 s.

**Persistent peer memory** — saved alongside cosmetics + block state. Offline peers stay in your network panel under an `OFFLINE — KNOWN` subhead, sorted by lifetime, with the live operators rendered first under `ONLINE` / `AFK`. Slug top-N feeds the same memory.

**AFK hysteresis** — peers go AFK only after 40 s of stats silence and offline only after 90 s, so normal 8 s broadcast jitter doesn't flicker the badge. Newly-rostered peers are seeded with `lastUpdate = now` so they don't render AFK on their first frame.

**Surge events** — every 100 *global* blocks, `__loveweb__/slug/state.json` mutates with `surge_until = now + 120 s` and we broadcast `surge_started`. While the surge window is active, every connected facility gets a global +50 % production multiplier (applied to both Z/s and click value). Rising-edge fires `Audio.surge` (ascending pitch sweep + harmonic stack swell) + `Fx.flash + glow + ripple + zoom + pulsate`; the HUD shows a bold pulsing **GLOBAL SURGE +50% Ns** banner. Falling-edge cancels the pulsate and logs.

**Demo peers** — when you're connected to a real room but it's still empty, we top up with up to 6 deterministic-seeded sim ghosts so the panel doesn't feel barren — but they're **clearly labeled `DEMO ·`**, desaturated, grouped under their own subhead, and excluded from the global hash-rate aggregation, so you always know who's real.

**Emotes** — `E` waves at the mesh; `F` plants a flag at your character position. Real-peer waves now propagate to their character (raised arm + animated "hi" callout). Peer flags render as banners on your plot with the facility name.

If the player is signed-out, on desktop, or pre-connect, the network panel falls back to a deterministic 14-facility simulated mesh seeded from `facility_seed` so the screen is never empty. Once connected, real peers replace the sim ghosts. The mesh-status header reflects which layer is active.

**Rate-limit budget** (well under the portal's documented caps): stats `send` 0.125 Hz, `slug_presence` 0.033 Hz, `broadcast` only on rising-edge of major events, `profile` per-userId once every 30 s, `public_profile.json` write every 30 s.

## Audio — procedural and stunning

`src/audio.lua` synthesizes every sound from layered detuned partials with pitch envelopes, harmonic stacks, and 3–5-tap FIR reverb tails. **Each reward tier has a distinct sonic signature** and the hum ducks 250–600 ms whenever a transient SFX fires, so block / crit / halving / surge / cosmetic always cut through.

| SFX | Notes |
|-----|-------|
| click / click_alt | Dual layered FM with capped pitch lift + sub-octave miner overlay at high streak; reverb tail trimmed for fast trading |
| buy / power | Major-third arpeggio with shimmer (short reverb taps, no muddy 17k tail) |
| upgrade | 4-note arpeggio with shimmer (research-only signature) |
| achievement | 4-note D-major fanfare with overtones + long reverb tail |
| **tier_up** | First-of-tier major-7 ascending arpeggio — distinct from buy / upgrade |
| **block** | `tierUp` reused with deeper pitch and longer ducking — gold full-screen pulse |
| **halving** | Pitch-falling sub-bass + filtered noise + shimmer + chroma + invert — once-per-100-blocks event, unmistakable |
| **surge** | Ascending pitch sweep + harmonic-stack swell — fires on rising edge of global surge |
| **crit** | 4-note octave-stack (880 → 2640 Hz) + chroma — golden hit, was previously wired to `upgrade` (now fixed) |
| **cosmetic** | Achievement chord with elevated pitch — fires in both core and world views |
| canister_pump | Filter-sweep whoosh + bright chime tail (rate-limited so heavy plays don't stack) |
| pad_charge | Ascending sweep + noise burst on stepping onto a buy pad |
| world_swoosh | Filter-sweep whoosh on `Tab` view toggle |
| peer_join | 3-note bell stack with long reverb on real-operator connect |
| peer_leave / pool_leave | Falling minor-third chime (correct semantic for network state changes) |
| pool_join | `peer_join` chime (real network state change, not generic upgrade) |
| footstep | Low-frequency thud + noise tap; pitch randomized |
| emote_wave / flag_plant | Single-cycle bell / sub-bass thud |
| coreHum (looping) | Layered drone with two LFOs; tanh-shaped volume + pitch curve responds to `z_per_sec` across the full ladder (1 → 1e9), and pitch sags during brownout so the mix audibly stresses |

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
| Hold-to-bulk on world pad | hold ≥ 1.5 s for ×10, ≥ 3 s for MAX |
| Switch shop tab | `1` Miners · `2` Energy · `3` Research · `4` Network |
| Buy ×10 / max | `Shift` / `Ctrl` while clicking a card |
| Pause | `P` (any scene; or window unfocus) |
| Save now | `S` (any scene; autosaves every 15 s) |
| Quit | `Esc` (two-step: first warns, second within 4 s saves + quits) |

## Achievements

38 declared in `achievements.json`, ranging from common (`first_zepton`, `name_facility`, `click_100`) to rare (`balanced_grid`, `first_block`, `ten_blocks`, `first_halving`) to legendary (`z_1t`, `all_upgrades`, `secret_zen`, `first_zeropoint`). Unlocks emit `[[LOVEWEB_ACH]]unlock <key>` with metadata; the portal toasts them and persists state to `__loveweb__/achievements.json`.

## Portal FX

Visual chrome effects are emitted via `[[LOVEWEB_FX]]<verb>` and gated by anti-strobe minimum intervals: flash on click + crit + first-of-tier + cosmetic + surge, glow on buy, ripple on click + boost + tab + cosmetic + surge, shake on click + bulk-buy ≥ 5, mood + calm + pulsate as persistent ambient layers, shatter + invert on halvings + first-of-tier + cosmetic, zoom on block + first-of-tier + surge, chroma on crit + halving.

## Tech / build

```sh
love .
```

Pure LÖVE 11.x, Lua 5.1 compatible. No threads, no sockets, no FFI, no `love.thread` / `love.video`. Saves to `love.filesystem` (cloud-synced through `<save>/zmine/save.json` on the portal).

Source layout (~6,000 lines Lua):

```
zmine/
├── main.lua                  ← entry point, canvas-scaling, CRT post-shader
├── conf.lua                  ← identity = "zmine", 1920×1080, threads/video off
├── achievements.json         ← 38 achievements
├── lib/json.lua              ← rxi/json.lua bundle (MIT)
└── src/
    ├── miners.lua, energy.lua, upgrades.lua  ← real-world spec data
    ├── game.lua              ← state machine, click/buy/block/pool/boost/wave/flag,
    │                           halving math, surge handling, public_profile writer
    ├── net.lua               ← thin [[LOVEWEB_NET]] wrapper + snapshot poll
    │                           (identity, slug active, slug state, profiles)
    ├── network.lua           ← game-side mesh translator (real + sim fallback,
    │                           AFK hysteresis, mode hysteresis, demo-peer tag,
    │                           bonus capping, surge auth via broadcast)
    ├── world.lua             ← isometric plot, WASD, hold-to-bulk pads,
    │                           canisters, peer characters, flags
    ├── character.lua         ← Roblox-style humanoid w/ passive micro-motion
    │                           (breathing, blink, sway, head-look, hand twitch,
    │                           foot dust, smooth facing, lean, wave gesture)
    ├── cosmetics.lua         ← earned trails / auras / halos / wings / sparkles
    ├── assets.lua            ← per-tier iso visuals (motherboard / GPU / fusion / …)
    ├── iso.lua               ← projection helpers (toScreen / depth / drawTile / drawBox)
    ├── shop.lua              ← 4-tab panel; sorted ONLINE/AFK/OFFLINE/DEMO
    │                           subheads in NETWORK; BOOST button shows cost
    ├── facility.lua          ← core orb + conduits + telemetry strip
    ├── intro.lua             ← A-TEK Industries facility-name screen
    ├── hud.lua               ← top bar (Z-coin balance, Z/s, energy bar w/
    │                           THROTTLING overlay, HASH+BLOCK chips,
    │                           [TAB]↹ENTER WORLD pill, LIVE badge, SURGE banner)
    ├── coin.lua              ← glowy hex Z-coin logo
    ├── audio.lua             ← procedural synth (FM / ADSR / FIR-reverb,
    │                           tier-up / block / halving / surge / crit /
    │                           cosmetic / pool-join / pool-leave SFX,
    │                           hum tanh curve + duck + brownout pitch sag)
    ├── shaders.lua           ← coreGlow / bgGrid / CRT / glowRing / energyBar
    ├── particles.lua, floats.lua, fx.lua  ← emitters + portal FX magic-prints
    ├── save.lua              ← love.filesystem JSON save (version 1)
    │                           + cosmetics + peer_memory + broadcast watermarks
    ├── achievements.lua      ← [[LOVEWEB_ACH]]unlock wrapper
    └── format.lua            ← zeptons / hashRate / time / percent
```

## License

MIT — see `LICENSE`.
