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
# Adds an "Almanac" tab to the country panel of every country (other countries and the player's own).
# Contains generated copies of vanilla types (Victoria 3 1.13.11) - regenerate after game updates:
#   country_panel (game/gui/country_panel.gui)   -> overridden: uses fleet_almanac_tab_buttons, adds the Almanac content
#   tab_buttons   (game/gui/shared/tab_bars.gui) -> copied as fleet_almanac_tab_buttons with a 6th tab (vanilla tab_buttons untouched)
#   generated lists: land and sea strategic regions (common/strategic_regions), ship modification slots (common/ship_modification_slots)
# This file must load BEFORE country_panel.gui (00_ prefix): the first type definition wins.
'@

$templates = Lines @'
### Vanilla information_tab_visibility, extended so the Information tab also hides while the Almanac tab is open
template fleet_almanac_information_tab_visibility {
	visible = "[Or( And( Country.IsLocalPlayer, Not(Or(Or(InformationPanel.IsTabSelected('diplomacy'), InformationPanel.IsTabSelected('modifiers')), InformationPanel.IsTabSelected('fleet_almanac')))), And( Country.IsAIOrOtherPlayer, Not(Or(Or(Or(InformationPanel.IsTabSelected('politics'), InformationPanel.IsTabSelected('diplomacy')), InformationPanel.IsTabSelected('interactions')), InformationPanel.IsTabSelected('fleet_almanac')))))]"
}

template fleet_almanac_information_tab_visibility_not {
	visible = "[Not( Or( And( Country.IsLocalPlayer, Not(Or(Or(InformationPanel.IsTabSelected('diplomacy'), InformationPanel.IsTabSelected('modifiers')), InformationPanel.IsTabSelected('fleet_almanac')))), And( Country.IsAIOrOtherPlayer, Not(Or(Or(Or(InformationPanel.IsTabSelected('politics'), InformationPanel.IsTabSelected('diplomacy')), InformationPanel.IsTabSelected('interactions')), InformationPanel.IsTabSelected('fleet_almanac'))))))]"
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
					visible = "[InformationPanel.IsTabSelected('fleet_almanac')]"
				}
				blockoverride "sixth_button_visibility_checked" {
					visible = "[Not(InformationPanel.IsTabSelected('fleet_almanac'))]"
				}
				blockoverride "sixth_button_selected" {
					text = "FLEET_ALMANAC_TAB_SELECTED"
				}
'@

$slot = Lines @'

				fleet_almanac_content = {
					visible = "[InformationPanel.IsTabSelected('fleet_almanac')]"
					using = default_content_fade
				}
'@

$content = Lines @'
	### ALMANAC TAB CONTENT
	type fleet_almanac_content = flowcontainer {
		### Military map mode (fleets, HQs, naval missions) while the mouse is over the Almanac, like vanilla hover map modes
		alwaystransparent = no
		onmousehierarchyenter = "[SetTempMapModeByKey('mm_military')]"
		onmousehierarchyleave = "[RemoveTempMapMode]"

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
				fleet_almanac_ship_group = { datacontext = "[Country.GetShipList]" }
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

		### Fleets with neither a current HQ nor a sea node
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
						visible = "[And(Not(MilitaryFormation.GetCurrentHQ.IsValid), StringIsEmpty(MilitaryFormation.GetCurrentSeaNode.GetStateRegion.GetStrategicRegion.GetNameNoFormatting))]"

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
						visible = "[And(Not(MilitaryFormation.GetCurrentHQ.IsValid), StringIsEmpty(MilitaryFormation.GetCurrentSeaNode.GetStateRegion.GetStrategicRegion.GetNameNoFormatting))]"
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

	### Fleets currently in this strategic region: stationed at an HQ there, or (without HQ) at a sea node of this sea region; no spacing so empty regions take no room
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
					visible = "[Or(And(MilitaryFormation.GetCurrentHQ.IsValid, ObjectsEqual(MilitaryFormation.GetCurrentHQ.GetStrategicRegion.Self, StrategicRegion.Self)), And(Not(MilitaryFormation.GetCurrentHQ.IsValid), ObjectsEqual(MilitaryFormation.GetCurrentSeaNode.GetStateRegion.GetStrategicRegion.Self, StrategicRegion.Self)))]"

					
blockoverride "header_text" {
						
text = "[SelectLocalization(MilitaryFormation.GetCurrentHQ.IsValid, 'FLEET_ALMANAC_REGION_HEADER', 'FLEET_ALMANAC_SEA_HEADER')]"
					
}
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
					visible = "[Or(And(MilitaryFormation.GetCurrentHQ.IsValid, ObjectsEqual(MilitaryFormation.GetCurrentHQ.GetStrategicRegion.Self, StrategicRegion.Self)), And(Not(MilitaryFormation.GetCurrentHQ.IsValid), ObjectsEqual(MilitaryFormation.GetCurrentSeaNode.GetStateRegion.GetStrategicRegion.Self, StrategicRegion.Self)))]"
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

	### One ship group of a ship list (country or fleet - set the ShipList as datacontext where it is used):
	### header, then one line per ship template
	type fleet_almanac_ship_group = flowcontainer {
		visible = "[NotZero(ShipList.GetNumShipsOfGroup(ShipGroup.Self))]"
		parentanchor = hcenter
		direction = vertical
		minimumsize = { 520 -1 }
		maximumsize = { 520 -1 }
		spacing = 2
		margin_bottom = 5

		background = {
			using = entry_bg
		}

		### Group header: icon + "Capital Ships: 10"
		widget = {
			size = { 520 34 }

			flowcontainer = {
				parentanchor = vcenter
				position = { 10 0 }
				spacing = 5

				icon = {
					parentanchor = vcenter
					size = { 28 28 }
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

		### One line per ship template of this group
		flowcontainer = {
			parentanchor = hcenter
			direction = vertical
			spacing = 2
			datamodel = "[ShipList.GetShipTemplatesOfGroup(ShipGroup.Self)]"

			item = {
				fleet_almanac_template_line = {}
			}
		}
	}

	### One ship template: number of ships (+ under construction) with outdated marker below, type silhouette, ship type + template name,
	### modifications by slot (fixed order), defense (armor), offense (hull damage) - values as in the vanilla ship building menu
	type fleet_almanac_template_line = widget {
		size = { 510 40 }

		tooltipwidget = {
			FancyTooltip_ShipTemplate = {}
		}

		background = {
			using = dark_area
			alpha = 0.3
		}

		flowcontainer = {
			parentanchor = vcenter
			position = { 5 0 }
			spacing = 6

			### Number of ships, below it a marker if ships of this template are outdated
			flowcontainer = {
				parentanchor = vcenter
				direction = vertical
				ignoreinvisible = yes
				min_width = 34

				textbox = {
					parentanchor = hcenter
					autoresize = yes
					min_width = 30
					align = hcenter|nobaseline
					using = fontsize_small
					text = "FLEET_SHIP_TEMPLATE_NUMBER"

					background = {
						using = dark_area
						alpha = 0.5
						margin = { -2 -2 }
					}
				}

				### One copy per outdated ship of this template, stacked (spacing = -height): shown once or not at all
				flowcontainer = {
					parentanchor = hcenter
					direction = vertical
					spacing = -16
					ignoreinvisible = yes
					datamodel = "[ShipList.GetShipsOfType(ShipTemplate.GetType.Self)]"

					tooltipwidget = {
						fleet_almanac_outdated_ships_tooltip = {
							blockoverride "header_text" {
								text = "FLEET_ALMANAC_TEMPLATE_OUTDATED"
							}

							blockoverride "ships_datamodel" {
								datamodel = "[ShipList.GetShipsOfType(ShipTemplate.GetType.Self)]"
							}

							blockoverride "ship_filter" {
								visible = "[And(Ship.IsOutdated, ObjectsEqual(Ship.GetTemplate.Self, ShipTemplate.Self))]"
							}
						}
					}

					item = {
						icon = {
							visible = "[And(Ship.IsOutdated, ObjectsEqual(Ship.GetTemplate.Self, ShipTemplate.Self))]"
							size = { 16 16 }
							texture = "gfx/interface/icons/formation_order_icons/upgrade.dds"
						}
					}
				}
			}

			ship_type_silhouette = {
				datacontext = "[ShipTemplate.GetType]"
				parentanchor = vcenter
				size = { 60 26 }

				blockoverride "fittype" {
					fittype = start
				}
			}

			flowcontainer = {
				parentanchor = vcenter
				direction = vertical

				textbox = {
					autoresize = yes
					max_width = 140
					elide = right
					align = nobaseline
					text = "[ShipTemplate.GetType.GetNameNoFormatting]"
				}

				textbox = {
					autoresize = yes
					max_width = 140
					elide = right
					align = nobaseline
					using = fontsize_small
					text = "[ShipTemplate.GetNameNoFormatting]"
				}
			}
		}

		### Modifications, left-aligned, grouped by slot in a fixed order (generated from common/ship_modification_slots, utility slots left out)
		flowcontainer = {
			parentanchor = vcenter
			position = { 260 0 }
			ignoreinvisible = yes

			@@MOD_SLOTS@@
		}

		flowcontainer = {
			parentanchor = right|vcenter
			position = { -8 0 }
			spacing = 8

			textbox = {
				parentanchor = vcenter
				autoresize = yes
				min_width = 40
				align = right|nobaseline
				raw_text = "@ship_armor! #v [ShipTemplate.GetModifier.GetValueFor('ship_armor_add')|0]#!"
			}

			textbox = {
				parentanchor = vcenter
				autoresize = yes
				min_width = 40
				align = right|nobaseline
				raw_text = "@hull_attack_damage! #v [ShipTemplate.GetModifier.GetValueFor('ship_hull_damage_add')|0]#!"
			}
		}
	}

	### Tooltip: header text, then every outdated ship with its current equipment
	### (modifications by slot, same order as the template lines), armor and hull damage
	type fleet_almanac_outdated_ships_tooltip = RegularTooltip {
		blockoverride "tooltip_content_after" {
			custom_tooltip_textbox = {
				block "header_text" {
					text = "FLEET_ALMANAC_FLEET_OUTDATED"
				}
			}

			tooltip_divider = {}

			flowcontainer = {
				direction = vertical
				spacing = 3
				ignoreinvisible = yes

				block "ships_datamodel" {
					datamodel = "[ShipList.GetShips]"
				}

				item = {
					flowcontainer = {
						block "ship_filter" {
							visible = "[Ship.IsOutdated]"
						}

						spacing = 6

						DefaultTooltipTextBox = {
							parentanchor = vcenter
							min_width = 150
							max_width = 150
							elide = right
							fonttintcolor = "[TooltipInfo.GetTintColor]"
							text = "[Ship.GetNameNoFormatting]"
						}

						widget = {
							parentanchor = vcenter
							size = { 130 22 }

							flowcontainer = {
								parentanchor = vcenter
								ignoreinvisible = yes

								@@MOD_SLOTS_SHIP@@
							}
						}

						DefaultTooltipTextBox = {
							parentanchor = vcenter
							min_width = 45
							align = right|nobaseline
							fonttintcolor = "[TooltipInfo.GetTintColor]"
							raw_text = "@ship_armor! #v [Ship.GetArmor|0]#!"
						}

						DefaultTooltipTextBox = {
							parentanchor = vcenter
							min_width = 45
							align = right|nobaseline
							fonttintcolor = "[TooltipInfo.GetTintColor]"
							raw_text = "@hull_attack_damage! #v [Ship.GetHullDamage|0]#!"
						}
					}
				}
			}
		}
	}

	### One fleet in one line (click = show/hide ship breakdown): flag, name + status, ships per ship group, outdated ships, open fleet button
	type fleet_almanac_fleet_item = flowcontainer {
		parentanchor = hcenter
		direction = vertical
		minimumsize = { @panel_width -1 }
		maximumsize = { @panel_width -1 }

		background = {
			using = entry_bg
		}

		section_header_button = {
			datacontext = "[MilitaryFormation.GetShipList]"
			parentanchor = hcenter
			size = { @panel_width 48 }
			onmousehierarchyenter = "[AccessHighlightManager.HighlightMilitaryFormation( MilitaryFormation.Self )]"
			onmousehierarchyleave = "[AccessHighlightManager.RemoveHighlight]"

			blockoverride "onclick" {
				onclick = "[GetVariableSystem.Toggle(Concatenate('fleet_almanac_fleet_', MilitaryFormation.GetIDString))]"
			}

			blockoverride "onclick_showmore" {
				visible = "[Not(GetVariableSystem.Exists(Concatenate('fleet_almanac_fleet_', MilitaryFormation.GetIDString)))]"
			}

			blockoverride "onclick_showless" {
				visible = "[GetVariableSystem.Exists(Concatenate('fleet_almanac_fleet_', MilitaryFormation.GetIDString))]"
			}

			### Flag, name and status
			flowcontainer = {
				parentanchor = vcenter
				position = { 32 0 }
				spacing = 6

				icon = {
					parentanchor = vcenter
					size = { 36 36 }
					texture = "[MilitaryFormation.GetFlag]"
					color = "[MilitaryFormation.GetFlagColor]"
				}

				flowcontainer = {
					parentanchor = vcenter
					direction = vertical

					textbox = {
						autoresize = yes
						align = nobaseline
						elide = right
						max_width = 250
						default_format = "#header"
						text = "[MilitaryFormation.GetNameNoFormatting]"
					}

					textbox = {
						autoresize = yes
						align = nobaseline
						elide = right
						max_width = 250
						using = fontsize_small
						text = "[MilitaryFormation.GetShortFormationStatusDesc]"
					}
				}
			}

			### Ships per ship group (icon + number), button that opens the fleet
			flowcontainer = {
				parentanchor = right|vcenter
				position = { -8 0 }
				spacing = 12

				flowcontainer = {
					parentanchor = vcenter
					spacing = 10
					datamodel = "[GetShipGroups]"

					item = {
						flowcontainer = {
							visible = "[NotZero(ShipList.GetNumShipsOfGroup(ShipGroup.Self))]"
							parentanchor = vcenter
							spacing = 3
							### Tooltip: this group's ship templates in the fleet (silhouette + number)
							tooltipwidget = {
								RegularTooltip_AdditionalShipTypes = {
									blockoverride "header_text" {
										text = "FLEET_ALMANAC_GROUP"
									}

									blockoverride "datamodel" {
										datamodel = "[ShipList.GetShipTemplatesOfGroup(ShipGroup.Self)]"
									}
								}
							}

							icon = {
								parentanchor = vcenter
								size = { 26 26 }
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

				### Outdated ships in the fleet (tooltip lists them with their current equipment)
				flowcontainer = {
					visible = "[ShipList.HasAnyShipOutdated]"
					parentanchor = vcenter
					spacing = 2

					tooltipwidget = {
						fleet_almanac_outdated_ships_tooltip = {
							blockoverride "header_text" {
								text = "FLEET_ALMANAC_FLEET_OUTDATED"
							}
						}
					}

					icon = {
						parentanchor = vcenter
						size = { 22 22 }
						texture = "gfx/interface/icons/formation_order_icons/upgrade.dds"
					}

					textbox = {
						parentanchor = vcenter
						autoresize = yes
						align = nobaseline
						raw_text = "#v [ShipList.GetNumShipsOutdated]#!"
					}
				}

				button_icon_goto = {
					parentanchor = vcenter
					size = { 28 28 }
					using = tooltip_ne
					tooltip = "GO_TO_BUTTON_MILITARY_FORMATION"
					onclick = "[InformationPanelBar.OpenMilitaryFormationPanelTab( MilitaryFormation.Self, 'default' )]"
				}
			}
		}

		flowcontainer = {
			parentanchor = hcenter
			direction = vertical

			### Ship breakdown of the fleet: same layout as the Ships section (ship groups, types, templates)
			flowcontainer = {
				visible = "[GetVariableSystem.Exists(Concatenate('fleet_almanac_fleet_', MilitaryFormation.GetIDString))]"
				datacontext = "[MilitaryFormation.GetShipList]"
				parentanchor = hcenter
				direction = vertical
				ignoreinvisible = yes
				margin = { 0 5 }
				spacing = 3
				datamodel = "[GetShipGroups]"

				item = {
					fleet_almanac_ship_group = {}
				}
			}
		}
	}

'@

# Strategic regions, read from the game files (land first, then sea): a region counts as land if at least one of its states
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
$waterRegions = New-Object System.Collections.Generic.List[string]
foreach ($f in (Get-ChildItem "$gameRoot\common\strategic_regions" -Filter '*.txt' | Sort-Object Name)) {
	foreach ($b in (Get-TopBlocks $f.FullName)) {
		if ($b.Body -match '(?s)states\s*=\s*\{([^}]*)\}') {
			$stateKeys = [regex]::Matches($Matches[1], '[A-Za-z_][A-Za-z0-9_]*') | ForEach-Object { $_.Value }
			if (@($stateKeys | Where-Object { $landStates.ContainsKey($_) }).Count -gt 0) { $regions.Add($b.Key) } else { $waterRegions.Add($b.Key) }
		}
	}
}
if ($regions.Count -eq 0) { throw 'No land strategic regions found' }
$landCount = $regions.Count
$regions.AddRange($waterRegions)

$regionLines = New-Object System.Collections.Generic.List[string]
$regionLines.Add("		### Strategic regions ($landCount land + $($waterRegions.Count) sea, generated from game/common/strategic_regions): one group per region")
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
"strategic regions: $landCount land + $($waterRegions.Count) sea"


# Ship modification slots in a fixed order (non-utility slots from common/ship_modification_slots):
# one icon group per slot, replacing @@MOD_SLOTS@@ (ship template lines) and @@MOD_SLOTS_SHIP@@ (outdated ships tooltip)
$slotDir = Join-Path (Split-Path $game -Parent) 'common\ship_modification_slots'
$slots = New-Object System.Collections.Generic.List[string]
foreach ($f in (Get-ChildItem $slotDir -Filter '*.txt' | Sort-Object Name)) {
	foreach ($b in (Get-TopBlocks $f.FullName)) {
		if ($b.Body -notmatch '\butility\s*=\s*yes\b') { $slots.Add($b.Key) }
	}
}
if ($slots.Count -eq 0) { throw 'No non-utility ship modification slots found' }

function New-SlotLines($datamodel, $iconSize) {
	$res = New-Object System.Collections.Generic.List[string]
	foreach ($s in $slots) {
		$slotBlock = @"
						flowcontainer = {
							parentanchor = vcenter
							spacing = 2
							margin_right = 2
							ignoreinvisible = yes
							datamodel = "$datamodel"

							item = {
								icon = {
									visible = "[ObjectsEqual(ShipModificationType.GetSlotType.Self, GetShipModificationSlotType('$s').Self)]"
									size = { $iconSize $iconSize }
									texture = "[ShipModificationType.GetIcon]"

									tooltipwidget = {
										FancyTooltip_ShipModificationType = {}
									}
								}
							}
						}
"@
		$res.AddRange([string[]]($slotBlock -split "`r?`n"))
	}
	return ,$res
}

$slotReplacements = @{
	'@@MOD_SLOTS@@'      = (New-SlotLines '[ShipTemplate.GetModifications]' 22)
	'@@MOD_SLOTS_SHIP@@' = (New-SlotLines '[Ship.GetModifications]' 20)
}
$slotFound = @{}
$slotContent = New-Object System.Collections.Generic.List[string]
foreach ($x in $content) {
	$t = $x.Trim()
	if ($slotReplacements.ContainsKey($t)) { $slotFound[$t] = 1 + [int]$slotFound[$t]; $slotContent.AddRange([string[]]$slotReplacements[$t]) } else { $slotContent.Add($x) }
}
foreach ($k in $slotReplacements.Keys) { if ([int]$slotFound[$k] -ne 1) { throw "Expected exactly one $k placeholder, found $([int]$slotFound[$k])" } }
$content = $slotContent
"ship modification slots: $($slots -join ', ')"

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
