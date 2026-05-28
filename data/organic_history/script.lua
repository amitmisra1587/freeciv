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
organic_history_civil_war_last_turn = organic_history_civil_war_last_turn or {}
organic_history_civil_war_success_this_turn = false
organic_history_prestige = organic_history_prestige or {}


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
  log.normal("organic_history turn_begin turn=%d year=%d", turn, year)
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
  "americas", "europe", "near_east", "africa", "steppe", "india", "china"
}

organic_history_scenario_regions = {
  africa = {name = "Africa", x_min = 38, x_max = 55, y_min = 27, y_max = 49},
  americas = {name = "Americas", x_min = 0, x_max = 29, y_min = 8, y_max = 43},
  china = {name = "China", x_min = 63, x_max = 74, y_min = 16, y_max = 30},
  europe = {name = "Europe", x_min = 36, x_max = 50, y_min = 10, y_max = 25},
  india = {name = "India", x_min = 55, x_max = 64, y_min = 23, y_max = 34},
  near_east = {name = "Near East", x_min = 47, x_max = 58, y_min = 22, y_max = 33},
  steppe = {name = "Steppe", x_min = 48, x_max = 69, y_min = 6, y_max = 18}
}

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

function organic_history_log_regional_hegemony(turn)
  local regions = {}

  for _, region_id in ipairs(organic_history_scenario_region_order) do
    regions[region_id] = {total = 0, players = {}}
  end

  for player in players_iterate() do
    for city in player:cities_iterate() do
      local region_id = organic_history_region_for_tile(city.tile)
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
  end
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

    log.normal('organic_history_metric turn=%d year=%d player=%d name=%q nation=%q alive=%s cities=%d units=%d gold=%d culture=%d government=%q',
               turn, year, player.id, player.name, nation,
               tostring(player.is_alive), cities, units, gold, culture,
               government)
    log.normal('organic_history_stability turn=%d player=%d cities=%d units=%d gold=%d culture=%d wars=%d stress=%d risk=%q',
               turn, player.id, cities, units, gold, culture, wars, stress,
               risk)
    log.normal('organic_history_prestige turn=%d player=%d cities=%d culture=%d wars=%d prestige=%d',
               turn, player.id, cities, culture, wars, prestige)
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
    local stress = organic_history_stress_for(player, cities, units, gold,
                                             culture, wars)
    local last_turn = organic_history_civil_war_last_turn[player.id] or -999999
    local cooldown_until = last_turn + organic_history_civil_war_cooldown

    if organic_history_player_excluded(player) then
      organic_history_civil_war_log("civil_war_skip", turn, player, stress,
                                    'reason="excluded"')
    elseif not player.is_alive then
      organic_history_civil_war_log("civil_war_skip", turn, player, stress,
                                    'reason="not_alive"')
    elseif turn < organic_history_civil_war_min_turn then
      organic_history_civil_war_log("civil_war_skip", turn, player, stress,
                                    'reason="early_turn"')
    elseif cities < organic_history_civil_war_min_cities then
      organic_history_civil_war_log("civil_war_skip", turn, player, stress,
                                    'reason="small_state" cities=' .. cities)
    elseif turn < cooldown_until then
      organic_history_civil_war_log("civil_war_cooldown", turn, player, stress,
                                    "until=" .. cooldown_until)
    elseif stress < organic_history_civil_war_stress_threshold then
      organic_history_civil_war_log("civil_war_skip", turn, player, stress,
                                    'reason="low_stress"')
    elseif organic_history_civil_war_success_this_turn then
      organic_history_civil_war_log("civil_war_skip", turn, player, stress,
                                    'reason="turn_success_limit"')
    else
      local successor

      organic_history_civil_war_log("civil_war_check", turn, player, stress,
                                    "eligible=true probability="
                                    .. organic_history_civil_war_probability)
      organic_history_civil_war_last_turn[player.id] = turn
      successor = player:civil_war(organic_history_civil_war_probability)
      if successor == nil then
        organic_history_civil_war_log("civil_war_noop", turn, player, stress,
                                      'result="no_successor"')
      else
        organic_history_civil_war_success_this_turn = true
        log.normal('organic_history_mechanic type=civil_war_triggered turn=%d player=%d successor=%d stress=%d',
                   turn, player.id, successor.id, stress)
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
