-- Freeciv - Copyright (C) 2007 - The Freeciv Project
--   This program is free software; you can redistribute it and/or modify
--   it under the terms of the GNU General Public License as published by
--   the Free Software Foundation; either version 2, or (at your option)
--   any later version.
--
--   This program is distributed in the hope that it will be useful,
--   but WITHOUT ANY WARRANTY; without even the implied warranty of
--   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--   GNU General Public License for more details.

-- This file is for lua-functionality that is specific to a given
-- ruleset. When freeciv loads a ruleset, it also loads script
-- file called 'default.lua'. The one loaded if your ruleset
-- does not provide an override is default/default.lua.

organic_history_mechanics_enabled =
    organic_history_mechanics_enabled or false
organic_history_civil_war_enabled =
    organic_history_civil_war_enabled or false
organic_history_civil_war_min_turn =
    organic_history_civil_war_min_turn or 80
organic_history_civil_war_min_cities =
    organic_history_civil_war_min_cities or 8
organic_history_civil_war_stress_threshold =
    organic_history_civil_war_stress_threshold or 45
organic_history_civil_war_cooldown =
    organic_history_civil_war_cooldown or 40
organic_history_civil_war_probability =
    organic_history_civil_war_probability or 8
organic_history_dynastic_stress_enabled =
    organic_history_dynastic_stress_enabled or false
organic_history_dynastic_stress_max_bonus =
    organic_history_dynastic_stress_max_bonus or 10
organic_history_institution_stress_modifiers_enabled =
    organic_history_institution_stress_modifiers_enabled or false
organic_history_institution_stress_max_modifier =
    organic_history_institution_stress_max_modifier or 4
organic_history_mandate_enabled = organic_history_mandate_enabled or false
organic_history_mandate_max_stress_reduction =
    organic_history_mandate_max_stress_reduction or 4
organic_history_pressure_modifiers_enabled =
    organic_history_pressure_modifiers_enabled or false
organic_history_pressure_max_stress_modifier =
    organic_history_pressure_max_stress_modifier or 6
organic_history_mandate_loss_enabled =
    organic_history_mandate_loss_enabled or false
organic_history_mandate_loss_threshold =
    organic_history_mandate_loss_threshold or 0.24
organic_history_mandate_loss_min_cities =
    organic_history_mandate_loss_min_cities or 10
organic_history_mandate_loss_max_stress_modifier =
    organic_history_mandate_loss_max_stress_modifier or 6
organic_history_secession_fallback_enabled =
    organic_history_secession_fallback_enabled or false
organic_history_secession_min_cities =
    organic_history_secession_min_cities or 10
organic_history_secession_max_cities =
    organic_history_secession_max_cities or 1
organic_history_civil_war_last_turn = organic_history_civil_war_last_turn or {}
organic_history_civil_war_success_this_turn = false
organic_history_prestige = organic_history_prestige or {}
organic_history_city_pressure = organic_history_city_pressure or {}
organic_history_institutions = organic_history_institutions or {}
organic_history_event_risks = organic_history_event_risks or {}
organic_history_region_status = organic_history_region_status or {}
organic_history_mandates = organic_history_mandates or {}
organic_history_state_capacity = organic_history_state_capacity or {}
organic_history_secession_success_this_turn = false


-- Place Ruins at the location of the destroyed city.
function city_destroyed_callback(city, loser, destroyer)
  city.tile:create_extra("Ruins", NIL)
  -- continue processing
  return false
end

signal.connect("city_destroyed", "city_destroyed_callback")

-- Check if there is certain terrain in ANY CAdjacent tile.
function adjacent_to(tile, terrain_name)
  for adj_tile in tile:circle_iterate(1) do
    if adj_tile.id ~= tile.id then
      local adj_terr = adj_tile.terrain
      local adj_name = adj_terr:rule_name()
      if adj_name == terrain_name then
        return true
      end
    end
  end
  return false
end

-- Check if there is certain terrain in ALL CAdjacent tiles.
function surrounded_by(tile, terrain_name)
  for adj_tile in tile:circle_iterate(1) do
    if adj_tile.id ~= tile.id then
      local adj_terr = adj_tile.terrain
      local adj_name = adj_terr:rule_name()
      if adj_name ~= terrain_name then
        return false
      end
    end
  end
  return true
end

-- Add random labels to the map.
function place_map_labels()
  local rivers = 0
  local deeps = 0
  local oceans = 0
  local lakes = 0
  local swamps = 0
  local glaciers = 0
  local tundras = 0
  local deserts = 0
  local plains = 0
  local grasslands = 0
  local jungles = 0
  local forests = 0
  local hills = 0
  local mountains = 0

  local selected_river = 0
  local selected_deep = 0
  local selected_ocean = 0
  local selected_lake = 0
  local selected_swamp = 0
  local selected_glacier = 0
  local selected_tundra = 0
  local selected_desert = 0
  local selected_plain = 0
  local selected_grassland = 0
  local selected_jungle = 0
  local selected_forest = 0
  local selected_hill = 0
  local selected_mountain = 0

  -- Count the tiles that has a terrain type that may get a label.
  for place in whole_map_iterate() do
    local terr = place.terrain
    local tname = terr:rule_name()

    if place:has_extra("River") then
      rivers = rivers + 1
    elseif tname == "Deep Ocean" then
      deeps = deeps + 1
    elseif tname == "Ocean" then
      oceans = oceans + 1
    elseif tname == "Lake" then
      lakes = lakes + 1
    elseif tname == "Swamp" then
      swamps = swamps + 1
    elseif tname == "Glacier" then
      glaciers = glaciers + 1
    elseif tname == "Tundra" then
      tundras = tundras + 1
    elseif tname == "Desert" then
      deserts = deserts + 1
    elseif tname == "Plains" then
      plains = plains + 1
    elseif tname == "Grassland" then
      grasslands = grasslands + 1
    elseif tname == "Jungle" then
      jungles = jungles + 1
    elseif tname == "Forest" then
      forests = forests + 1
    elseif tname == "Hills" then
      hills = hills + 1
    elseif tname == "Mountains" then
      mountains = mountains + 1
    end
  end

  -- Decide if a label should be included and, in case it should, where.
    if random(1, 100) <= rivers then
      selected_river = random(1, rivers)
    end
    if random(1, 100) <= deeps then
      selected_deep = random(1, deeps)
    end
    if random(1, 100) <= oceans then
      selected_ocean = random(1, oceans)
    end
    if random(1, 100) <= lakes then
      selected_lake = random(1, lakes)
    end
    if random(1, 100) <= swamps then
      selected_swamp = random(1, swamps)
    end
    if random(1, 100) <= glaciers then
      selected_glacier = random(1, glaciers)
    end
    if random(1, 100) <= tundras then
      selected_tundra = random(1, tundras)
    end
    if random(1, 100) <= deserts then
      selected_desert = random(1, deserts)
    end
    if random(1, 100) <= plains then
      selected_plain = random(1, plains)
    end
    if random(1, 100) <= grasslands then
      selected_grassland = random(1, grasslands)
    end
    if random(1, 100) <= jungles then
      selected_jungle = random(1, jungles)
    end
    if random(1, 100) <= forests then
      selected_forest = random(1, forests)
    end
    if random(1, 100) <= hills then
      selected_hill = random(1, hills)
    end
    if random(1, 100) <= mountains then
      selected_mountain = random(1, mountains)
    end

  -- Place the included labels at the location determined above.
  for place in whole_map_iterate() do
    local terr = place.terrain
    local tname = terr:rule_name()

    if place:has_extra("River") then
      selected_river = selected_river - 1
      if selected_river == 0 then
        if tname == "Hills" then
          place:set_label(_("Grand Canyon"))
        elseif tname == "Mountains" then
          place:set_label(_("Deep Gorge"))
        elseif tname == "Tundra" then
          place:set_label(_("Fjords"))
        elseif random(1, 100) <= 50 then
          place:set_label(_("Waterfalls"))
        else
          place:set_label(_("Travertine Terraces"))
        end
      end
    elseif tname == "Deep Ocean" then
      selected_deep = selected_deep - 1
      if selected_deep == 0 then
        if surrounded_by(place, "Deep Ocean") then
          -- Fully surrounded
          place:set_label(_("Deep Trench"))
        else
          place:set_label(_("Thermal Vent"))
        end
      end
    elseif tname == "Ocean" then
      selected_ocean = selected_ocean - 1
      if selected_ocean == 0 then
        if surrounded_by(place, "Ocean") then
          -- Fully surrounded
          place:set_label(_("Atoll Chain"))
        elseif adjacent_to(place, "Glacier") then
          place:set_label(_("Glacier Bay"))
        elseif adjacent_to(place, "Deep Ocean") then
          place:set_label(_("Great Barrier Reef"))
        else
          -- Coast (not adjacent to glacier nor deep ocean)
          place:set_label(_("Great Blue Hole"))
        end
      end
    elseif tname == "Lake" then
      selected_lake = selected_lake - 1
      if selected_lake == 0 then
        if surrounded_by(place, "Lake") then
          -- Fully surrounded
          place:set_label(_("Great Lakes"))
        elseif not adjacent_to(place, "Lake") then
          -- Isolated
          place:set_label(_("Dead Sea"))
        else
          place:set_label(_("Rift Lake"))
        end
      end
    elseif tname == "Swamp" then
      selected_swamp = selected_swamp - 1
      if selected_swamp == 0 then
        if not adjacent_to(place, "Swamp") then
          -- Isolated
          place:set_label(_("Grand Prismatic Spring"))
        elseif adjacent_to(place, "Ocean") then
          -- Coast
          place:set_label(_("Mangrove Forest"))
        else
          place:set_label(_("Cenotes"))
        end
      end
    elseif tname == "Glacier" then
      selected_glacier = selected_glacier - 1
      if selected_glacier == 0 then
        if surrounded_by(place, "Glacier") then
          -- Fully surrounded
          place:set_label(_("Ice Sheet"))
        elseif not adjacent_to(place, "Glacier") then
          -- Isolated
          place:set_label(_("Frozen Lake"))
        elseif adjacent_to(place, "Ocean") then
          -- Coast
          place:set_label(_("Ice Shelf"))
        else
          place:set_label(_("Advancing Glacier"))
        end
      end
    elseif tname == "Tundra" then
      selected_tundra = selected_tundra - 1
      if selected_tundra == 0 then
          place:set_label(_("Geothermal Area"))
      end
    elseif tname == "Desert" then
      selected_desert = selected_desert - 1
      if selected_desert == 0 then
        if surrounded_by(place, "Desert") then
          -- Fully surrounded
          place:set_label(_("Sand Sea"))
        elseif not adjacent_to(place, "Desert") then
          -- Isolated
          place:set_label(_("Salt Flat"))
        elseif random(1, 100) <= 50 then
          place:set_label(_("Singing Dunes"))
        else
          place:set_label(_("White Desert"))
        end
      end
    elseif tname == "Plains" then
      selected_plain = selected_plain - 1
      if selected_plain == 0 then
        if adjacent_to(place, "Ocean") then
          -- Coast
          place:set_label(_("Long Beach"))
        elseif random(1, 100) <= 50 then
          place:set_label(_("Valley of Geysers"))
        else
          place:set_label(_("Rock Pillars"))
        end
      end
    elseif tname == "Grassland" then
      selected_grassland = selected_grassland - 1
      if selected_grassland == 0 then
        if adjacent_to(place, "Ocean") then
          -- Coast
          place:set_label(_("White Cliffs"))
        elseif random(1, 100) <= 50 then
          place:set_label(_("Giant Cave"))
        else
          place:set_label(_("Rock Formation"))
        end
      end
    elseif tname == "Jungle" then
      selected_jungle = selected_jungle - 1
      if selected_jungle == 0 then
        if surrounded_by(place, "Jungle") then
          -- Fully surrounded
          place:set_label(_("Rainforest"))
        elseif adjacent_to(place, "Ocean") then
          -- Coast
          place:set_label(_("Subterranean River"))
        else
          place:set_label(_("Sinkholes"))
        end
      end
    elseif tname == "Forest" then
      selected_forest = selected_forest - 1
      if selected_forest == 0 then
        if adjacent_to(place, "Mountains") then
          place:set_label(_("Stone Forest"))
        elseif surrounded_by(place, "Forest") then
          -- Fully surrounded
          place:set_label(_("Sequoia Forest"))
        else
          place:set_label(_("Millenary Trees"))
        end
      end
    elseif tname == "Hills" then
      selected_hill = selected_hill - 1
      if selected_hill == 0 then
        if not adjacent_to(place, "Hills") then
          if adjacent_to(place, "Mountains") then
            -- Isolated (but adjacent to mountains)
            place:set_label(_("Table Mountain"))
          else
            -- Isolated (not adjacent to hills nor mountains)
            place:set_label(_("Inselberg"))
          end
        elseif random(1, 100) <= 50 then
          place:set_label(_("Karst Landscape"))
        else
          place:set_label(_("Mud Volcanoes"))
        end
      end
    elseif tname == "Mountains" then
      selected_mountain = selected_mountain - 1
      if selected_mountain == 0 then
        if surrounded_by(place, "Mountains") then
          -- Fully surrounded
          place:set_label(_("Highest Peak"))
        elseif not adjacent_to(place, "Mountains") then
          -- Isolated
          place:set_label(_("Sacred Mount"))
        elseif adjacent_to(place, "Ocean") then
          -- Coast
          place:set_label(_("Cliff Coast"))
        elseif random(1, 100) <= 50 then
          place:set_label(_("Active Volcano"))
        else
          place:set_label(_("High Summit"))
        end
      end
    end
  end
  return false
end

signal.connect("map_generated", "place_map_labels")

-- Diagnostic only: prove organic-history ruleset Lua hooks fire.
function organic_history_turn_begin(turn, year)
  organic_history_civil_war_success_this_turn = false
  organic_history_secession_success_this_turn = false
  log.normal("organic_history turn_begin turn=%d year=%d", turn, year)
  organic_history_log_scenario_metadata_status(turn)
  organic_history_log_player_metrics(turn, year)
  organic_history_log_regional_hegemony(turn)
  organic_history_check_civil_wars(turn)
end

signal.connect('turn_begin', 'organic_history_turn_begin')

function organic_history_player_name(player)
  if player == nil then
    return "none"
  end
  return player.name
end

function organic_history_player_id(player)
  if player == nil then
    return -1
  end
  return player.id
end

function organic_history_rule_name(item)
  if item == nil then
    return "none"
  end
  return item:rule_name()
end

function organic_history_war_count(player)
  local wars = 0

  for other in players_iterate() do
    if other.id ~= player.id and player:diplstate(other) == "War" then
      wars = wars + 1
    end
  end

  return wars
end

function organic_history_stress_for(player, cities, units, gold, culture, wars)
  local stress = cities * 2 + wars * 5

  if gold < 0 then
    stress = stress + 10
  elseif gold < cities * 2 then
    stress = stress + 3
  end

  if cities > 0 and units > cities * 5 then
    stress = stress + 2
  end

  stress = stress - math.floor(culture / 100)

  if stress < 0 then
    stress = 0
  elseif stress > 100 then
    stress = 100
  end

  return stress
end

function organic_history_risk_for(stress)
  if stress >= 35 then
    return "high"
  elseif stress >= 15 then
    return "medium"
  end

  return "low"
end

function organic_history_clamp(value, low, high)
  if value < low then
    return low
  elseif value > high then
    return high
  end

  return value
end

function organic_history_update_prestige(player, cities, culture, wars)
  local player_id = organic_history_player_id(player)
  local prestige = organic_history_prestige[player_id] or 0

  prestige = prestige + cities + math.floor(culture / 200) - wars
  if prestige < 0 then
    prestige = 0
  end

  organic_history_prestige[player_id] = prestige
  return prestige
end

organic_history_scenario_region_order = {
  "americas", "europe", "near_east", "africa", "steppe", "india", "china",
  "east_asia"
}

organic_history_scenario_regions = {
  africa = {name = "Africa", x_min = 38, x_max = 55, y_min = 27, y_max = 49},
  americas = {name = "Americas", x_min = 0, x_max = 29, y_min = 8, y_max = 43},
  china = {name = "China", x_min = 63, x_max = 74, y_min = 16, y_max = 30},
  east_asia = {name = "East Asia", x_min = 63, x_max = 74, y_min = 10, y_max = 18},
  europe = {name = "Europe", x_min = 36, x_max = 50, y_min = 10, y_max = 25},
  india = {name = "India", x_min = 55, x_max = 64, y_min = 23, y_max = 34},
  near_east = {name = "Near East", x_min = 47, x_max = 58, y_min = 22, y_max = 33},
  steppe = {name = "Steppe", x_min = 48, x_max = 69, y_min = 6, y_max = 18}
}

organic_history_scenario_actor_metadata = {
  abbasid = {leader = "Harun al-Rashid", nation = "Arab", core_region = "near_east", successor_nation = "Arab", successor_names = {"Abbasid Provincial Secession", "Mesopotamian Emirate"}, core_cities = {["Baghdad"] = true}},
  africa = {leader = "Sundiata", nation = "Egyptian", core_region = "africa", successor_nation = "Egyptian", successor_names = {"Sahelian Secession", "African Regional Secession"}, core_cities = {["Niani"] = true}},
  aztec = {leader = "Moctezuma I", nation = "Aztec", core_region = "americas", successor_nation = "Aztec", successor_names = {"Central Mexican Secession", "Aztec Tributary Secession"}, core_cities = {["Tenochtitlan"] = true}},
  byzantium = {leader = "Basil II", nation = "Byzantine", core_region = "near_east", successor_nation = "Byzantine", successor_names = {"Anatolian Roman Secession", "Byzantine Frontier Secession"}, core_cities = {["Constantinople"] = true}},
  castile = {leader = "Isabella", nation = "Spanish", core_region = "europe", successor_nation = "Spanish", successor_names = {"Castilian Crown Secession", "Iberian Frontier Secession"}, core_cities = {["Toledo"] = true, ["Seville"] = true}},
  china = {leader = "Qin Shi Huang", nation = "Chinese", core_region = "china", successor_nation = "Chinese", successor_names = {"Chinese Regional Secession", "Yellow River Secession"}, core_cities = {["Chang'an"] = true}},
  chola = {leader = "Rajaraja Chola", nation = "Indian", core_region = "india", successor_nation = "Indian", successor_names = {"Tamil Country Secession", "Indian Ocean Polity"}, core_cities = {["Thanjavur"] = true, ["Kanchipuram"] = true}},
  egypt = {leader = "Narmer", nation = "Egyptian", core_region = "africa", successor_nation = "Egyptian", successor_names = {"Nile Delta Secession", "Upper Egyptian Secession"}, core_cities = {["Memphis"] = true}},
  franks = {leader = "Charlemagne", nation = "French", core_region = "europe", successor_nation = "French", successor_names = {"Frankish March Secession", "West Frankish Secession"}, core_cities = {["Aachen"] = true}},
  greece = {leader = "Pericles", nation = "Greek", core_region = "europe", successor_nation = "Greek", successor_names = {"Hellenic League Secession", "Greek City Secession"}, core_cities = {["Athens"] = true}},
  inca = {leader = "Pachacuti", nation = "Inca", core_region = "americas", successor_nation = "Inca", successor_names = {"Andean Secession", "Inca Provincial Secession"}, core_cities = {["Cusco"] = true}},
  india = {leader = "Chandragupta", nation = "Indian", core_region = "india", successor_nation = "Indian", successor_names = {"Magadhan Secession", "Indian Regional Secession"}, core_cities = {["Pataliputra"] = true}},
  japan = {leader = "Ashikaga Yoshimasa", nation = "Japanese", core_region = "east_asia", successor_nation = "Japanese", successor_names = {"Japanese Daimyo Secession", "Eastern Island Secession"}, core_cities = {["Kyoto"] = true}},
  ming = {leader = "Xuande", nation = "Chinese", core_region = "china", successor_nation = "Chinese", successor_names = {"Ming Provincial Secession", "Northern Chinese Secession"}, core_cities = {["Beijing"] = true}},
  ottoman = {leader = "Mehmed II", nation = "Persian", core_region = "near_east", successor_nation = "Persian", successor_names = {"Anatolian Beylik Secession", "Ottoman Frontier Secession"}, core_cities = {["Istanbul"] = true}},
  persia = {leader = "Cyrus", nation = "Persian", core_region = "near_east", successor_nation = "Persian", successor_names = {"Persian Satrapy Secession", "Iranian Plateau Secession"}, core_cities = {["Parsa"] = true, ["Ecbatana"] = true}},
  portugal = {leader = "Henry", nation = "Portuguese", core_region = "europe", successor_nation = "Portuguese", successor_names = {"Portuguese Atlantic Secession", "Iberian Port Secession"}, core_cities = {["Lisbon"] = true, ["Porto"] = true}},
  rome = {leader = "Romulus", nation = "Roman", core_region = "europe", successor_nation = "Roman", successor_names = {"Western Roman Secession", "Italian Roman Secession", "Roman Frontier Secession"}, core_cities = {["Roma"] = true, ["Neapolis"] = true}},
  song = {leader = "Taizu", nation = "Chinese", core_region = "china", successor_nation = "Chinese", successor_names = {"Southern Song Secession", "Chinese Provincial Secession"}, core_cities = {["Kaifeng"] = true, ["Hangzhou"] = true}},
  steppe = {leader = "Temujin", nation = "Mongol", core_region = "steppe", successor_nation = "Mongol", successor_names = {"Steppe Ulus Secession", "Mongol Horde Secession"}, core_cities = {["Karakorum"] = true, ["Sarai"] = true}},
  sumer = {leader = "Gilgamesh", nation = "Sumerian", core_region = "near_east", successor_nation = "Sumerian", successor_names = {"Sumerian City Secession", "Mesopotamian Secession"}, core_cities = {["Uruk"] = true}},
  venice = {leader = "Francesco Foscari", nation = "Italian", core_region = "europe", successor_nation = "Italian", successor_names = {"Venetian Terraferma Secession", "Adriatic League Secession"}, core_cities = {["Venice"] = true}}
}

organic_history_scenario_city_metadata = {
  ["Aachen"] = {actor = "franks", region = "europe", core = true, x = 36, y = 14},
  ["Athens"] = {actor = "greece", region = "europe", core = true, x = 40, y = 16},
  ["Baghdad"] = {actor = "abbasid", region = "near_east", core = true, x = 44, y = 20},
  ["Beijing"] = {actor = "ming", region = "china", core = true, x = 59, y = 18},
  ["Beshbalik"] = {actor = "steppe", region = "steppe", core = true, x = 62, y = 12},
  ["Chang'an"] = {actor = "china", region = "china", core = true, x = 59, y = 17},
  ["Constantinople"] = {actor = "byzantium", region = "near_east", core = true, x = 41, y = 17},
  ["Cusco"] = {actor = "inca", region = "americas", core = true, x = 18, y = 34},
  ["Ecbatana"] = {actor = "persia", region = "near_east", core = true, x = 51, y = 17},
  ["Hangzhou"] = {actor = "song", region = "china", core = true, x = 58, y = 22},
  ["Istanbul"] = {actor = "ottoman", region = "near_east", core = true, x = 42, y = 18},
  ["Kaifeng"] = {actor = "song", region = "china", core = true, x = 59, y = 18},
  ["Kanchipuram"] = {actor = "chola", region = "india", core = true, x = 55, y = 27},
  ["Karakorum"] = {actor = "steppe", region = "steppe", core = true, x = 54, y = 11},
  ["Kyoto"] = {actor = "japan", region = "east_asia", core = true, x = 67, y = 14},
  ["Lisbon"] = {actor = "portugal", region = "europe", core = true, x = 32, y = 20},
  ["Memphis"] = {actor = "egypt", region = "africa", core = true, x = 38, y = 21},
  ["Neapolis"] = {actor = "rome", region = "europe", core = true, x = 34, y = 20},
  ["Niani"] = {actor = "africa", region = "africa", core = true, x = 35, y = 29},
  ["Parsa"] = {actor = "persia", region = "near_east", core = true, x = 47, y = 16},
  ["Pataliputra"] = {actor = "india", region = "india", core = true, x = 50, y = 21},
  ["Porto"] = {actor = "portugal", region = "europe", core = true, x = 30, y = 17},
  ["Roma"] = {actor = "rome", region = "europe", core = true, x = 36, y = 17},
  ["Sarai"] = {actor = "steppe", region = "steppe", core = true, x = 58, y = 10},
  ["Seville"] = {actor = "castile", region = "europe", core = true, x = 35, y = 22},
  ["Tenochtitlan"] = {actor = "aztec", region = "americas", core = true, x = 15, y = 23},
  ["Thanjavur"] = {actor = "chola", region = "india", core = true, x = 50, y = 24},
  ["Toledo"] = {actor = "castile", region = "europe", core = true, x = 35, y = 18},
  ["Uruk"] = {actor = "sumer", region = "near_east", core = true, x = 44, y = 19},
  ["Venice"] = {actor = "venice", region = "europe", core = true, x = 38, y = 17}
}

organic_history_scenario_metadata_active_cache = nil
organic_history_scenario_metadata_match_cache = nil

function organic_history_region_for_tile(tile)
  if tile == nil then
    return "unknown", "Unknown"
  end

  for _, region_id in ipairs(organic_history_scenario_region_order) do
    local region = organic_history_scenario_regions[region_id]
    if tile.x >= region.x_min and tile.x <= region.x_max
       and tile.y >= region.y_min and tile.y <= region.y_max then
      return region_id, region.name
    end
  end

  return "unknown", "Unknown"
end

function organic_history_region_name(region_id)
  local region = organic_history_scenario_regions[region_id]

  if region ~= nil then
    return region.name
  end

  return "Unknown"
end

function organic_history_city_metadata_for(city)
  if city == nil then
    return nil
  end

  if not organic_history_scenario_metadata_active() then
    return nil
  end

  local metadata = organic_history_scenario_city_metadata[city.name]

  if organic_history_city_matches_authored_tile(city, metadata) then
    return metadata
  end

  return nil
end

function organic_history_region_for_city(city)
  local metadata = organic_history_city_metadata_for(city)

  if metadata ~= nil and metadata.region ~= nil then
    return metadata.region, organic_history_region_name(metadata.region)
  end

  return organic_history_region_for_tile(city.tile)
end

function organic_history_actor_metadata_for(player)
  if not organic_history_scenario_metadata_active() then
    return nil, nil
  end

  local player_name = organic_history_player_name(player)
  local nation = organic_history_rule_name(player and player.nation)

  for actor_id, metadata in pairs(organic_history_scenario_actor_metadata) do
    if metadata.leader == player_name and metadata.nation == nation then
      return metadata, actor_id
    end
  end

  for actor_id, metadata in pairs(organic_history_scenario_actor_metadata) do
    if metadata.leader == player_name then
      return metadata, actor_id
    end
  end

  return nil, nil
end

function organic_history_city_matches_authored_tile(city, metadata)
  return city ~= nil and metadata ~= nil and city.tile ~= nil
         and metadata.x ~= nil and metadata.y ~= nil
         and city.tile.x == metadata.x and city.tile.y == metadata.y
end

function organic_history_scenario_metadata_active()
  if organic_history_scenario_metadata_active_cache ~= nil then
    return organic_history_scenario_metadata_active_cache
  end

  local matches = 0

  for player in players_iterate() do
    for city in player:cities_iterate() do
      local metadata = organic_history_scenario_city_metadata[city.name]

      if organic_history_city_matches_authored_tile(city, metadata) then
        matches = matches + 1
      end
    end
  end

  organic_history_scenario_metadata_active_cache = matches >= 3
  organic_history_scenario_metadata_match_cache = matches
  log.normal('organic_history_scenario_metadata active=%s matches=%d',
             tostring(organic_history_scenario_metadata_active_cache), matches)

  return organic_history_scenario_metadata_active_cache
end

function organic_history_log_scenario_metadata_status(turn)
  local active = organic_history_scenario_metadata_active()
  local matches = organic_history_scenario_metadata_match_cache or -1

  log.normal('organic_history_scenario_metadata_status turn=%d active=%s matches=%d',
             turn, tostring(active), matches)
end

function organic_history_city_authored_core(city, actor_id)
  local metadata = organic_history_city_metadata_for(city)

  return metadata ~= nil and metadata.actor == actor_id and metadata.core
end

function organic_history_city_key(city)
  if city.id ~= nil then
    return tostring(city.id)
  end

  return city.name
end

function organic_history_region_archetype(region_id)
  if region_id == "china" then
    return "imperial", "empire"
  elseif region_id == "india" then
    return "agrarian", "kingdom"
  elseif region_id == "near_east" then
    return "regional", "regional_kingdom"
  elseif region_id == "europe" then
    return "scholarly", "city_league"
  elseif region_id == "steppe" then
    return "nomadic", "nomadic_confederation"
  elseif region_id == "africa" then
    return "defensive", "defensive_kingdom"
  elseif region_id == "americas" then
    return "regional", "regional_polity"
  elseif region_id == "east_asia" then
    return "maritime", "regional_polity"
  end

  return "regional", "regional_polity"
end

function organic_history_city_pressure_baseline(region_id)
  if region_id == "steppe" then
    return 0.22, 0.28
  elseif region_id == "africa" or region_id == "near_east" then
    return 0.18, 0.12
  elseif region_id == "india" then
    return 0.12, 0.08
  elseif region_id == "americas" then
    return 0.08, 0.10
  end

  return 0.05, 0.04
end

function organic_history_update_city_pressure(city, player, turn, stress, wars,
                                              player_gold, player_city_count)
  local key = organic_history_city_key(city)
  local state = organic_history_city_pressure[key]
  local region_id, region_name = organic_history_region_for_city(city)
  local climate_base, migration_base = organic_history_city_pressure_baseline(region_id)
  local owner_id = organic_history_player_id(player)
  local size = city.size or 1
  local garrison = city.tile:num_units()

  if state == nil then
    state = {
      owner = owner_id,
      occupation_turns = 0,
      development = 0.28,
      unrest = 0.10,
      autonomy = 0.12,
      climate_stress = climate_base,
      migration_pressure = migration_base
    }
  end

  if state.owner ~= owner_id then
    state.owner = owner_id
    state.occupation_turns = 0
    state.unrest = organic_history_clamp(state.unrest + 0.12, 0, 1)
    state.autonomy = organic_history_clamp(state.autonomy + 0.08, 0, 1)
  else
    state.occupation_turns = state.occupation_turns + 1
  end

  local population_pressure = organic_history_clamp((size - 4) / 16, 0, 1)
  local food_pressure = organic_history_clamp(population_pressure * 0.45
                                             + state.climate_stress * 0.35, 0, 1)
  local economic_pressure = 0
  if player_gold < 0 then
    economic_pressure = 0.35
  elseif player_gold < player_city_count * 2 then
    economic_pressure = 0.16
  end
  economic_pressure = organic_history_clamp(economic_pressure
                                            + state.autonomy * 0.12
                                            - state.development * 0.08, 0, 1)
  local garrison_pressure = organic_history_clamp((size - garrison) / 12
                                                  + wars * 0.04, 0, 1)

  state.climate_stress = organic_history_clamp(state.climate_stress * 0.985
                                               + climate_base * 0.015, 0, 1)
  state.migration_pressure = organic_history_clamp(state.migration_pressure * 0.975
                                                   + migration_base * 0.012
                                                   + state.climate_stress * 0.01
                                                   + wars * 0.006, 0, 1)
  state.development = organic_history_clamp(state.development * 0.995
                                            + size * 0.001
                                            - state.unrest * 0.0015, 0, 1)
  state.unrest = organic_history_clamp(state.unrest * 0.90
                                       + stress / 1000
                                       + food_pressure * 0.08
                                       + economic_pressure * 0.08
                                       + garrison_pressure * 0.06
                                       + state.migration_pressure * 0.04
                                       - state.development * 0.035, 0, 1)
  state.autonomy = organic_history_clamp(state.autonomy * 0.985
                                         + state.unrest * 0.012
                                         + (state.occupation_turns < 12 and 0.004 or 0)
                                         - state.development * 0.002, 0, 1)
  state.region_id = region_id
  state.region_name = region_name
  organic_history_city_pressure[key] = state

  log.normal('organic_history_city_pressure turn=%d city=%q city_id=%s player=%d region=%q size=%d garrison=%d occupation_turns=%d population_pressure=%.3f food_pressure=%.3f economic_pressure=%.3f garrison_pressure=%.3f development=%.3f unrest=%.3f autonomy=%.3f climate_stress=%.3f migration_pressure=%.3f',
             turn, city.name, key, owner_id, region_id, size, garrison,
             state.occupation_turns, population_pressure, food_pressure,
             economic_pressure, garrison_pressure, state.development,
             state.unrest, state.autonomy, state.climate_stress,
             state.migration_pressure)

  return {
    unrest = state.unrest,
    autonomy = state.autonomy,
    development = state.development,
    climate_stress = state.climate_stress,
    migration_pressure = state.migration_pressure,
    population_pressure = population_pressure,
    food_pressure = food_pressure,
    economic_pressure = economic_pressure,
    garrison_pressure = garrison_pressure,
    region_id = region_id
  }
end

function organic_history_pressure_summary_init()
  return {
    cities = 0,
    unrest = 0,
    autonomy = 0,
    development = 0,
    climate_stress = 0,
    migration_pressure = 0,
    population_pressure = 0,
    economic_pressure = 0,
    garrison_pressure = 0,
    regions = {}
  }
end

function organic_history_pressure_summary_add(summary, pressure)
  summary.cities = summary.cities + 1
  summary.unrest = summary.unrest + pressure.unrest
  summary.autonomy = summary.autonomy + pressure.autonomy
  summary.development = summary.development + pressure.development
  summary.climate_stress = summary.climate_stress + pressure.climate_stress
  summary.migration_pressure = summary.migration_pressure + pressure.migration_pressure
  summary.population_pressure = summary.population_pressure + pressure.population_pressure
  summary.economic_pressure = summary.economic_pressure + pressure.economic_pressure
  summary.garrison_pressure = summary.garrison_pressure + pressure.garrison_pressure
  summary.regions[pressure.region_id] = (summary.regions[pressure.region_id] or 0) + 1
end

function organic_history_pressure_summary_finish(summary)
  if summary.cities <= 0 then
    return summary
  end

  summary.unrest = summary.unrest / summary.cities
  summary.autonomy = summary.autonomy / summary.cities
  summary.development = summary.development / summary.cities
  summary.climate_stress = summary.climate_stress / summary.cities
  summary.migration_pressure = summary.migration_pressure / summary.cities
  summary.population_pressure = summary.population_pressure / summary.cities
  summary.economic_pressure = summary.economic_pressure / summary.cities
  summary.garrison_pressure = summary.garrison_pressure / summary.cities
  return summary
end

function organic_history_dominant_region(summary)
  local dominant = "unknown"
  local count = 0

  for region_id, region_count in pairs(summary.regions) do
    if region_count > count then
      dominant = region_id
      count = region_count
    end
  end

  return dominant
end

function organic_history_player_core_region(player, pressure_summary)
  local metadata = organic_history_actor_metadata_for(player)

  if metadata ~= nil and metadata.core_region ~= nil then
    return metadata.core_region
  end

  return organic_history_dominant_region(pressure_summary)
end

function organic_history_update_institution(player, turn, cities, stress,
                                            wars, pressure_summary)
  local player_id = organic_history_player_id(player)
  local institution = organic_history_institutions[player_id]
  local core_region = organic_history_player_core_region(player, pressure_summary)
  local archetype, default_form = organic_history_region_archetype(core_region)

  if cities >= 14 and default_form ~= "nomadic_confederation" then
    default_form = "empire"
    archetype = "imperial"
  end

  if institution == nil then
    institution = {
      state_form = default_form,
      archetype = archetype,
      cohesion = 0.54,
      reform_pressure = 0.0
    }
  end

  local cohesion = institution.cohesion * 0.97
                   + (1 - stress / 100) * 0.025
                   + (1 - pressure_summary.unrest) * 0.008
                   - wars * 0.006
  local reform_pressure = institution.reform_pressure * 0.985
                          + math.max(0, 0.46 - cohesion) * 0.035
                          + math.max(0, cities - 10) * 0.003
                          + pressure_summary.autonomy * 0.01

  institution.state_form = default_form
  institution.archetype = archetype
  institution.core_region = core_region
  institution.cohesion = organic_history_clamp(cohesion, 0, 1)
  institution.reform_pressure = organic_history_clamp(reform_pressure, 0, 1)
  organic_history_institutions[player_id] = institution

  log.normal('organic_history_institution turn=%d player=%d archetype=%q state_form=%q core_region=%q cohesion=%.3f reform_pressure=%.3f cities=%d stress=%d',
             turn, player_id, institution.archetype, institution.state_form,
             core_region, institution.cohesion, institution.reform_pressure,
             cities, stress)

  return institution
end

function organic_history_log_event_risks(turn, player, cities, stress, wars,
                                         gold, pressure_summary, institution)
  local succession = organic_history_clamp((stress - 45) / 55
                                           + institution.reform_pressure * 0.35
                                           + math.max(0, cities - 8) * 0.02, 0, 1)
  local fiscal = organic_history_clamp(math.max(0, -gold) / 220
                                       + pressure_summary.economic_pressure * 0.55, 0, 1)
  local plague = organic_history_clamp(pressure_summary.population_pressure * 0.55
                                       + pressure_summary.development * 0.25, 0, 1)
  local trade = organic_history_clamp(pressure_summary.economic_pressure * 0.45
                                      + math.max(0, cities - 6) * 0.015, 0, 1)
  local climate = organic_history_clamp(pressure_summary.climate_stress, 0, 1)
  local frontier = organic_history_clamp(pressure_summary.migration_pressure
                                         + pressure_summary.garrison_pressure * 0.25, 0, 1)
  local risks = {
    succession = succession,
    fiscal = fiscal,
    plague = plague,
    trade_disruption = trade,
    climate = climate,
    frontier = frontier
  }
  organic_history_event_risks[organic_history_player_id(player)] = risks

  log.normal('organic_history_event_risk turn=%d player=%d succession=%.3f fiscal=%.3f plague=%.3f trade_disruption=%.3f climate=%.3f frontier=%.3f state_form=%q core_region=%q',
             turn, organic_history_player_id(player), succession, fiscal,
             plague, trade, climate, frontier, institution.state_form,
             institution.core_region or "unknown")
  return risks
end

function organic_history_state_capacity_for(player, turn, cities, pressure_summary,
                                            institution, mandate, risks)
  local player_id = organic_history_player_id(player)
  local mandate_score = mandate.mandate or 0
  local cohesion = institution.cohesion or 0
  local reform_pressure = institution.reform_pressure or 0
  local unrest = pressure_summary.unrest or 0
  local autonomy = pressure_summary.autonomy or 0
  local frontier = risks.frontier or 0
  local mandate_threshold = organic_history_mandate_loss_threshold or 0.24
  local mandate_deficit = 0

  if mandate_threshold > 0 then
    mandate_deficit = organic_history_clamp((mandate_threshold - mandate_score)
                                            / mandate_threshold, 0, 1)
  end

  local cohesion_deficit = organic_history_clamp((0.48 - cohesion) / 0.48, 0, 1)
  local overextension = organic_history_clamp((cities - 10) / 12, 0, 1)
  local crisis = organic_history_clamp(mandate_deficit * 0.35
                                       + overextension * 0.18
                                       + cohesion_deficit * 0.16
                                       + reform_pressure * 0.14
                                       + autonomy * 0.10
                                       + frontier * 0.07, 0, 1)
  local recovery = organic_history_clamp(mandate_score * 0.40
                                         + cohesion * 0.30
                                         + (1 - reform_pressure) * 0.15
                                         + (1 - unrest) * 0.15, 0, 1)
  local modifier = 0

  if organic_history_mechanics_enabled
     and organic_history_mandate_loss_enabled
     and cities >= organic_history_mandate_loss_min_cities
     and mandate_deficit > 0 then
    modifier = math.floor(crisis
                          * organic_history_mandate_loss_max_stress_modifier)
  end

  local status = "stable"
  if modifier > 0 and crisis >= 0.55 then
    status = "legitimacy_crisis"
  elseif modifier > 0 then
    status = "strained"
  elseif overextension >= 0.55 and mandate_score < mandate_threshold + 0.10 then
    status = "overextended"
  elseif reform_pressure >= 0.55 then
    status = "reform_crisis"
  elseif recovery >= 0.65 then
    status = "recovery"
  end

  local state = {
    mandate = mandate_score,
    mandate_deficit = mandate_deficit,
    overextension = overextension,
    cohesion = cohesion,
    cohesion_deficit = cohesion_deficit,
    reform_pressure = reform_pressure,
    unrest = unrest,
    autonomy = autonomy,
    frontier_risk = frontier,
    crisis = crisis,
    recovery = recovery,
    stress_modifier = modifier,
    status = status
  }
  organic_history_state_capacity[player_id] = state

  log.normal('organic_history_state_capacity turn=%d player=%d status=%q cities=%d mandate=%.3f mandate_deficit=%.3f overextension=%.3f cohesion=%.3f cohesion_deficit=%.3f reform_pressure=%.3f unrest=%.3f autonomy=%.3f frontier_risk=%.3f crisis=%.3f recovery=%.3f stress_modifier=%d enabled=%s',
             turn, player_id, status, cities, mandate_score, mandate_deficit,
             overextension, cohesion, cohesion_deficit, reform_pressure, unrest,
             autonomy, frontier, crisis, recovery, modifier,
             tostring(organic_history_mandate_loss_enabled))

  return state
end

function organic_history_log_regional_hegemony(turn)
  local regions = {}
  organic_history_region_status = {}

  for _, region_id in ipairs(organic_history_scenario_region_order) do
    regions[region_id] = {total = 0, players = {}}
  end

  for player in players_iterate() do
    for city in player:cities_iterate() do
      local region_id = organic_history_region_for_city(city)
      local region = regions[region_id]

      if region ~= nil then
        local player_id = organic_history_player_id(player)
        region.total = region.total + 1
        region.players[player_id] = (region.players[player_id] or 0) + 1
      end
    end
  end

  for _, region_id in ipairs(organic_history_scenario_region_order) do
    local region = regions[region_id]
    local region_def = organic_history_scenario_regions[region_id]
    local leader = -1
    local leader_cities = 0

    for player_id, count in pairs(region.players) do
      if count > leader_cities then
        leader = player_id
        leader_cities = count
      end
    end

    local leader_share = 0
    local classification = "empty"
    if region.total > 0 then
      leader_share = leader_cities / region.total
      if leader_share >= 0.67 then
        classification = "hegemon"
      else
        classification = "contested"
      end
    end

    log.normal('organic_history_region turn=%d region=%q name=%q total_cities=%d leader=%d leader_cities=%d leader_share=%.3f classification=%q',
               turn, region_id, region_def.name, region.total, leader,
               leader_cities, leader_share, classification)
    organic_history_region_status[region_id] = {
      leader = leader,
      leader_share = leader_share,
      total_cities = region.total,
      classification = classification
    }
  end
end

function organic_history_mandate_for(player, pressure_summary, institution,
                                     prestige, stress)
  local player_id = organic_history_player_id(player)
  local core_region = institution.core_region or organic_history_dominant_region(pressure_summary)
  local region = organic_history_region_status[core_region] or {}
  local leader_share = region.leader_share or 0
  local is_hegemon = region.leader == player_id and leader_share >= 0.67
  local cohesion = institution.cohesion or 0
  local reform_pressure = institution.reform_pressure or 0
  local prestige_score = organic_history_clamp(prestige / 500, 0, 1)
  local pressure_penalty = organic_history_clamp(pressure_summary.unrest
                                                 + pressure_summary.autonomy
                                                 + stress / 100, 0, 2) / 2
  local mandate = organic_history_clamp(leader_share * 0.35
                                        + cohesion * 0.30
                                        + prestige_score * 0.20
                                        - reform_pressure * 0.10
                                        - pressure_penalty * 0.15, 0, 1)
  local reduction = 0

  if organic_history_mechanics_enabled
     and organic_history_mandate_enabled
     and is_hegemon then
    reduction = math.floor(mandate
                           * organic_history_mandate_max_stress_reduction)
  end

  organic_history_mandates[player_id] = {
    mandate = mandate,
    stress_reduction = reduction,
    core_region = core_region,
    leader_share = leader_share,
    is_hegemon = is_hegemon
  }
  log.normal('organic_history_mandate turn=%d player=%d core_region=%q hegemon=%s leader_share=%.3f cohesion=%.3f prestige=%d reform_pressure=%.3f unrest=%.3f mandate=%.3f stress_reduction=%d',
             game.current_turn(), player_id, core_region, tostring(is_hegemon),
             leader_share, cohesion, prestige, reform_pressure,
             pressure_summary.unrest, mandate, reduction)

  return organic_history_mandates[player_id]
end

function organic_history_log_player_metrics(turn, year)
  for player in players_iterate() do
    local cities = player:num_cities()
    local units = player:num_units()
    local gold = player:gold()
    local culture = player:culture()
    local government = organic_history_rule_name(player.government)
    local nation = organic_history_rule_name(player.nation)
    local wars = organic_history_war_count(player)
    local stress = organic_history_stress_for(player, cities, units, gold,
                                             culture, wars)
    local risk = organic_history_risk_for(stress)
    local prestige = organic_history_update_prestige(player, cities, culture,
                                                     wars)
    local pressure_summary = organic_history_pressure_summary_init()

    for city in player:cities_iterate() do
      local pressure = organic_history_update_city_pressure(city, player, turn,
                                                           stress, wars, gold,
                                                           cities)
      organic_history_pressure_summary_add(pressure_summary, pressure)
    end
    pressure_summary = organic_history_pressure_summary_finish(pressure_summary)
    local institution = organic_history_update_institution(player, turn, cities,
                                                          stress, wars,
                                                          pressure_summary)
    local mandate = organic_history_mandate_for(player, pressure_summary,
                                                institution, prestige, stress)

    log.normal('organic_history_metric turn=%d year=%d player=%d name=%q nation=%q alive=%s cities=%d units=%d gold=%d culture=%d government=%q',
               turn, year, player.id, player.name, nation,
               tostring(player.is_alive), cities, units, gold, culture,
               government)
    log.normal('organic_history_stability turn=%d player=%d cities=%d units=%d gold=%d culture=%d wars=%d stress=%d risk=%q',
               turn, player.id, cities, units, gold, culture, wars, stress,
               risk)
    log.normal('organic_history_prestige turn=%d player=%d cities=%d culture=%d wars=%d prestige=%d',
               turn, player.id, cities, culture, wars, prestige)
    local risks = organic_history_log_event_risks(turn, player, cities, stress,
                                                  wars, gold, pressure_summary,
                                                  institution)
    organic_history_state_capacity_for(player, turn, cities, pressure_summary,
                                       institution, mandate, risks)
  end
end

function organic_history_player_excluded(player)
  local nation = organic_history_rule_name(player.nation)

  if nation == "Animal Kingdom" then
    return true
  end

  return false
end

function organic_history_civil_war_log(kind, turn, player, stress, extra)
  log.normal('organic_history_mechanic type=%s turn=%d player=%d stress=%d threshold=%d %s',
             kind, turn, organic_history_player_id(player), stress,
             organic_history_civil_war_stress_threshold, extra or "")
end

function organic_history_successor_name(player, turn, city)
  local nation = organic_history_rule_name(player.nation)
  local metadata = organic_history_actor_metadata_for(player)

  if metadata ~= nil
     and metadata.successor_names ~= nil
     and #metadata.successor_names > 0 then
    local city_id = 0

    if city ~= nil and city.id ~= nil then
      city_id = city.id
    end

    local index = ((turn + organic_history_player_id(player) + city_id)
                   % #metadata.successor_names) + 1
    return metadata.successor_names[index] .. " " .. turn
  end

  if nation == "Roman" then
    return "Roman Secession " .. turn
  elseif nation == "Chinese" then
    return "Regional Chinese Rebels " .. turn
  elseif nation == "Persian" then
    return "Persian Rebels " .. turn
  end

  return organic_history_player_name(player) .. " Secession " .. turn
end

function organic_history_successor_nation(player)
  local metadata = organic_history_actor_metadata_for(player)

  if metadata ~= nil
     and metadata.successor_nation ~= nil
     and find ~= nil
     and find.nation_type ~= nil then
    local nation = find.nation_type(metadata.successor_nation)

    if nation ~= nil then
      return nation, organic_history_rule_name(nation)
    end
  end

  return player.nation, organic_history_rule_name(player.nation)
end

function organic_history_secession_log(kind, turn, player, stress, extra)
  log.normal('organic_history_secession type=%s turn=%d player=%d stress=%d threshold=%d %s',
             kind, turn, organic_history_player_id(player), stress,
             organic_history_civil_war_stress_threshold, extra or "")
end

function organic_history_secession_candidate_city(player)
  local best_city = nil
  local best_score = -1
  local best_region = "unknown"
  local best_core = false
  local best_peripheral = false
  local metadata, actor_id = organic_history_actor_metadata_for(player)
  local core_region = nil

  if metadata ~= nil then
    core_region = metadata.core_region
  end

  for city in player:cities_iterate() do
    if not city:is_primary_capital()
       and not city:is_capital()
       and not city:is_gov_center() then
      local state = organic_history_city_pressure[organic_history_city_key(city)] or {}
      local unrest = state.unrest or 0
      local autonomy = state.autonomy or 0
      local migration = state.migration_pressure or 0
      local city_region = organic_history_region_for_city(city)
      local authored_core = organic_history_city_authored_core(city, actor_id)
      local peripheral = core_region ~= nil and city_region ~= core_region
      local score = unrest + autonomy + migration

      if peripheral then
        score = score + 0.75
      end
      if authored_core then
        score = score - 0.35
      else
        score = score + 0.15
      end

      if score > best_score then
        best_score = score
        best_city = city
        best_region = city_region
        best_core = authored_core
        best_peripheral = peripheral
      end
    end
  end

  return best_city, best_score, best_region, best_core, best_peripheral
end

function organic_history_try_secession_fallback(turn, player, base_stress,
                                                dynastic, stress, cities)
  if not organic_history_secession_fallback_enabled then
    organic_history_secession_log("secession_candidate", turn, player, stress,
                                  'eligible=false reason="disabled"')
    return nil
  elseif organic_history_secession_success_this_turn then
    organic_history_secession_log("secession_candidate", turn, player, stress,
                                  'eligible=false reason="turn_success_limit"')
    return nil
  elseif cities < organic_history_secession_min_cities then
    organic_history_secession_log("secession_candidate", turn, player, stress,
                                  'eligible=false reason="small_state" cities='
                                  .. cities)
    return nil
  end

  local metadata, actor_id = organic_history_actor_metadata_for(player)
  local core_region = "unknown"

  if metadata ~= nil and metadata.core_region ~= nil then
    core_region = metadata.core_region
  end

  local city, city_score, city_region, city_core, peripheral =
      organic_history_secession_candidate_city(player)
  if city == nil then
    organic_history_secession_log("secession_candidate", turn, player, stress,
                                  'eligible=false reason="no_candidate_city" cities='
                                  .. cities)
    return nil
  end

  organic_history_secession_log("secession_candidate", turn, player, stress,
                                'eligible=true city=' .. string.format("%q", city.name)
                                .. " city_region=" .. string.format("%q", city_region)
                                .. " core_region=" .. string.format("%q", core_region)
                                .. " parent_actor=" .. string.format("%q", actor_id or "unknown")
                                .. " city_core=" .. tostring(city_core)
                                .. " peripheral=" .. tostring(peripheral)
                                .. " city_score=" .. string.format("%.3f", city_score)
                                .. " base_stress=" .. base_stress
                                .. " dynastic_bonus=" .. dynastic.bonus)

  local successor_name = organic_history_successor_name(player, turn, city)
  local successor_nation, successor_nation_name =
      organic_history_successor_nation(player)
  local successor = edit.create_player(successor_name, successor_nation, "classic")
  if successor == nil then
    organic_history_secession_log("secession_noop", turn, player, stress,
                                  'reason="create_player_failed" successor='
                                  .. string.format("%q", successor_name)
                                  .. " successor_nation="
                                  .. string.format("%q", successor_nation_name))
    return nil
  end

  local ok = edit.transfer_city(city, successor)
  if not ok then
    organic_history_secession_log("secession_noop", turn, player, stress,
                                  'reason="transfer_failed" city='
                                  .. string.format("%q", city.name)
                                  .. ' successor='
                                  .. string.format("%d", organic_history_player_id(successor)))
    return nil
  end

  organic_history_secession_success_this_turn = true
  organic_history_civil_war_success_this_turn = true
  organic_history_secession_log("secession_triggered", turn, player, stress,
                                'successor=' .. string.format("%d", organic_history_player_id(successor))
                                .. " successor_name=" .. string.format("%q", successor_name)
                                .. " successor_nation=" .. string.format("%q", successor_nation_name)
                                .. " parent_actor=" .. string.format("%q", actor_id or "unknown")
                                .. " core_region=" .. string.format("%q", core_region)
                                .. " city=" .. string.format("%q", city.name)
                                .. " city_region=" .. string.format("%q", city_region)
                                .. " city_core=" .. tostring(city_core)
                                .. " peripheral=" .. tostring(peripheral)
                                .. " transferred=1")
  return successor
end

function organic_history_dynastic_probe_context(player, base_stress)
  local player_id = organic_history_player_id(player)
  local risks = organic_history_event_risks[player_id] or {}
  local institution = organic_history_institutions[player_id] or {}
  local mandate = organic_history_mandates[player_id] or {}
  local succession = risks.succession or 0
  local fiscal = risks.fiscal or 0
  local frontier = risks.frontier or 0
  local cohesion = institution.cohesion or 0
  local reform_pressure = institution.reform_pressure or 0
  local max_bonus = organic_history_dynastic_stress_max_bonus or 0
  local institution_max = organic_history_institution_stress_max_modifier or 0
  local pressure_max = organic_history_pressure_max_stress_modifier or 0
  local bonus = 0
  local institution_modifier = 0
  local pressure_modifier = 0
  local state_capacity = organic_history_state_capacity[player_id] or {}
  local state_capacity_modifier = state_capacity.stress_modifier or 0
  local mandate_reduction = mandate.stress_reduction or 0

  if organic_history_mechanics_enabled
     and organic_history_civil_war_enabled
     and organic_history_dynastic_stress_enabled then
    bonus = math.floor(organic_history_clamp(succession, 0, 1) * max_bonus)
    if organic_history_institution_stress_modifiers_enabled then
      institution_modifier = math.floor(organic_history_clamp(reform_pressure
                                                              - cohesion,
                                                              -1, 1)
                                        * institution_max)
    end
    if not organic_history_mandate_enabled then
      mandate_reduction = 0
    end
    if organic_history_pressure_modifiers_enabled then
      pressure_modifier = math.floor(organic_history_clamp((fiscal * 0.55)
                                                           + (frontier * 0.45),
                                                           0, 1)
                                     * pressure_max + 0.5)
    end
    if not organic_history_mandate_loss_enabled then
      state_capacity_modifier = 0
    end
  else
    mandate_reduction = 0
    state_capacity_modifier = 0
  end

  return {
    succession = succession,
    fiscal = fiscal,
    frontier = frontier,
    cohesion = cohesion,
    reform_pressure = reform_pressure,
    bonus = bonus,
    institution_modifier = institution_modifier,
    pressure_modifier = pressure_modifier,
    state_capacity_modifier = state_capacity_modifier,
    state_capacity_crisis = state_capacity.crisis or 0,
    state_capacity_status = state_capacity.status or "unknown",
    mandate_reduction = mandate_reduction,
    mandate = mandate.mandate or 0,
    effective_stress = organic_history_clamp(base_stress + bonus
                                             + institution_modifier
                                             + pressure_modifier
                                             + state_capacity_modifier
                                             - mandate_reduction, 0, 100),
    max_bonus = max_bonus,
    institution_max = institution_max,
    pressure_max = pressure_max
  }
end

function organic_history_dynastic_probe_log(turn, player, base_stress, context,
                                            action, reason)
  if not (organic_history_mechanics_enabled
          and organic_history_civil_war_enabled
          and organic_history_dynastic_stress_enabled) then
    return
  end

  log.normal('organic_history_dynastic_probe turn=%d player=%d action=%q reason=%q base_stress=%d succession_risk=%.3f fiscal_risk=%.3f frontier_risk=%.3f cohesion=%.3f reform_pressure=%.3f mandate=%.3f bonus=%d institution_modifier=%d pressure_modifier=%d state_capacity_modifier=%d state_capacity_crisis=%.3f state_capacity_status=%q mandate_reduction=%d max_bonus=%d institution_max=%d pressure_max=%d effective_stress=%d threshold=%d',
             turn, organic_history_player_id(player), action, reason,
             base_stress, context.succession, context.fiscal,
             context.frontier, context.cohesion,
             context.reform_pressure, context.mandate, context.bonus,
             context.institution_modifier, context.pressure_modifier,
             context.state_capacity_modifier, context.state_capacity_crisis,
             context.state_capacity_status, context.mandate_reduction,
             context.max_bonus,
             context.institution_max, context.pressure_max,
             context.effective_stress, organic_history_civil_war_stress_threshold)
end

function organic_history_check_civil_wars(turn)
  if not organic_history_mechanics_enabled
     or not organic_history_civil_war_enabled then
    return
  end

  for player in players_iterate() do
    local cities = player:num_cities()
    local units = player:num_units()
    local gold = player:gold()
    local culture = player:culture()
    local wars = organic_history_war_count(player)
    local base_stress = organic_history_stress_for(player, cities, units, gold,
                                                  culture, wars)
    local dynastic = organic_history_dynastic_probe_context(player, base_stress)
    local stress = dynastic.effective_stress
    local last_turn = organic_history_civil_war_last_turn[player.id] or -999999
    local cooldown_until = last_turn + organic_history_civil_war_cooldown

    if organic_history_player_excluded(player) then
      organic_history_dynastic_probe_log(turn, player, base_stress, dynastic,
                                         "skip", "excluded")
      organic_history_civil_war_log("civil_war_skip", turn, player, stress,
                                    'reason="excluded" base_stress=' .. base_stress
                                    .. " dynastic_bonus=" .. dynastic.bonus)
    elseif not player.is_alive then
      organic_history_dynastic_probe_log(turn, player, base_stress, dynastic,
                                         "skip", "not_alive")
      organic_history_civil_war_log("civil_war_skip", turn, player, stress,
                                    'reason="not_alive" base_stress=' .. base_stress
                                    .. " dynastic_bonus=" .. dynastic.bonus)
    elseif turn < organic_history_civil_war_min_turn then
      organic_history_dynastic_probe_log(turn, player, base_stress, dynastic,
                                         "skip", "early_turn")
      organic_history_civil_war_log("civil_war_skip", turn, player, stress,
                                    'reason="early_turn" base_stress=' .. base_stress
                                    .. " dynastic_bonus=" .. dynastic.bonus)
    elseif cities < organic_history_civil_war_min_cities then
      organic_history_dynastic_probe_log(turn, player, base_stress, dynastic,
                                         "skip", "small_state")
      organic_history_civil_war_log("civil_war_skip", turn, player, stress,
                                    'reason="small_state" cities=' .. cities
                                    .. " base_stress=" .. base_stress
                                    .. " dynastic_bonus=" .. dynastic.bonus)
    elseif turn < cooldown_until then
      organic_history_dynastic_probe_log(turn, player, base_stress, dynastic,
                                         "cooldown", "cooldown")
      organic_history_civil_war_log("civil_war_cooldown", turn, player, stress,
                                    "until=" .. cooldown_until
                                    .. " base_stress=" .. base_stress
                                    .. " dynastic_bonus=" .. dynastic.bonus)
    elseif stress < organic_history_civil_war_stress_threshold then
      organic_history_dynastic_probe_log(turn, player, base_stress, dynastic,
                                         "skip", "low_effective_stress")
      organic_history_civil_war_log("civil_war_skip", turn, player, stress,
                                    'reason="low_stress" base_stress=' .. base_stress
                                    .. " dynastic_bonus=" .. dynastic.bonus)
    elseif organic_history_civil_war_success_this_turn then
      organic_history_dynastic_probe_log(turn, player, base_stress, dynastic,
                                         "skip", "turn_success_limit")
      organic_history_civil_war_log("civil_war_skip", turn, player, stress,
                                    'reason="turn_success_limit" base_stress=' .. base_stress
                                    .. " dynastic_bonus=" .. dynastic.bonus)
    else
      local successor

      organic_history_dynastic_probe_log(turn, player, base_stress, dynastic,
                                         "check", "eligible")
      organic_history_civil_war_log("civil_war_check", turn, player, stress,
                                    "eligible=true probability="
                                    .. organic_history_civil_war_probability
                                    .. " base_stress=" .. base_stress
                                    .. " dynastic_bonus=" .. dynastic.bonus)
      organic_history_civil_war_last_turn[player.id] = turn
      successor = player:civil_war(organic_history_civil_war_probability)
      if successor == nil then
        organic_history_dynastic_probe_log(turn, player, base_stress, dynastic,
                                           "noop", "no_successor")
        organic_history_civil_war_log("civil_war_noop", turn, player, stress,
                                      'result="no_successor" base_stress=' .. base_stress
                                      .. " dynastic_bonus=" .. dynastic.bonus)
        successor = organic_history_try_secession_fallback(turn, player,
                                                           base_stress,
                                                           dynastic, stress,
                                                           cities)
        if successor ~= nil then
          organic_history_dynastic_probe_log(turn, player, base_stress,
                                             dynastic, "fallback_triggered",
                                             "secession")
        end
      else
        organic_history_civil_war_success_this_turn = true
        organic_history_dynastic_probe_log(turn, player, base_stress, dynastic,
                                           "triggered", "successor")
        log.normal('organic_history_mechanic type=civil_war_triggered turn=%d player=%d successor=%d stress=%d base_stress=%d dynastic_bonus=%d',
                   turn, player.id, successor.id, stress, base_stress,
                   dynastic.bonus)
      end
    end
  end
end

function organic_history_city_built(city)
  log.normal('organic_history_event type=city_built turn=%d city=%q player=%d',
             game.current_turn(), city.name, organic_history_player_id(city.owner))
end

function organic_history_city_transferred(city, loser, winner, reason)
  log.normal('organic_history_event type=city_transferred turn=%d city=%q loser=%d winner=%d reason=%q',
             game.current_turn(), city.name, organic_history_player_id(loser),
             organic_history_player_id(winner), reason)
end

function organic_history_city_destroyed(city, loser, destroyer)
  log.normal('organic_history_event type=city_destroyed turn=%d city=%q loser=%d destroyer=%d',
             game.current_turn(), city.name, organic_history_player_id(loser),
             organic_history_player_id(destroyer))
end

function organic_history_city_size_change(city, change, reason)
  log.normal('organic_history_event type=city_size_change turn=%d city=%q player=%d change=%d reason=%q size=%d',
             game.current_turn(), city.name, organic_history_player_id(city.owner),
             change, reason, city.size)
end

function organic_history_unit_lost(unit, loser, reason)
  log.normal('organic_history_event type=unit_lost turn=%d unit=%d loser=%d reason=%q',
             game.current_turn(), unit.id, organic_history_player_id(loser),
             reason)
end

function organic_history_disaster(disaster, city, had_internal_effect)
  log.normal('organic_history_event type=disaster_occurred turn=%d disaster=%q city=%q player=%d internal=%s',
             game.current_turn(), organic_history_rule_name(disaster),
             city.name, organic_history_player_id(city.owner),
             tostring(had_internal_effect))
end

function organic_history_tech_researched(tech, player, how)
  log.normal('organic_history_event type=tech_researched turn=%d player=%d tech=%q how=%q',
             game.current_turn(), organic_history_player_id(player),
             organic_history_rule_name(tech), how)
end

signal.connect('city_built', 'organic_history_city_built')
signal.connect('city_transferred', 'organic_history_city_transferred')
signal.connect('city_destroyed', 'organic_history_city_destroyed')
signal.connect('city_size_change', 'organic_history_city_size_change')
signal.connect('unit_lost', 'organic_history_unit_lost')
signal.connect('disaster_occurred', 'organic_history_disaster')
signal.connect('tech_researched', 'organic_history_tech_researched')
