# Fleet Almanac – Projektnotizen für Claude

UI-Mod für **Victoria 3 (1.14.x)**: fügt im Länderfenster jedes Landes (auch dem eigenen) einen Tab **„Almanac"** hinter „Interactions" hinzu – Übersicht über Schiffe und Flotten. Rein kosmetisch, keine Skript-Effekte, nichts im Spielstand.

Nutzer spricht Deutsch; Antworten auf Deutsch. Code-Kommentare, README, Commit-Messages und Mod-Texte auf Englisch.

## Harte Regeln

- **Spielordner `D:\SteamLibrary\steamapps\common\Victoria 3` nur lesen/kopieren, niemals schreiben.** Schreiben nur in diesem Mod-Ordner (und im Scratchpad).
- **`gui/00_fleet_almanac.gui` nie von Hand bearbeiten** – wird von `tools/build_fleet_almanac.ps1` erzeugt. Änderungen immer im Skript machen, dann neu bauen:
  `powershell -NoProfile -ExecutionPolicy Bypass -File tools\build_fleet_almanac.ps1`
- **Git:** keine Branches/PRs. Nach Bestätigung durch den Nutzer (meist nach Test im Spiel) direkt auf `main` committen und pushen. Commit-Messages mit `Co-Authored-By`-Zeile.
- **Commit-Messages per Datei** (`git commit -F <datei>`): Windows PowerShell 5.1 zerlegt doppelte Anführungszeichen in Here-Strings an native Programme.

## Struktur

| Pfad | Zweck |
|---|---|
| `gui/00_fleet_almanac.gui` | Generiert. Muss **vor** `country_panel.gui` laden (`00_`-Präfix): bei doppelten GUI-Typen gewinnt die **erste** Definition |
| `tools/build_fleet_almanac.ps1` | Build-Skript (Parameter `-GameDir`, `-ModDir`) |
| `localization/english`, `localization/german` | `fleet_almanac_l_*.yml` – UTF-8 **mit BOM**, genau ein Schlüssel pro Zeile |
| `.metadata/metadata.json` | Launcher-Metadaten (`id: fleet_almanac`, `multiplayer_synchronized: false`) |
| `thumbnail.png`, `.metadata/thumbnail.png` | Vorschaubild (1024×1024, 1,35 MB – für Steam zu groß, siehe unten) |
| `docs/` | Screenshots für README/Mod-Seite |
| `tools/steam_preview.png`, `tools/steam_preview.vdf` | 512×512-Vorschau + SteamCMD-Konfiguration |

## Was das Build-Skript tut

1. Kopiert Vanilla-Typen und prüft deren Zeilen per `Check` (bricht bei Patch-Änderungen ab):
   - `country_panel` (`game/gui/country_panel.gui`, Z. 90–377) → überschrieben: nutzt `fleet_almanac_tab_buttons`, Tab 6 + Almanach-Inhalt, eigene `information_tab_visibility`-Templates
   - `tab_buttons` (`game/gui/shared/tab_bars.gui`, Z. 47–331) → als `fleet_almanac_tab_buttons` mit 6. Tab (Vanilla bleibt unberührt)
   - Die `@panel_width`-Konstanten sind dateilokal und werden mitkopiert
2. Erzeugt Listen aus Spieldateien und ersetzt Platzhalter:
   - `@@MOD_SLOTS@@` (Vorlagen) / `@@MOD_SLOTS_SHIP@@` (Schiffe im Tooltip): Nicht-Utility-Slots aus `common/ship_modification_slots` in Dateireihenfolge (armor, guns, propulsion, range)
3. Prüft Klammerbalance. Danach immer auch Lokalisierung gegen die GUI prüfen (fehlende/ungenutzte Keys, BOM, ein Key pro Zeile).

Nach einem Spielupdate: Skript laufen lassen; bei Abbruch die gemeldeten Vanilla-Zeilen neu abgleichen und `supported_game_version` anpassen.

## Aktueller Aufbau des Tabs

- **Ships:** pro Schiffsgruppe (`GetShipGroups`) ein Kopf „Capital Ships: N", darunter **eine Zeile pro Vorlage** (`ShipList.GetShipTemplatesOfGroup`): Anzahl (+ im Bau), Silhouette, Typname / Vorlagenname, Modifikationen nach Slot (linksbündig, ohne Utility-Extras), Panzerung + Rumpfschaden (Vorlagen-Grundwerte wie im Bau-Menü).
  - ⬆-Marker unter der Anzahl, wenn Schiffe dieser Vorlage veraltet sind (`ShipList.GetShipsOfTemplate`); Tooltip listet diese Schiffe mit tatsächlicher Ausstattung (`Ship.GetModifications`, `GetArmor`, `GetHullDamage`).
- **Fleets:** flache Liste in Spielreihenfolge (`Country.GetMilitaryFormationsFleet`). Früher nach Region gruppiert (142 Regionen × 2 Datamodels über alle Flotten) – aus Performancegründen zurückgebaut.
  - Eine Zeile pro Flotte: Flagge, Name, Status, Ort (HQ-Region `GetCurrentHQ.GetStrategicRegion` „Stationed at", sonst Seeregion `GetCurrentSeaNode.GetStateRegion.GetStrategicRegion` „At", sonst „Unknown location"), Symbol+Anzahl pro Schiffsgruppe (Tooltip: Vorlagen der Gruppe), „⬆ N" veraltete Schiffe, Gehe-zu-Knopf. Aufklappen zeigt dieselbe Vorlagen-Liste für die Flotte (`MilitaryFormation.GetShipList` als Datacontext).
- **Karte:** `mm_military` per `SetTempMapModeByKey` / `RemoveTempMapMode` beim Hover über dem Inhalt.

## GUI-Modding-Erkenntnisse (Victoria 3 / Jomini)

- **Doppelte Typen:** erste geladene Definition gewinnt → `00_`-Präfix. Typ-Änderungen brauchen **Spielneustart**; GUI-Hot-Reload im Debug-Modus reicht dafür nicht.
- **GUI kann nicht sortieren:** kein generisches Datamodel-Sort, nur fest eingebaute Panel-Sortierungen (keine für Flotten nach Ort).
- **Performance:** Datamodel-Items existieren auch mit `visible = no` (ob ihre Kinder dann aktualisiert werden, ist ungeklärt) – Muster „N feste Gruppen × Datamodel über alle Objekte mit Filter" skaliert schlecht, sparsam einsetzen.
- **GUI kann nicht zählen, sammeln oder deduplizieren.** Workaround für „Überschrift genau einmal / gar nicht": pro passendem Element eine identische Kopie, gestapelt mit negativem `spacing` (= -Höhe) und `ignoreinvisible = yes`.
- Kein Zähler für veraltete Schiffe pro Vorlage (nur `GetNumShipsOutdatedOfGroup`, `GetNumShipsOutdated`). Auch per Script Value nicht lösbar (kein Outdated-Trigger, kein Ship→Template-Link im Skript).
- Kein `Province.IsValid` → leere Referenzen über `StringIsEmpty(...GetNameNoFormatting)` prüfen. `ObjectsEqual(A.Self, B.Self)` zum Vergleichen.
- Regionen direkt adressierbar: `GetStrategicRegion('region_key')`; Slots: `GetShipModificationSlotType('key')`.
- Vorlagen-Tooltip wiederverwendbar: `RegularTooltip_AdditionalShipTypes` (Blöcke `header_text`, `datamodel`). Eigene Tooltips: `type X = RegularTooltip { blockoverride "tooltip_content_after" { … } }`.
- `ship_item` (Schiffskarten) enthält fest eingebaute Umrüst-Knöpfe – verworfen, zu komplex für den Nutzer.
- Standarddaten der Vorlagen via `ShipTemplate.GetModifier.GetValueFor('ship_armor_add' | 'ship_hull_damage_add')` (keine Landesboni).
- Datentypen-Referenz: im Spiel-Konsole `dump_data_types` → `Documents\Paradox Interactive\Victoria 3\logs\data_types\`. Skript-Doku: `script_docs` → `...\Victoria 3\docs\`. Fehler: `...\logs\error.log`.

## Veröffentlichung

- **Steam Workshop:** Item `3801188659` (App `529340`). **Paradox Mods:** ID `159081`. GitHub: https://github.com/scuzzar/vic3-almanac
- Der Launcher hat **keine Vorschaubild-Option für Steam**, und Steam akzeptiert Vorschaubilder nur **bis 1 MB**. Vorschau per SteamCMD setzen (Nutzer führt aus und gibt Zugangsdaten selbst ein):
  `C:\Users\scuzz\Downloads\steamcmd.exe +login scuzzar +workshop_build_item "<Mod-Ordner>\tools\steam_preview.vdf" +quit`
  Log: `C:\Users\scuzz\Downloads\logs\workshop_log.txt` („File Not Found" = Item-ID existiert nicht).
- Der Launcher packt den ganzen Mod-Ordner (inkl. `.git`, `docs`, `tools`) – ca. 12 MB statt ~100 KB.
- Launcher-Tags werden im Upload-Dialog gewählt (`tags` in metadata.json leer lassen). Passend: Utilities (ggf. Warfare), nicht Graphics.
- Keine DLC-Abhängigkeit (nur Grundspiel-Daten, keine `HasDlcFeature`-Abfragen). Nur mit allen DLCs getestet.

## Arbeitsweise mit dem Nutzer

- Nutzer testet im Spiel und schickt Screenshots; Iterationen sind kurz. Lieber schlank und mit wenig Klicks als vollständig – zu komplexe Layouts wurden mehrfach zurückgebaut.
- Bei Unsicherheit über Datenfunktionen erst in `data_types` / Vanilla-GUI nachsehen, nicht raten. Ergebnisse, die nur per Build-Checks und nicht im Spiel geprüft sind, als ungetestet kennzeichnen.
