# Fleet Almanac build script: regenerates gui/00_fleet_almanac.gui from the vanilla game files.
param(
	[string]$GameDir = 'D:\SteamLibrary\steamapps\common\Victoria 3\game',
	[string]$ModDir = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
# Reads vanilla files (read-only) and writes ONLY the mod GUI file. Usage: powershell -ExecutionPolicy Bypass -File tools\build_fleet_almanac.ps1 [-GameDir <...\Victoria 3\game>]
$game = Join-Path $GameDir 'gui'
$out  = Join-Path $ModDir 'gui\00_fleet_almanac.gui'
$utf8 = New-Object System.Text.UTF8Encoding($true)
$cp = [IO.File]::ReadAllLines("$game\country_panel.gui", $utf8)
$tb = [IO.File]::ReadAllLines("$game\shared\tab_bars.gui", $utf8)

function Check($arr, $line, $expected) {
	if ($arr[$line - 1].Trim() -ne $expected) { throw "Vanilla layout changed: line $line is '$($arr[$line - 1].Trim())', expected '$expected'" }
}
Check $cp 90  'type country_panel = default_block_window_two_lines {'
Check $cp 138 'tab_buttons = {'
Check $cp 241 'blockoverride "fifth_button_name" {'
Check $cp 243 '}'
Check $cp 244 '}'
Check $cp 340 'country_panel_interactions_content = {'
Check $cp 343 '}'
Check $cp 377 '}'
Check $tb 47  'type tab_buttons = hbox {'
Check $tb 317 '### END DIVIDER'
Check $tb 331 '}'

function Lines($s) { return ,($s -split "`r?`n") }

$header = Lines @'
# Fleet Almanac
# Adds an "Almanac" tab behind "Interactions" in the country panel of other countries.
# Contains generated copies of vanilla types (Victoria 3 1.13.11) - regenerate after game updates:
#   country_panel (game/gui/country_panel.gui)   -> overridden: uses fleet_almanac_tab_buttons, adds the Almanac content
#   tab_buttons   (game/gui/shared/tab_bars.gui) -> copied as fleet_almanac_tab_buttons with a 6th tab (vanilla tab_buttons untouched)
# This file must load BEFORE country_panel.gui (00_ prefix): the first type definition wins.
'@

$templates = Lines @'
### Vanilla information_tab_visibility, extended so the Information tab also hides while the Almanac tab is open
template fleet_almanac_information_tab_visibility {
	visible = "[Or( And( Country.IsLocalPlayer, Not(Or(InformationPanel.IsTabSelected('diplomacy'), InformationPanel.IsTabSelected('modifiers')))), And( Country.IsAIOrOtherPlayer, Not(Or(Or(Or(InformationPanel.IsTabSelected('politics'), InformationPanel.IsTabSelected('diplomacy')), InformationPanel.IsTabSelected('interactions')), InformationPanel.IsTabSelected('fleet_almanac')))))]"
}

template fleet_almanac_information_tab_visibility_not {
	visible = "[Not( Or( And( Country.IsLocalPlayer, Not(Or(InformationPanel.IsTabSelected('diplomacy'), InformationPanel.IsTabSelected('modifiers')))), And( Country.IsAIOrOtherPlayer, Not(Or(Or(Or(InformationPanel.IsTabSelected('politics'), InformationPanel.IsTabSelected('diplomacy')), InformationPanel.IsTabSelected('interactions')), InformationPanel.IsTabSelected('fleet_almanac'))))))]"
}
'@

$sixthTab = Lines @'
		### TAB 6 (Fleet Almanac)
		tab_button = {
			block "sixth_button_name" {}
			layoutstretchfactor_horizontal = 1
			layoutpolicy_horizontal = preferred
			block "height" {}

			block "sixth_button_visibility_checked" {
				visible = no
			}

			block "sixth_button_tooltip" {}
			using = tooltip_above

			block "sixth_button_click" {}

			textbox = {
				block "sixth_button" {
					raw_text = "Placeholder"
				}
				default_format = "#title"
				using = tab_text_properties
			}
		}
		icon = {
			block "sixth_button_name" {}
			using = selected_tabs
			layoutstretchfactor_horizontal = 1
			layoutpolicy_horizontal = preferred
			block "height" {}

			block "sixth_button_visibility" {
				visible = no
			}

			textbox = {
				block "sixth_button_selected" {
					raw_text = "#BOLD Placeholder#!"
				}
				default_format = "#variable"
				using = tab_text_properties
			}
		}

'@

$sixthOverrides = Lines @'

				# Fleet Almanac (mod)
				blockoverride "sixth_button" {
					text = "FLEET_ALMANAC_TAB"
				}
				blockoverride "sixth_button_tooltip" {
					tooltip = "FLEET_ALMANAC_TAB_TOOLTIP"
				}
				blockoverride "sixth_button_click" {
					onclick = "[InformationPanel.SelectTab('fleet_almanac')]"
				}
				blockoverride "sixth_button_visibility" {
					visible = "[And(Country.IsAIOrOtherPlayer,InformationPanel.IsTabSelected('fleet_almanac'))]"
				}
				blockoverride "sixth_button_visibility_checked" {
					visible = "[And(Country.IsAIOrOtherPlayer,Not(InformationPanel.IsTabSelected('fleet_almanac')))]"
				}
				blockoverride "sixth_button_selected" {
					text = "FLEET_ALMANAC_TAB_SELECTED"
				}
'@

$slot = Lines @'

				fleet_almanac_content = {
					visible = "[And(Country.IsAIOrOtherPlayer,InformationPanel.IsTabSelected('fleet_almanac'))]"
					using = default_content_fade
				}
'@

$content = Lines @'
	### ALMANAC TAB CONTENT
	type fleet_almanac_content = flowcontainer {
		parentanchor = hcenter
		direction = vertical
		spacing = 5
		margin_top = 10
		margin_bottom = 10

		### SHIPS BY GROUP
		default_header = {
			blockoverride "text" {
				text = "FLEET_ALMANAC_SHIPS_HEADER"
			}
		}

		textbox = {
			visible = "[IsDataModelEmpty(Country.GetShipList.GetShips)]"
			parentanchor = hcenter
			autoresize = yes
			align = nobaseline
			margin = { 0 10 }
			using = fontsize_large
			using = empty_state_text_properties
			text = "FLEET_ALMANAC_NO_SHIPS"
		}

		flowcontainer = {
			parentanchor = hcenter
			direction = vertical
			spacing = 5
			datamodel = "[GetShipGroups]"

			item = {
				fleet_almanac_ship_group = {}
			}
		}

		### FLEETS
		default_header = {
			visible = "[Not(IsDataModelEmpty(Country.GetMilitaryFormationsFleet))]"

			blockoverride "text" {
				text = "FLEET_ALMANAC_FLEETS_HEADER"
			}
		}

		@@REGION_GROUPS@@

		### Fleets without a current HQ
		flowcontainer = {
			parentanchor = hcenter
			direction = vertical
			ignoreinvisible = yes

			flowcontainer = {
				direction = vertical
				spacing = -46
				ignoreinvisible = yes
				datamodel = "[Country.GetMilitaryFormationsFleet]"

				item = {
					fleet_almanac_region_header = {
						visible = "[Not(MilitaryFormation.GetCurrentHQ.IsValid)]"

						blockoverride "header_text" {
							text = "FLEET_ALMANAC_NO_HQ_HEADER"
						}

						blockoverride "zoom" {}
					}
				}
			}

			flowcontainer = {
				parentanchor = hcenter
				direction = vertical
				ignoreinvisible = yes
				datamodel = "[Country.GetMilitaryFormationsFleet]"

				item = {
					flowcontainer = {
						visible = "[Not(MilitaryFormation.GetCurrentHQ.IsValid)]"
						direction = vertical

						widget = {
							size = { 1 5 }
						}

						fleet_almanac_fleet_item = {}
					}
				}
			}
		}
	}

	### Fleets whose current HQ lies in this strategic region ("Stationed at"), no spacing so empty regions take no room
	type fleet_almanac_region_group = flowcontainer {
		parentanchor = hcenter
		direction = vertical
		ignoreinvisible = yes

		### Header: one identical copy per fleet in this region, stacked on top of each other
		### (spacing = -height), so it shows exactly once - or not at all for regions without fleets
		flowcontainer = {
			direction = vertical
			spacing = -46
			ignoreinvisible = yes
			datamodel = "[Country.GetMilitaryFormationsFleet]"

			item = {
				fleet_almanac_region_header = {
					visible = "[And(MilitaryFormation.GetCurrentHQ.IsValid, ObjectsEqual(MilitaryFormation.GetCurrentHQ.GetStrategicRegion.Self, StrategicRegion.Self))]"
				}
			}
		}

		flowcontainer = {
			parentanchor = hcenter
			direction = vertical
			ignoreinvisible = yes
			datamodel = "[Country.GetMilitaryFormationsFleet]"

			item = {
				flowcontainer = {
					visible = "[And(MilitaryFormation.GetCurrentHQ.IsValid, ObjectsEqual(MilitaryFormation.GetCurrentHQ.GetStrategicRegion.Self, StrategicRegion.Self))]"
					direction = vertical

					widget = {
						size = { 1 5 }
					}

					fleet_almanac_fleet_item = {}
				}
			}
		}
	}

	### Region header "Stationed at <region>" with zoom button (needs StrategicRegion context)
	type fleet_almanac_region_header = widget {
		size = { @panel_width 46 }

		widget = {
			parentanchor = bottom
			size = { 100% 36 }

			background = {
				using = dark_area
			}

			textbox = {
				parentanchor = vcenter
				position = { 10 0 }
				autoresize = yes
				max_width = 470
				elide = right
				align = nobaseline
				using = fontsize_large

				block "header_text" {
					text = "FLEET_ALMANAC_REGION_HEADER"
				}
			}

			block "zoom" {
				button_icon_zoom = {
					parentanchor = right|vcenter
					position = { -8 0 }
					size = { 28 28 }
					tooltip = "ZOOM_TO_STRATEGIC_REGION"
					onclick = "[StrategicRegion.ZoomToFar]"
				}
			}
		}
	}

	### One ship group: header (click = show/hide ships), templates, optional ship list
	type fleet_almanac_ship_group = flowcontainer {
		datacontext = "[Country.GetShipList]"
		visible = "[NotZero(ShipList.GetNumShipsOfGroup(ShipGroup.Self))]"
		direction = vertical
		minimumsize = { @panel_width -1 }

		background = {
			using = entry_bg
		}

		widget = {
			size = { @panel_width 40 }

			button = {
				size = { 100% 100% }
				using = default_button
				tooltip = "FLEET_ALMANAC_TOGGLE_SHIPS"
				onclick = "[GetVariableSystem.Toggle(Concatenate('fleet_almanac_group_', ShipGroup.GetKey))]"
			}

			flowcontainer = {
				parentanchor = vcenter
				position = { 8 0 }
				spacing = 5

				button = {
					visible = "[Not(GetVariableSystem.Exists(Concatenate('fleet_almanac_group_', ShipGroup.GetKey)))]"
					parentanchor = vcenter
					size = { 25 25 }
					using = expand_arrow
					alwaystransparent = yes
				}

				button = {
					visible = "[GetVariableSystem.Exists(Concatenate('fleet_almanac_group_', ShipGroup.GetKey))]"
					parentanchor = vcenter
					size = { 25 25 }
					using = expand_arrow_expanded
					alwaystransparent = yes
				}

				icon = {
					parentanchor = vcenter
					size = { 30 30 }
					texture = "[ShipGroup.GetIcon]"
				}

				textbox = {
					parentanchor = vcenter
					autoresize = yes
					align = nobaseline
					using = fontsize_large
					text = "FLEET_ALMANAC_GROUP"
				}
			}
		}

		flowcontainer = {
			datacontext = "[ShipList.GetFilterOfGroup(ShipGroup.Self)]"
			datamodel = "[ShipList.GetShipTemplatesOfGroup(ShipGroup.Self)]"
			margin = { 8 5 }
			spacing = 5
			wrap_count = 4

			item = {
				compact_ship_template = {
					size = { 126 40 }
				}
			}
		}

		flowcontainer = {
			visible = "[GetVariableSystem.Exists(Concatenate('fleet_almanac_group_', ShipGroup.GetKey))]"
			parentanchor = hcenter
			direction = vertical
			spacing = 2
			margin = { 0 5 }
			datamodel = "[ShipList.GetShipsOfGroup(ShipGroup.Self)]"

			item = {
				fleet_almanac_ship_row = {}
			}
		}
	}

	### One fleet: name, ships per group, status, HP, zoom (click = show/hide ships)
	type fleet_almanac_fleet_item = flowcontainer {
		parentanchor = hcenter
		direction = vertical
		minimumsize = { @panel_width -1 }

		background = {
			using = entry_bg
		}

		widget = {
			size = { @panel_width 60 }

			button = {
				size = { 100% 100% }
				using = default_button
				tooltip = "FLEET_ALMANAC_FLEET_TOOLTIP"
				onclick = "[GetVariableSystem.Toggle(Concatenate('fleet_almanac_fleet_', MilitaryFormation.GetIDString))]"
			}

			button = {
				visible = "[Not(GetVariableSystem.Exists(Concatenate('fleet_almanac_fleet_', MilitaryFormation.GetIDString)))]"
				parentanchor = vcenter
				position = { 8 0 }
				size = { 25 25 }
				using = expand_arrow
				alwaystransparent = yes
			}

			button = {
				visible = "[GetVariableSystem.Exists(Concatenate('fleet_almanac_fleet_', MilitaryFormation.GetIDString))]"
				parentanchor = vcenter
				position = { 8 0 }
				size = { 25 25 }
				using = expand_arrow_expanded
				alwaystransparent = yes
			}

			flowcontainer = {
				direction = vertical
				position = { 38 6 }
				spacing = 2

				textbox = {
					autoresize = yes
					max_width = 290
					elide = right
					align = nobaseline
					using = fontsize_large
					text = "FLEET_ALMANAC_FLEET_NAME"
				}

				flowcontainer = {
					datacontext = "[MilitaryFormation.GetShipList]"
					datamodel = "[GetShipGroups]"
					spacing = 10

					item = {
						flowcontainer = {
							visible = "[NotZero(ShipList.GetNumShipsOfGroup(ShipGroup.Self))]"
							tooltip = "[ShipGroup.GetNameNoFormatting]"
							spacing = 3

							icon = {
								parentanchor = vcenter
								size = { 20 20 }
								texture = "[ShipGroup.GetIcon]"
							}

							textbox = {
								parentanchor = vcenter
								autoresize = yes
								align = nobaseline
								raw_text = "#v [ShipList.GetNumShipsOfGroup(ShipGroup.Self)]#!"
							}
						}
					}
				}
			}

			flowcontainer = {
				parentanchor = right|vcenter
				position = { -45 0 }
				direction = vertical
				spacing = 2

				textbox = {
					parentanchor = right
					autoresize = yes
					max_width = 160
					elide = right
					align = right|nobaseline
					using = fontsize_small
					text = "[MilitaryFormation.GetShortFormationStatusDesc]"
				}

				textbox = {
					parentanchor = right
					autoresize = yes
					align = right|nobaseline
					text = "FLEET_ALMANAC_FLEET_HP"
				}
			}

			button_icon_zoom = {
				parentanchor = right|vcenter
				position = { -8 0 }
				size = { 30 30 }
				tooltip = "FLEET_ALMANAC_ZOOM"
				onclick = "[MilitaryFormation.ZoomToMapMarkerPosition]"
			}
		}

		flowcontainer = {
			visible = "[GetVariableSystem.Exists(Concatenate('fleet_almanac_fleet_', MilitaryFormation.GetIDString))]"
			parentanchor = hcenter
			direction = vertical
			spacing = 2
			margin = { 0 5 }
			datacontext = "[MilitaryFormation.GetShipList]"
			datamodel = "[ShipList.GetShips]"

			item = {
				fleet_almanac_ship_row = {
					blockoverride "second_column" {
						textbox = {
							parentanchor = vcenter
							position = { 295 0 }
							autoresize = yes
							max_width = 150
							elide = right
							align = nobaseline
							using = fontsize_small
							raw_text = "[Ship.GetTemplate.GetNameNoFormatting]"
						}
					}
				}
			}
		}
	}

	### One ship: silhouette, name, fleet (or template), HP; vanilla ship tooltip
	type fleet_almanac_ship_row = button {
		size = { 530 34 }
		using = default_button
		onclick = "[InformationPanelBar.OpenShipPanel(Ship.Self)]"

		tooltipwidget = {
			FancyTooltip_Ship = {}
		}

		widget = {
			parentanchor = vcenter
			position = { 5 0 }
			size = { 80 28 }
			alwaystransparent = yes

			background = {
				fittype = center
				texture = "[Ship.GetType.GetProfileTexture]"
			}
		}

		textbox = {
			parentanchor = vcenter
			position = { 90 0 }
			autoresize = yes
			max_width = 200
			elide = right
			align = nobaseline
			raw_text = "[JoinText(Nbsp, AddLocalizationIf(Ship.IsFlagship, '@flagship!'), Ship.GetNameNoFormatting)]"
		}

		block "second_column" {
			textbox = {
				parentanchor = vcenter
				position = { 295 0 }
				autoresize = yes
				max_width = 150
				elide = right
				align = nobaseline
				using = fontsize_small
				raw_text = "[Ship.GetFleet.GetNameNoFormatting]"
			}
		}

		textbox = {
			parentanchor = right|vcenter
			position = { -10 0 }
			autoresize = yes
			align = right|nobaseline
			text = "FLEET_ALMANAC_SHIP_HP"
		}
	}
'@

# Land strategic regions, read from the game files: a region counts as land if at least one of its states
# is a land state (has subsistence_building - the sea states in map_data/state_regions have none)
function Get-TopBlocks($path) {
	$text = (([IO.File]::ReadAllLines($path, $utf8)) | ForEach-Object { $_ -replace '#.*$', '' }) -join "`n"
	$depth = 0; $key = $null; $startIdx = 0
	$res = New-Object System.Collections.Generic.List[object]
	foreach ($m in [regex]::Matches($text, '([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{|\{|\}')) {
		if ($m.Value -eq '}') {
			$depth--
			if ($depth -eq 0 -and $key) { $res.Add([pscustomobject]@{ Key = $key; Body = $text.Substring($startIdx, $m.Index - $startIdx) }); $key = $null }
		} else {
			if ($depth -eq 0 -and $m.Groups[1].Success) { $key = $m.Groups[1].Value; $startIdx = $m.Index }
			$depth++
		}
	}
	return ,$res
}

$gameRoot = Split-Path $game -Parent
$landStates = @{}
foreach ($f in (Get-ChildItem "$gameRoot\map_data\state_regions" -Filter '*.txt')) {
	foreach ($b in (Get-TopBlocks $f.FullName)) { if ($b.Body -match '\bsubsistence_building\b') { $landStates[$b.Key] = $true } }
}
if ($landStates.Count -eq 0) { throw 'No land states found' }

$regions = New-Object System.Collections.Generic.List[string]
foreach ($f in (Get-ChildItem "$gameRoot\common\strategic_regions" -Filter '*.txt' | Sort-Object Name)) {
	foreach ($b in (Get-TopBlocks $f.FullName)) {
		if ($b.Body -match '(?s)states\s*=\s*\{([^}]*)\}') {
			$stateKeys = [regex]::Matches($Matches[1], '[A-Za-z_][A-Za-z0-9_]*') | ForEach-Object { $_.Value }
			if (@($stateKeys | Where-Object { $landStates.ContainsKey($_) }).Count -gt 0) { $regions.Add($b.Key) }
		}
	}
}
if ($regions.Count -eq 0) { throw 'No land strategic regions found' }

$regionLines = New-Object System.Collections.Generic.List[string]
$regionLines.Add("		### Land strategic regions ($($regions.Count), generated from game/common/strategic_regions): one group per region")
$regionLines.Add('		flowcontainer = {')
$regionLines.Add('			parentanchor = hcenter')
$regionLines.Add('			direction = vertical')
$regionLines.Add('			ignoreinvisible = yes')
$regionLines.Add('')
foreach ($r in $regions) {
	$regionLines.Add("			fleet_almanac_region_group = { datacontext = `"[GetStrategicRegion('$r')]`" }")
}
$regionLines.Add('		}')

$contentList = New-Object System.Collections.Generic.List[string]
foreach ($s in $content) {
	if ($s.Trim() -eq '@@REGION_GROUPS@@') { foreach ($x in $regionLines) { $contentList.Add($x) } } else { $contentList.Add($s) }
}
$content = $contentList
"land strategic regions: $($regions.Count)"


# country_panel copy (lines 90-377) with the tab bar swapped, 6th tab overrides and the Almanac content slot
$panel = New-Object System.Collections.Generic.List[string]
for ($i = 90; $i -le 377; $i++) {
	$l = $cp[$i - 1]
	if ($i -eq 138) { $l = $l.Replace('tab_buttons = {', 'fleet_almanac_tab_buttons = {') }
	$l = $l.Replace('information_tab_visibility', 'fleet_almanac_information_tab_visibility')
	$panel.Add($l)
	if ($i -eq 243) { foreach ($s in $sixthOverrides) { $panel.Add($s) } }
	if ($i -eq 343) { foreach ($s in $slot) { $panel.Add($s) } }
}

# tab_buttons copy (lines 47-331) renamed, with a 6th tab before the end divider
$tabs = New-Object System.Collections.Generic.List[string]
for ($i = 47; $i -le 331; $i++) {
	$l = $tb[$i - 1]
	if ($i -eq 47) { $l = $l.Replace('type tab_buttons = hbox {', 'type fleet_almanac_tab_buttons = hbox {') }
	if ($i -eq 317) { foreach ($s in $sixthTab) { $tabs.Add($s) } }
	$tabs.Add($l)
}

$all = New-Object System.Collections.Generic.List[string]
foreach ($s in $header) { $all.Add($s) }
foreach ($s in $cp[1..10]) { $all.Add($s) }   # @panel_width constants (file-local in vanilla)
$all.Add('')
foreach ($s in $templates) { $all.Add($s) }
$all.Add('')
$all.Add('types fleet_almanac_types')
$all.Add('{')
foreach ($s in $tabs) { $all.Add($s) }
$all.Add('')
foreach ($s in $panel) { $all.Add($s) }
$all.Add('')
foreach ($s in $content) { $all.Add($s) }
$all.Add('}')

[IO.File]::WriteAllLines($out, $all, $utf8)

$o = 0; $c = 0
foreach ($l in $all) { $x = ($l -replace '"[^"]*"', '') -replace '#.*$', ''; $o += ([regex]::Matches($x, '\{')).Count; $c += ([regex]::Matches($x, '\}')).Count }
"written: $out"
"lines: $($all.Count)  braces open=$o close=$c"
