# CrieffMap — Minimap That Moves Out Of Your Way

Do you like having your minimap in the middle of the screen while you're running around the world, but hate it being there the moment you zone into a dungeon? I do, and I got tired of dragging it back and forth!

CrieffMap is a tiny World of Warcraft addon that moves your minimap to a spot you choose whenever you're out in the open world, and snaps it straight back to its normal home the instant you enter any instanced content — dungeon, raid, delve, scenario, arena or battleground.

![CrieffMap preview](https://raw.githubusercontent.com/rkst/CrieffMap/main/media/placeholder.png "CrieffMap preview — replace with a real screenshot")

## Overview

You pick one outdoor position. From then on CrieffMap watches every zone change:

- **Outdoors** → the minimap jumps to your saved spot.
- **Inside an instance** → the minimap returns to wherever it normally lives (the position it had when you logged in).

That's the whole addon. No options frame, no profiles, no extra buttons.

## Setting Your Outdoor Spot

While standing in the open world:

1. Type `/cmap drag`.
2. Drag the minimap to wherever you want it for outdoor play.
3. Type `/cmap drag` again to save.

The position is stored per-character, so each character can have its own layout.

## Slash Commands

- `/cmap drag` (or `/crieffmap drag`) — toggles drag mode: drag the minimap to your preferred outdoor spot, then run it again to save.
- `/cmap reset` — clears the saved spot. The minimap then stays in its normal location everywhere.
- `/cmap` — prints a short help line.

## How It Decides Indoors vs Outdoors

CrieffMap uses the game's own `IsInInstance()` check on every zone transition. Anything the game considers instanced — dungeons, raids, delves, scenarios, arenas and battlegrounds — counts as "indoors" and gets the original layout. Everything else is treated as the open world and gets your saved spot. Nothing to configure; new instanced content types are covered automatically.

## Installation

CrieffMap supports retail WoW (The War Within / Midnight, Interface 12.0.0+).

- **Manual** — download the latest release zip from the [Releases page](https://github.com/rkst/CrieffMap/releases) and extract it into `World of Warcraft/_retail_/Interface/AddOns/`.

## A Note On Edit Mode

In modern retail, the minimap's default position is managed by Blizzard's Edit Mode. CrieffMap re-applies your chosen position after every zone change, deliberately running just after Edit Mode settles its own layout so the two don't fight. This covers normal play. In the unlikely event the minimap ends up somewhere unexpected outdoors, a reload (`/reload`) will sort it — and please open an issue so it can be looked into.

## Reporting Issues

If something doesn't work, open an issue at https://github.com/rkst/CrieffMap/issues describing what you did and what the minimap did instead.
