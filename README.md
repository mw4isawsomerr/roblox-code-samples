# Roblox Code Samples — Trevor Trosko

A small set of Luau scripts pulled from a live Roblox game I work on, chosen to
show how I write: pure functions where they belong, a shared UI system instead of
copy-paste, client-side animation that stays smooth under streaming, and HUD code
that derives its numbers instead of trusting a second source of truth.

These are real production files, lightly selected. Nothing here touches purchases,
data saving, moderation, or anti-exploit — that code stays private, as it should.

**Contact:** Discord `lasteroiddaddyhackiv`

---

## What's here

| File | Where it runs | What it shows |
|------|---------------|---------------|
| `ReplicatedStorage/ObstacleMotion.lua` | Server + client | A stateless, pure-function obstacle system. The same function gives authority on the server and smooth visuals on the client, synced by server time instead of replication. |
| `ReplicatedStorage/UITheme.lua` | Shared | The game's UI framework: colour tokens, typography, cards, buttons, number formatting, and one responsive scale rule for every screen. |
| `ReplicatedStorage/AccessoryMotion.lua` | Shared | One motion description read by three renderers (the pet in the world, the checkout preview, the item thumbnail) so what you buy is what you were shown. |
| `StarterPlayerScripts/TreadmillAnimator.lua` | Client | A single RenderStepped loop driving belt stripes, digital-rain decks and part motion, with self-healing tracking that survives StreamingEnabled. |
| `StarterPlayerScripts/StatHud.lua` | Client | The Speed/Money HUD, built on `UITheme`. Derives the true multiplier rather than trusting a published value, and reseats itself under the mobile nav grid. |

## How it's organised

Folders mirror their Roblox service, so the path tells you where each script lives:

- `ReplicatedStorage/` — modules shared by server and client
- `StarterPlayerScripts/` — client scripts that run for each player

## Notes

- Written for Roblox's Luau, tested in Studio and live.
- Comments explain the *why* — the bug that forced a decision, the constraint behind
  a number — not just the *what*.
- These are samples for review, not a drop-in library.
