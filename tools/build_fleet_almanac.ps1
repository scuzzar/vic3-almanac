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
# Contains generated copies of vanilla types (Victoria 3 1.14.2) - regenerate after game updates:
#   country_panel (game/gui/country_panel.gui)   -> overridden: uses fleet_almanac_tab_buttons, adds the Almanac content
#   tab_buttons   (game/gui/shared/tab_bars.gui) -> copied as fleet_almanac_tab_buttons with a 6th tab (vanilla tab_buttons untouched)
#   generated lists: ship modification slots (common/ship_modification_slots),
#                    land combat unit types by group (common/combat_unit_groups, common/combat_unit_types)
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

		### NEWEST UNLOCKED COMBAT UNIT TYPE PER LAND GROUP (one line, generated from game/common/combat_unit_types)
		flowcontainer = {
			parentanchor = hcenter
			spacing = 16
			margin = { 10 4 }
			ignoreinvisible = yes

			background = {
				using = entry_bg
			}

			@@UNIT_TYPES@@
		}

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

		### Main fleets first, small fleets last: a fleet is small with less than 5% of the country's ships (ships * 100 < country ships * 5)
		### or fewer than 3 ships. Each part in game order (the GUI cannot sort); its header is one identical copy per fleet of the part,
		### stacked on top of each other (spacing = -height), so it shows exactly once - or not at all for an empty part
		flowcontainer = {
			parentanchor = hcenter
			direction = vertical
			ignoreinvisible = yes

			flowcontainer = {
				direction = vertical
				spacing = -40
				ignoreinvisible = yes
				datamodel = "[Country.GetMilitaryFormationsFleet]"

				item = {
					fleet_almanac_fleet_part_header = {
						visible = "[Not(Or(LessThan_int32(Multiply_int32(MilitaryFormation.GetNumShips, '(int32)100'), Multiply_int32(Country.GetNumShips, '(int32)5')), LessThan_int32(MilitaryFormation.GetNumShips, '(int32)3')))]"

						blockoverride "header_text" {
							text = "FLEET_ALMANAC_MAIN_FLEETS"
						}
					}
				}
			}

			flowcontainer = {
				parentanchor = hcenter
				direction = vertical
				spacing = 5
				ignoreinvisible = yes
				datamodel = "[Country.GetMilitaryFormationsFleet]"

				item = {
					fleet_almanac_fleet_item = {
						visible = "[Not(Or(LessThan_int32(Multiply_int32(MilitaryFormation.GetNumShips, '(int32)100'), Multiply_int32(Country.GetNumShips, '(int32)5')), LessThan_int32(MilitaryFormation.GetNumShips, '(int32)3')))]"
					}
				}
			}
		}

		flowcontainer = {
			parentanchor = hcenter
			direction = vertical
			ignoreinvisible = yes

			flowcontainer = {
				direction = vertical
				spacing = -40
				ignoreinvisible = yes
				datamodel = "[Country.GetMilitaryFormationsFleet]"

				item = {
					fleet_almanac_fleet_part_header = {
						visible = "[Or(LessThan_int32(Multiply_int32(MilitaryFormation.GetNumShips, '(int32)100'), Multiply_int32(Country.GetNumShips, '(int32)5')), LessThan_int32(MilitaryFormation.GetNumShips, '(int32)3'))]"

						blockoverride "header_text" {
							text = "FLEET_ALMANAC_SMALL_FLEETS"
						}
					}
				}
			}

			flowcontainer = {
				parentanchor = hcenter
				direction = vertical
				spacing = 5
				ignoreinvisible = yes
				datamodel = "[Country.GetMilitaryFormationsFleet]"

				item = {
					fleet_almanac_fleet_item = {
						visible = "[Or(LessThan_int32(Multiply_int32(MilitaryFormation.GetNumShips, '(int32)100'), Multiply_int32(Country.GetNumShips, '(int32)5')), LessThan_int32(MilitaryFormation.GetNumShips, '(int32)3'))]"
					}
				}
			}
		}
	}

	### Header of a part of the fleet list (main fleets / small fleets); fixed height 40, used stacked with spacing = -40
	type fleet_almanac_fleet_part_header = widget {
		size = { @panel_width 40 }

		widget = {
			parentanchor = bottom
			size = { 100% 32 }

			background = {
				using = dark_area
			}

			textbox = {
				parentanchor = vcenter
				position = { 10 0 }
				autoresize = yes
				max_width = 500
				elide = right
				align = nobaseline

				block "header_text" {
					text = "FLEET_ALMANAC_MAIN_FLEETS"
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
					datamodel = "[ShipList.GetShipsOfTemplate(ShipTemplate.Self)]"

					tooltipwidget = {
						fleet_almanac_outdated_ships_tooltip = {
							blockoverride "header_text" {
								text = "FLEET_ALMANAC_TEMPLATE_OUTDATED"
							}

							blockoverride "ships_datamodel" {
								datamodel = "[ShipList.GetShipsOfTemplate(ShipTemplate.Self)]"
							}
						}
					}

					item = {
						icon = {
							visible = "[Ship.IsOutdated]"
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

			### Flag, name and status (the status already names the current location)
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

# Top-level blocks (key + body) of a game script file, comments removed
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

# Land combat unit groups (file order, marines left out) and their unit types with the unlocking technology:
# per group one image + name per type (no group label), visible for the newest unlocked type(s) - its technology is researched and no later type
# of the group with a different technology is (types sharing a technology, like dragoons and cuirassiers, show together)
$gameRoot = Split-Path $game -Parent
$excludedUnitGroups = @('combat_unit_group_marines')
$unitGroups = New-Object System.Collections.Generic.List[string]
foreach ($f in (Get-ChildItem "$gameRoot\common\combat_unit_groups" -Filter '*.txt' | Sort-Object Name)) {
	foreach ($b in (Get-TopBlocks $f.FullName)) { if ($excludedUnitGroups -notcontains $b.Key) { $unitGroups.Add($b.Key) } }
}
if ($unitGroups.Count -eq 0) { throw 'No land combat unit groups found' }

$unitTypes = New-Object System.Collections.Generic.List[object]
foreach ($f in (Get-ChildItem "$gameRoot\common\combat_unit_types" -Filter '*.txt' | Sort-Object Name)) {
	foreach ($b in (Get-TopBlocks $f.FullName)) {
		if ($b.Body -match '\bgroup\s*=\s*(\w+)') { $grp = $Matches[1] } else { throw "Combat unit type $($b.Key) has no group" }
		$tech = $null
		if ($b.Body -match '\bunlocking_technologies\s*=\s*\{([^}]*)\}') {
			$techs = @([regex]::Matches($Matches[1], '\w+') | ForEach-Object { $_.Value })
			if ($techs.Count -gt 1) { throw "Combat unit type $($b.Key) has more than one unlocking technology - check how the visibility condition should combine them" }
			if ($techs.Count -eq 1) { $tech = $techs[0] }
		}
		$unitTypes.Add([pscustomobject]@{ Key = $b.Key; Group = $grp; Tech = $tech })
	}
}

function Join-Condition($op, $terms) {
	$r = $terms[0]
	for ($i = 1; $i -lt $terms.Count; $i++) { $r = "$op($r, $($terms[$i]))" }
	return $r
}

$unitTypeLines = New-Object System.Collections.Generic.List[string]
foreach ($g in $unitGroups) {
	$types = @($unitTypes | Where-Object { $_.Group -eq $g })
	if ($types.Count -eq 0) { throw "No combat unit types found for group $g" }
	$block = @"
			### $g
			flowcontainer = {
				parentanchor = vcenter
				spacing = 16
				ignoreinvisible = yes
"@
	$unitTypeLines.AddRange([string[]]($block -split "`r?`n"))
	for ($i = 0; $i -lt $types.Count; $i++) {
		$t = $types[$i]
		$terms = New-Object System.Collections.Generic.List[string]
		if ($t.Tech) { $terms.Add("GetTechnology('$($t.Tech)').HasResearchedTech(Country.Self)") }
		$later = @($types | Select-Object -Skip ($i + 1) | Where-Object { $_.Tech -and $_.Tech -ne $t.Tech } | ForEach-Object { $_.Tech } | Select-Object -Unique)
		if ($later.Count -gt 0) { $terms.Add("Not($(Join-Condition 'Or' @($later | ForEach-Object { "GetTechnology('$_').HasResearchedTech(Country.Self)" })))") }
		$visible = if ($terms.Count -gt 0) { "`n					visible = `"[$(Join-Condition 'And' $terms)]`"" } else { '' }
		$block = @"

				flowcontainer = {$visible
					datacontext = "[GetCombatUnitType('$($t.Key)')]"
					parentanchor = vcenter
					spacing = 5

					tooltipwidget = {
						FancyTooltip_CombatUnitTypeWithoutCulture = {}
					}

					icon = {
						parentanchor = vcenter
						size = { 32 32 }
						texture = "[CombatUnitType.GetDefaultTexture]"

						modify_texture = {
							using = simple_frame_mask
						}

						icon = {
							using = simple_frame
							size = { 100% 100% }
						}
					}

					textbox = {
						parentanchor = vcenter
						autoresize = yes
						max_width = 150
						elide = right
						align = nobaseline
						text = "[CombatUnitType.GetNameNoFormatting]"
					}
				}
"@
		$unitTypeLines.AddRange([string[]]($block -split "`r?`n"))
	}
	$unitTypeLines.Add('			}')
	"combat unit group ${g}: $(($types | ForEach-Object { $_.Key -replace '^combat_unit_type_', '' }) -join ', ')"
}

$slotReplacements = @{
	'@@MOD_SLOTS@@'      = (New-SlotLines '[ShipTemplate.GetModifications]' 22)
	'@@MOD_SLOTS_SHIP@@' = (New-SlotLines '[Ship.GetModifications]' 20)
	'@@UNIT_TYPES@@'     = $unitTypeLines
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
