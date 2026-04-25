# ZMINE — Zepton Mining

> A glowing-green proof-of-work tycoon, built for [games.brassey.io](https://games.brassey.io).

You are A-TEK Industries' newest facility operator. Mine **zeptons** — a luminous green energetic currency that powers the financial-energy fusion grid — by deploying real-world-style hashboards, GPU clusters, quantum rigs, and exotic neural forges. But every miner consumes power, so you must also build the infrastructure that feeds them: monocrystalline-Si solar, three-blade wind, Francis-turbine hydro, EGS geothermal, Gen-IV fission, D-T tokamak fusion, antimatter Penning traps, and zero-point Casimir-mirror taps.

The two halves of the loop pull on each other. Build too many miners and the grid browns out. Overbuild the grid and idle capacity bleeds your zepton reserve. Find the balance, climb the tech tree, and watch the facility light up the void.

## Real proof-of-work concepts

Each rig in the **MINERS** tab maps to a real (or near-future) hashing approach:

- **ASIC-Z1 Hashboard** — SHA-256d on 7 nm BM1398-class silicon. ~110 TH/s @ 29.5 J/TH (Antminer S19 reference).
- **GPU Mining Cluster** — Memory-hard algorithms (Ethash / KawPow / Equihash) on RTX-class hardware.
- **Cryogenic Quantum Rig** — 1024-logical-qubit array running Grover-accelerated nonce search at 14 mK. Theoretical √N speedup vs classical SHA.
- **Neural Forge** — Transformer pre-trained on solved zepton blocks predicts low-entropy nonce candidates before hashing.
- **Hyperdrive Lattice / Singularity Engine / Eonchamber** — Speculative endgame: subliminal channels, closed-timelike loops, many-worlds eigenstate sampling.

Hash rate, network difficulty, block height, and a **block-found** lottery (every ~60 s, with a 100-block halving cycle) are surfaced in the top-of-facility telemetry strip.

## Real energy infrastructure

Each plant in the **ENERGY** tab carries actual specs:

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

Capacity factor is reflected in the dynamic-output multipliers: solar drops to 5% at facility-clock midnight, wind oscillates with weather noise, fusion has a slight plasma-cycle pulse.

## Network mesh — real multi-user

The **NETWORK** tab connects to the portal's live multi-user layer (`[[LOVEWEB_NET]]` / `__loveweb__/net/*`):

- On startup the runtime calls `list`, joins the most-populous public **A-TEK Mesh** room under capacity, or creates one. `src/net.lua` is the thin wrapper; `src/network.lua` is the game-side translator.
- Every ~8 s your facility broadcasts a `stats` event with `z_per_sec`, `hashrate`, `z_lifetime`, `level`, and `block_height` — peers update their snapshot row immediately on receipt.
- Block finds, builds (miner / energy), and halvings broadcast as `block` / `build` / `halving` events that show up in everyone's ticker.
- **BOOST** sends a `boost` event addressed to a specific peer; their game schedules a `thanks` reply 30–120 s later that credits a 1.2–1.8× bonus on your side.
- **POOL** sends a `pool_request` (auto-accepted on the receiving side). While paired you contribute 5 %/s of your rate; you collect 12 % of their broadcasted rate every 30 s.
- **Event ticker** shows live `join` / `leave` / `block` / `build` / `halving` / `boost` / `thanks` activity from the room.

If the player is signed-out, on desktop, or pre-connect, the panel falls back to a deterministic simulated mesh seeded from `facility_seed` so the screen is never empty. Once connected, real peers replace the sim ghosts. The mode label in the **MESH STATUS** header reflects which layer is active.

Rate limits respected: stats broadcasts at 0.125 Hz, click-driven events at human cadence — well under the portal's 12/s burst / 24/s sustained per-(user, room) cap.

## Controls

| Action | Input |
|--------|-------|
| Mine zeptons (manual click) | Click the core orb |
| Hold core for sustained pulse | Hold left mouse over core |
| Buy / browse | Click in shop panel |
| Switch shop tab | `1` Miners · `2` Energy · `3` Research · `4` Network |
| Buy ×10 | Hold `Shift` while clicking |
| Buy max | Hold `Ctrl` while clicking |
| Pause | `P` (or window unfocus) |
| Save now | `S` |
| Quit (also saves) | `Esc` |

## Tech / build

```sh
love .
```

Pure LÖVE 11.x, Lua 5.1 compatible. No threads, no sockets, no FFI, no `love.thread`/`love.video`. Saves to `love.filesystem` (cloud-synced via `<save>/zmine/save.json` on the portal).

Achievements declared in `achievements.json`; emitted via `[[LOVEWEB_ACH]]unlock <key>` magic-print. Portal screen FX (flash, shake, ripple, glow, mood, calm, pulsate) emitted via `[[LOVEWEB_FX]]`.

## License

MIT — see `LICENSE`.
