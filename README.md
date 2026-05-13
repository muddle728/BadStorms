# BadStorms

Raid helper for master loot management, soft reserves, and rolls.

## Commands

- `/badstorms` or `/bs` — Toggle the config frame

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

## Tabs

- **Settings** — Enable automation, auto-loot, auto-master-loot, configure disenchanter
- **Award** — Award items to players (requires master looter)
- **Roll** — Start/end rolls, award to winner
- **Soft-Reserves** — Import SR CSV, view players with/without SR
- **Plus Ones** — Track plus-one counts from MS rolls
- **Export** — View and export award history

## Importing Soft Reserves

1. Go to the Soft-Reserves tab
2. Click **Import**
3. Paste CSV data from softres.it
4. Click **Import**

The SR tab shows all raid/party members — players with SR (class-colored) and players missing SR (red).

## Auto-Loot

When enabled in Settings, while you are master looter:
- Gray/white items → looted to you
- Green items (equippable) → sent to the configured disenchanter
- Blue+ items → master looted to you
