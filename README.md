# BadStorms



Raid helper for master loot management, soft reserves, and rolls. 

[Download BadStorms Loot Assistant](https://github.com/muddle728/BadStorms/releases/latest)

## Commands

- `/badstorms` or `/bs` — Toggle the config frame
- `/bsr` — Toggle the loot roller frame
- `/bst` or `/tradetimer` — Toggle the trade timer panel

## Shortcuts

| Shortcut | Action |
|---|---|
| **Alt+Click** (bag) | Select item for rolling |
| **Alt+Shift+Click** (bag) | Select item for awarding |
| **Alt+Click** (loot window) | Start a roll for the item |
| **Alt+Shift+Click** (loot window) | Open award dialog for the item |
| **Drag & drop** item onto the frame | Same as Alt+Click |
| **Ctrl+Scroll** on the frame | Adjust UI scale (0.60 – 1.25) |
| **Ctrl+Right Click** on the frame | Reset UI scale to 1.0 |

## Minimap Button

| Click | Action |
|---|---|
| **Left-click** | Toggle loot assistant (config frame) |
| **Right-click** | Toggle loot roller (floating roll window) |

## Tabs

- **Settings** — Enable automation, auto-loot, auto-master-loot, configure disenchanter
- **Award** — Award items to players (requires master looter)
- **Roll** — Start/end rolls, award to winner
- **Soft-Reserves** — Import SR CSV, view players with/without SR, SR+ values
- **Plus Ones** — Track plus-one counts from MS rolls
- **Export** — View and export award history

## Importing Soft Reserves

1. Go to the Soft-Reserves tab
2. Click **Import**
3. Paste CSV data from softres.it or raidres.top
4. Click **Import**

The SR tab shows all raid/party members — players with SR (class-colored) and players missing SR (red).

## Loot Roller

The floating loot roller provides a compact roll interface:

- Shows live roll results as players roll
- **Roll MS** / **Roll OS** buttons for quick rolling
- **Pass** button to dismiss
- Closes automatically after the configured timeout
- Tracks winner announcements from chat

## Trade Timer

A floating panel that tracks equippable BoP items with active 2-hour trade timers, sorted by expiry ascending (soonest first). Master looter only.

| Trigger | Action |
|---|---|
| **Loot a tradeable item** | Panel auto-opens |
| **Click an item** | Opens Award tab with the item pre-selected |
| **`/bst` or `/tradetimer`** | Toggle the panel manually |

The panel refreshes every 60 seconds while visible. Trade timer detection uses tooltip text scanning (`BIND_TRADE_TIME_REMAINING`), not `GetItemCooldown`, avoiding false positives from on-use trinkets or gear.

## Auto-Loot

When enabled in Settings, while you are master looter:
- Gray/white items → looted to you
- Green items (equippable) → sent to the configured disenchanter
- Blue+ items → master looted to you
