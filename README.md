# CrieffMap

A small World of Warcraft addon that moves your minimap to a spot you pick while you're out in the open world, then puts it back to its normal place the moment you zone into instanced content (dungeon, raid, delve, scenario, arena or battleground).

I like my minimap near the middle of the screen while questing, but not while I'm in a dungeon. I got tired of dragging it back and forth, so I wrote this.

![CrieffMap preview](https://raw.githubusercontent.com/rkst/CrieffMap/main/media/placeholder.png "CrieffMap preview, replace with a real screenshot")

## How it works

You pick one outdoor position. After that, CrieffMap watches every zone change:

- **Outdoors:** the minimap jumps to your saved spot.
- **Inside an instance:** the minimap goes back to wherever it normally lives (the position it had when you logged in).

That's the whole addon. There's no options panel, no profiles, and no extra buttons.

## Setting your outdoor spot

While standing in the open world:

1. Type `/cmap drag`. A small panel with **Save** and **Cancel** buttons appears.
2. Drag the minimap to wherever you want it for outdoor play. You can drag it as many times as you like to get it right.
3. Click **Save** to keep it, or **Cancel** to put it back where it was.

The position is saved per character, so each of your characters can have its own layout.

## Slash commands

- `/cmap drag` (or `/crieffmap drag`): enter drag mode, move the minimap, then click **Save** (or **Cancel** to discard).
- `/cmap reset`: clear the saved spot. The minimap then stays in its normal place everywhere.
- `/cmap`: print a short help line.

## How it decides indoors vs outdoors

CrieffMap uses the game's own `IsInInstance()` check on every zone transition. Anything the game counts as instanced (dungeons, raids, delves, scenarios, arenas and battlegrounds) is treated as indoors and gets the original layout. Everything else is treated as the open world and gets your saved spot. There's nothing to configure, and new instanced content types are handled automatically.

## Installation

CrieffMap supports retail WoW (The War Within / Midnight, Interface 12.0.0 and up).

Download the latest release zip from the [Releases page](https://github.com/rkst/CrieffMap/releases) and extract it into `World of Warcraft/_retail_/Interface/AddOns/`.

## A note on Edit Mode

In modern retail, the minimap's default position is handled by Blizzard's Edit Mode. CrieffMap re-applies your chosen position after every zone change, and it deliberately runs just after Edit Mode settles its own layout so the two don't fight. This covers normal play. If the minimap ever ends up somewhere unexpected outdoors, a reload (`/reload`) will sort it out. Please open an issue if that happens so it can be looked into.

## Compatibility with full UI replacements (EllesmereUI and similar)

Some all-in-one UI addons, EllesmereUI being the common one, don't just move the minimap. They detach it from Blizzard's `MinimapCluster`, parent it straight to the screen, and hide the original cluster. CrieffMap detects this and moves whichever frame is actually showing the map, so it behaves the same way: your saved spot is used outdoors, and inside instances the minimap returns to wherever that addon normally puts it. Set your spot with `/cmap drag` exactly as described above.

## Reporting issues

If something doesn't work, open an issue at https://github.com/rkst/CrieffMap/issues and describe what you did and what the minimap did instead.
