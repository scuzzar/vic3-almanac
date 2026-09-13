# Fleet Almanac

A lean UI mod for **Victoria 3** (1.13.x) that adds an **Almanac** tab to the country panel of other countries, giving an overview of their navy:

- **Ships** by ship group and ship template, with an expandable list of individual ships (name, fleet, hit points; vanilla ship tooltip)
- **Fleets** grouped by the strategic region they are currently stationed in (current HQ): one line per fleet (name, status, ships, hit points, zoom) that expands to the fleet's ship cards, separated by ship group

The mod is purely cosmetic: no scripted effects, nothing is written to the save game.

> This mod was developed with extensive AI assistance (Claude by Anthropic).

## Structure

| Path | Purpose |
|---|---|
| `gui/00_fleet_almanac.gui` | Generated GUI file (do not edit by hand, see below) |
| `localization/english`, `localization/german` | Texts |
| `tools/build_fleet_almanac.ps1` | Build script that generates the GUI file |
| `.metadata/metadata.json` | Launcher metadata |

## Rebuilding after a game update

`gui/00_fleet_almanac.gui` contains copies of vanilla types (`country_panel`, `tab_buttons`, `ship_item` without the retrofit buttons) and the list of land strategic regions, all taken from the installed game. After a game update, regenerate it:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_fleet_almanac.ps1
```

Use `-GameDir "<path>\Victoria 3\game"` if the game is not installed at the default path in the script. The script only reads the game files and aborts with a message if the vanilla files changed in a way that needs manual attention.

The file is named `00_...` on purpose: it must load before the vanilla `country_panel.gui`, because the first definition of a GUI type wins.
