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
organic_history_dynastic_transfer_probe_enabled =
    organic_history_dynastic_transfer_probe_enabled or false
organic_history_dynastic_transfer_enabled =
    organic_history_dynastic_transfer_enabled or false
organic_history_dynastic_transfer_low_mandate_threshold =
    organic_history_dynastic_transfer_low_mandate_threshold or 0.35
organic_history_dynastic_transfer_crisis_threshold =
    organic_history_dynastic_transfer_crisis_threshold or 0.30
organic_history_dynastic_transfer_overextension_threshold =
    organic_history_dynastic_transfer_overextension_threshold or 0.45
organic_history_dynastic_transfer_min_predecessor_cities =
    organic_history_dynastic_transfer_min_predecessor_cities or 4
organic_history_dynastic_transfer_min_remaining_cities =
    organic_history_dynastic_transfer_min_remaining_cities or 1
organic_history_dynastic_transfer_max_cities =
    organic_history_dynastic_transfer_max_cities or 1
organic_history_iberian_successor_transfer_enabled =
    organic_history_iberian_successor_transfer_enabled or false
organic_history_iberian_transfer_remove_starter_enabled =
    organic_history_iberian_transfer_remove_starter_enabled or false
organic_history_expansion_pressure_probe_enabled =
    organic_history_expansion_pressure_probe_enabled or false
organic_history_expansion_pressure_crisis_limit =
    organic_history_expansion_pressure_crisis_limit or 0.45
organic_history_expansion_pressure_min_gold =
    organic_history_expansion_pressure_min_gold or -10
organic_history_partial_contraction_probe_enabled =
    organic_history_partial_contraction_probe_enabled or false
organic_history_partial_contraction_enabled =
    organic_history_partial_contraction_enabled or false
organic_history_partial_contraction_risk_threshold =
    organic_history_partial_contraction_risk_threshold or 0.65
organic_history_partial_contraction_cooldown =
    organic_history_partial_contraction_cooldown or 30
organic_history_partial_contraction_max_release_cities =
    organic_history_partial_contraction_max_release_cities or 1
organic_history_partial_contraction_cluster_risk_threshold =
    organic_history_partial_contraction_cluster_risk_threshold or 0.72
organic_history_partial_contraction_cluster_peripheral_share =
    organic_history_partial_contraction_cluster_peripheral_share or 0.35
organic_history_partial_contraction_min_remaining_cities =
    organic_history_partial_contraction_min_remaining_cities or 1
organic_history_partial_contraction_claimant_successors_enabled =
    organic_history_partial_contraction_claimant_successors_enabled or false
organic_history_partial_contraction_debt_enabled =
    organic_history_partial_contraction_debt_enabled or false
organic_history_partial_contraction_debt_overextension_threshold =
    organic_history_partial_contraction_debt_overextension_threshold or 0.40
organic_history_partial_contraction_debt_peripheral_threshold =
    organic_history_partial_contraction_debt_peripheral_threshold or 0.25
organic_history_partial_contraction_debt_required =
    organic_history_partial_contraction_debt_required or 6
organic_history_partial_contraction_debt_threshold_bonus =
    organic_history_partial_contraction_debt_threshold_bonus or 0.05
-- Wave 6 scaling-empire-stress (Phase 44): OFF by default. When an actor's
-- city count exceeds its historical size ceiling, add size-relative stress to
-- collapse_risk so over-persisting empires cross the existing partial-
-- contraction gate and shed peripheral cities. Only actors present in
-- organic_history_scaling_stress_ceilings are affected; every other actor
-- (including every passing actor) receives zero scaling stress, so this lever
-- cannot regress non-listed actors. The ceilings match the fit tool's
-- medianFinalCitiesMax expectations. Outcomes stay probabilistic and avoidable
-- (gravity-not-destiny) because the existing contraction gate/outcome weights
-- still apply; this lever only raises the pressure input, it never forces release.
organic_history_scaling_stress_enabled =
    organic_history_scaling_stress_enabled or false
organic_history_scaling_stress_weight =
    organic_history_scaling_stress_weight or 0.8
organic_history_scaling_stress_max =
    organic_history_scaling_stress_max or 0.4
if organic_history_scaling_stress_ceilings == nil then
  organic_history_scaling_stress_ceilings = {
    india = 18,
    nubia = 10,
  }
end
-- Phase 45 settlement containment (OFF by default; CONCLUDED NEGATIVE).
-- Experiment: for listed over-expander actors, cap how many cities they may hold
-- in explicitly-foreign regions (deep in another power's space, far outside their
-- own claims); over-cap foundings are REMOVED at the next turn_begin so the
-- over-expansion never accumulates and nothing is fed to a rival.
-- RESULT (india, 20-seed): net negative. Containment cut india's far-east
-- (peripheral 11->7) but india redirected its surplus settler economy into its
-- CLAIMED regions (9->12) and ended up BIGGER (18->19.5), flipping pass->warn and
-- regressing neighbors (assyria/chola/persia). India is at structural capacity;
-- post-hoc removal cannot shrink it. Kept flag-off for the reusable deferred-
-- removal pattern (queue in city_built, edit.remove_city in turn_begin -- direct
-- removal inside the city_built signal is re-entrant and crashes the server).
organic_history_containment_enabled =
    organic_history_containment_enabled or false
organic_history_containment_removal_queue =
    organic_history_containment_removal_queue or {}
if organic_history_containment_actors == nil then
  organic_history_containment_actors = {
    india = {
      maxForeignCities = 1,
      regions = {
        steppe = true,
        steppe_mongolia = true,
        south_china = true,
        north_china = true,
        japan_korea = true,
        east_asia = true,
      },
    },
  }
end
organic_history_objective_enabled =
    organic_history_objective_enabled or false
organic_history_objective_max_gold =
    organic_history_objective_max_gold or 60
organic_history_objective_max_units =
    organic_history_objective_max_units or 4
organic_history_objective_fallback_settlement_enabled =
    organic_history_objective_fallback_settlement_enabled or false
if organic_history_contact_diagnostics_enabled == nil then
  organic_history_contact_diagnostics_enabled = true
end

function organic_history_alive_regional_successor(player, region_id)
  local region = organic_history_region_status[region_id] or {}
  local region_leader = organic_history_player_by_id(region.leader or -1)

  if region_leader ~= nil and region_leader.id ~= player.id
     and region_leader.is_alive and region_leader:num_cities() > 0 then
    local _, region_actor_id = organic_history_actor_metadata_for(region_leader)

    return region_leader, region_actor_id or "unknown"
  end

  if organic_history_partial_contraction_claimant_successors_enabled then
    local best_player = nil
    local best_actor_id = nil
    local best_score = 999
    local scores = {core = 1, historical = 2, contested = 3, colonial = 4,
                    cultural = 5, respawn = 6}

    for other in players_iterate() do
      if other.id ~= player.id and other.is_alive and other:num_cities() > 0 then
        local _, other_actor_id = organic_history_actor_metadata_for(other)
        local claims = organic_history_active_actor_region_claims()[other_actor_id]
        local claim_type = organic_history_region_claim_type(claims, region_id)
        local score = scores[claim_type]

        if score ~= nil and score < best_score then
          best_player = other
          best_actor_id = other_actor_id
          best_score = score
        end
      end
    end

    if best_player ~= nil then
      return best_player, best_actor_id or "unknown"
    end
  end

  return nil, nil
end
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
if organic_history_claim_pressure_enabled == nil then
  organic_history_claim_pressure_enabled = true
end
organic_history_emergence_enabled =
    organic_history_emergence_enabled or false
organic_history_emergence_conditional_enabled =
    organic_history_emergence_conditional_enabled or false
organic_history_emergence_probability =
    organic_history_emergence_probability or 45
organic_history_emergence_relocation_radius =
    organic_history_emergence_relocation_radius or 18
organic_history_emergence_weak_holder_crisis_threshold =
    organic_history_emergence_weak_holder_crisis_threshold or 0.45
organic_history_emergence_delay_cooldown =
    organic_history_emergence_delay_cooldown or 10
organic_history_bootstrap_enabled =
    organic_history_bootstrap_enabled or false
organic_history_bootstrap_max_gold =
    organic_history_bootstrap_max_gold or 150
organic_history_bootstrap_max_units =
    organic_history_bootstrap_max_units or 8
organic_history_tech_floor_enabled =
    organic_history_tech_floor_enabled or false
organic_history_tech_floor_delta =
    organic_history_tech_floor_delta or 2
organic_history_tech_floor_max_techs =
    organic_history_tech_floor_max_techs or 12
organic_history_tech_floor_min_alive_peers =
    organic_history_tech_floor_min_alive_peers or 4
organic_history_tech_floor_min_popularity =
    organic_history_tech_floor_min_popularity or 2
organic_history_tech_floor_iteration_cap =
    organic_history_tech_floor_iteration_cap or 256
organic_history_claim_conversion_enabled =
    organic_history_claim_conversion_enabled or false
organic_history_claim_conversion_core_gold =
    organic_history_claim_conversion_core_gold or 40
organic_history_claim_conversion_historical_gold =
    organic_history_claim_conversion_historical_gold or 20
organic_history_claim_conversion_history_amount =
    organic_history_claim_conversion_history_amount or 200
organic_history_claim_conversion_free_building =
    organic_history_claim_conversion_free_building or "Walls"
organic_history_claim_conversion_min_city_size =
    organic_history_claim_conversion_min_city_size or 1
organic_history_claim_conversion_max_per_actor =
    organic_history_claim_conversion_max_per_actor or 99
organic_history_claim_conversion_lock_turns =
    organic_history_claim_conversion_lock_turns or 20
organic_history_fallback_successor_spawn_enabled =
    organic_history_fallback_successor_spawn_enabled or false
organic_history_fallback_successor_cooldown =
    organic_history_fallback_successor_cooldown or 30
organic_history_fallback_successor_max_per_turn =
    organic_history_fallback_successor_max_per_turn or 1
organic_history_homeland_defense_enabled =
    organic_history_homeland_defense_enabled or false
organic_history_homeland_defense_era_window_turns =
    organic_history_homeland_defense_era_window_turns or 80
organic_history_homeland_defense_min_defenders =
    organic_history_homeland_defense_min_defenders or 1
organic_history_homeland_defense_min_defenders_capital =
    organic_history_homeland_defense_min_defenders_capital or 2
organic_history_homeland_defense_cooldown =
    organic_history_homeland_defense_cooldown or 6
organic_history_homeland_defense_max_total_per_actor =
    organic_history_homeland_defense_max_total_per_actor or 6
organic_history_homeland_defense_max_per_turn =
    organic_history_homeland_defense_max_per_turn or 2
organic_history_sumer_urbanization_enabled =
    organic_history_sumer_urbanization_enabled or false
organic_history_sumer_urbanization_target_cities =
    organic_history_sumer_urbanization_target_cities or 3
organic_history_sumer_urbanization_max_cities =
    organic_history_sumer_urbanization_max_cities or 2
organic_history_sumer_urbanization_cooldown =
    organic_history_sumer_urbanization_cooldown or 20
organic_history_burst_enabled =
    organic_history_burst_enabled or false
organic_history_burst_max_gold =
    organic_history_burst_max_gold or 60
organic_history_burst_max_units =
    organic_history_burst_max_units or 4
organic_history_near_east_handoff_enabled =
    organic_history_near_east_handoff_enabled or false
organic_history_near_east_handoff_max_gold =
    organic_history_near_east_handoff_max_gold or 50
organic_history_near_east_handoff_max_units =
    organic_history_near_east_handoff_max_units or 3
organic_history_conquest_target_enabled =
    organic_history_conquest_target_enabled or false
organic_history_conquest_target_max_gold =
    organic_history_conquest_target_max_gold or 45
organic_history_conquest_target_max_units =
    organic_history_conquest_target_max_units or 3
organic_history_core_consolidation_enabled =
    organic_history_core_consolidation_enabled or false
organic_history_core_consolidation_max_cities =
    organic_history_core_consolidation_max_cities or 2
organic_history_core_consolidation_cooldown =
    organic_history_core_consolidation_cooldown or 20
organic_history_collapse_diagnostics_enabled =
    organic_history_collapse_diagnostics_enabled or true
organic_history_flavor_diagnostics_enabled =
    organic_history_flavor_diagnostics_enabled or true
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
organic_history_emergence_attempts = organic_history_emergence_attempts or {}
organic_history_emergence_blocked = organic_history_emergence_blocked or {}
organic_history_emergence_spawned = organic_history_emergence_spawned or {}
organic_history_emergence_delayed_until =
    organic_history_emergence_delayed_until or {}
organic_history_bootstrap_applied = organic_history_bootstrap_applied or {}
organic_history_tech_floor_applied = organic_history_tech_floor_applied or {}
organic_history_claim_conversion_locked = organic_history_claim_conversion_locked or {}
organic_history_claim_conversion_actor_counts = organic_history_claim_conversion_actor_counts or {}
organic_history_fallback_successor_last_turn = organic_history_fallback_successor_last_turn or {}
organic_history_fallback_successor_spawns_this_turn = 0
organic_history_homeland_defense_last_turn = organic_history_homeland_defense_last_turn or {}
organic_history_homeland_defense_total = organic_history_homeland_defense_total or {}
organic_history_homeland_defense_spawns_this_turn = 0
organic_history_sumer_urbanization_created =
    organic_history_sumer_urbanization_created or 0
organic_history_sumer_urbanization_last_turn =
    organic_history_sumer_urbanization_last_turn or -999999
organic_history_burst_applications = organic_history_burst_applications or {}
organic_history_burst_last_turn = organic_history_burst_last_turn or {}
organic_history_near_east_handoff_applications =
    organic_history_near_east_handoff_applications or {}
organic_history_near_east_handoff_last_turn =
    organic_history_near_east_handoff_last_turn or {}
organic_history_conquest_target_applications =
    organic_history_conquest_target_applications or {}
organic_history_conquest_target_last_turn =
    organic_history_conquest_target_last_turn or {}
organic_history_conquest_conversion_tracking =
    organic_history_conquest_conversion_tracking or {}
organic_history_conquest_conversion_next_id =
    organic_history_conquest_conversion_next_id or 1
organic_history_objective_applications =
    organic_history_objective_applications or {}
organic_history_objective_last_turn =
    organic_history_objective_last_turn or {}
organic_history_objective_attempted_sites =
    organic_history_objective_attempted_sites or {}
organic_history_settler_conversion_tracking =
    organic_history_settler_conversion_tracking or {}
organic_history_settler_conversion_next_id =
    organic_history_settler_conversion_next_id or 1
organic_history_iberian_activation_sequence =
    organic_history_iberian_activation_sequence or 0
organic_history_iberian_activation_logged =
    organic_history_iberian_activation_logged or {}
organic_history_core_consolidation_applications =
    organic_history_core_consolidation_applications or {}
organic_history_core_consolidation_last_turn =
    organic_history_core_consolidation_last_turn or {}
organic_history_actor_birth_turns = organic_history_actor_birth_turns or {}
organic_history_partial_contraction_streaks =
    organic_history_partial_contraction_streaks or {}
organic_history_partial_contraction_last_turn =
    organic_history_partial_contraction_last_turn or {}
organic_history_partial_contraction_debt =
    organic_history_partial_contraction_debt or {}
organic_history_partial_contraction_success_this_turn = false
organic_history_arrivals_seen = organic_history_arrivals_seen or {}
organic_history_crossings_seen = organic_history_crossings_seen or {}
organic_history_contacts_seen = organic_history_contacts_seen or {}
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
  organic_history_partial_contraction_success_this_turn = false
  organic_history_fallback_successor_spawns_this_turn = 0
  organic_history_homeland_defense_spawns_this_turn = 0
  organic_history_map_dimensions_cache = nil
  organic_history_global_scenario_metadata_active_cache = nil
  organic_history_process_containment_queue(turn)
  log.normal("organic_history turn_begin turn=%d year=%d", turn, year)
  organic_history_log_scenario_metadata_status(turn)
  organic_history_check_emergence(turn)
  organic_history_log_player_metrics(turn, year)
  organic_history_log_regional_hegemony(turn)
  organic_history_log_contact_diagnostics(turn)
  organic_history_log_claim_pressure(turn)
  organic_history_check_settler_conversions(turn)
  organic_history_check_conquest_conversions(turn)
  organic_history_check_homeland_defense(turn)
  organic_history_check_expansion_pressures(turn)
  organic_history_check_sumer_urbanization(turn)
  organic_history_check_bursts(turn)
  organic_history_check_near_east_handoffs(turn)
  organic_history_check_conquest_targets(turn)
  organic_history_check_objectives(turn)
  organic_history_check_core_consolidation(turn)
  organic_history_log_collapse_diagnostics(turn)
  organic_history_log_flavor_diagnostics(turn)
  organic_history_check_dynastic_transfers(turn)
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

organic_history_scenario_regions_large = {
  africa = {name = "Africa", x_min = 30, x_max = 62, y_min = 38, y_max = 78},
  americas = {name = "Americas", x_min = 118, x_max = 159, y_min = 15, y_max = 78},
  china = {name = "China", x_min = 76, x_max = 91, y_min = 28, y_max = 46},
  east_asia = {name = "East Asia", x_min = 92, x_max = 110, y_min = 24, y_max = 42},
  europe = {name = "Europe", x_min = 20, x_max = 43, y_min = 20, y_max = 38},
  india = {name = "India", x_min = 60, x_max = 76, y_min = 38, y_max = 56},
  near_east = {name = "Near East", x_min = 44, x_max = 62, y_min = 34, y_max = 48},
  steppe = {name = "Steppe", x_min = 55, x_max = 92, y_min = 18, y_max = 30}
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

organic_history_actor_region_claims = {
  abbasid = {core = {"near_east"}, historical = {"africa", "india"}, contested = {"europe"}},
  africa = {core = {"africa"}, historical = {"near_east"}, contested = {}},
  aztec = {core = {"americas"}, historical = {}, contested = {}},
  byzantium = {core = {"near_east"}, historical = {"europe"}, contested = {}},
  castile = {core = {"europe"}, historical = {"americas", "africa"}, contested = {}},
  china = {core = {"china"}, historical = {"east_asia", "steppe"}, contested = {}},
  chola = {core = {"india"}, historical = {"east_asia"}, contested = {}},
  egypt = {core = {"africa"}, historical = {"near_east"}, contested = {}},
  franks = {core = {"europe"}, historical = {"near_east"}, contested = {}},
  greece = {core = {"europe"}, historical = {"near_east"}, contested = {}},
  inca = {core = {"americas"}, historical = {}, contested = {}},
  india = {core = {"india"}, historical = {"near_east"}, contested = {}},
  japan = {core = {"east_asia"}, historical = {"china"}, contested = {}},
  ming = {core = {"china"}, historical = {"east_asia"}, contested = {"steppe"}},
  ottoman = {core = {"near_east"}, historical = {"europe", "africa"}, contested = {}},
  persia = {core = {"near_east"}, historical = {"india", "steppe"}, contested = {"europe"}},
  portugal = {core = {"europe"}, historical = {"africa", "india", "americas"}, contested = {}},
  rome = {core = {"europe"}, historical = {"near_east", "africa"}, contested = {"steppe"}},
  song = {core = {"china"}, historical = {"east_asia"}, contested = {"steppe"}},
  steppe = {core = {"steppe"}, historical = {"china", "near_east"}, contested = {"europe"}},
  sumer = {core = {"near_east"}, historical = {"africa"}, contested = {}},
  venice = {core = {"europe"}, historical = {"near_east"}, contested = {}}
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

organic_history_scenario_city_metadata_large = {
  ["Aachen"] = {actor = "franks", region = "europe", core = true, x = 30, y = 26},
  ["Athens"] = {actor = "greece", region = "europe", core = true, x = 41, y = 34},
  ["Baghdad"] = {actor = "abbasid", region = "near_east", core = true, x = 50, y = 43},
  ["Beijing"] = {actor = "ming", region = "china", core = true, x = 81, y = 32},
  ["Chang'an"] = {actor = "china", region = "china", core = true, x = 81, y = 32},
  ["Constantinople"] = {actor = "byzantium", region = "near_east", core = true, x = 44, y = 34},
  ["Cusco"] = {actor = "inca", region = "americas", core = true, x = 152, y = 62},
  ["Istanbul"] = {actor = "ottoman", region = "near_east", core = true, x = 44, y = 34},
  ["Kaifeng"] = {actor = "song", region = "china", core = true, x = 79, y = 35},
  ["Kanchipuram"] = {actor = "chola", region = "india", core = true, x = 66, y = 50},
  ["Karakorum"] = {actor = "steppe", region = "steppe", core = true, x = 82, y = 24},
  ["Kyoto"] = {actor = "japan", region = "east_asia", core = true, x = 95, y = 35},
  ["Lisbon"] = {actor = "portugal", region = "europe", core = true, x = 23, y = 35},
  ["Memphis"] = {actor = "egypt", region = "africa", core = true, x = 41, y = 40},
  ["Niani"] = {actor = "africa", region = "africa", core = true, x = 31, y = 54},
  ["Parsa"] = {actor = "persia", region = "near_east", core = true, x = 56, y = 36},
  ["Pataliputra"] = {actor = "india", region = "india", core = true, x = 64, y = 41},
  ["Roma"] = {actor = "rome", region = "europe", core = true, x = 35, y = 32},
  ["Tenochtitlan"] = {actor = "aztec", region = "americas", core = true, x = 142, y = 44},
  ["Thanjavur"] = {actor = "chola", region = "india", core = true, x = 66, y = 50},
  ["Toledo"] = {actor = "castile", region = "europe", core = true, x = 25, y = 32},
  ["Uruk"] = {actor = "sumer", region = "near_east", core = true, x = 50, y = 39}
}

organic_history_emergence_actors = {
  greece = {leader = "Pericles", nation = "Greek", style = "Classical", city = "Athens", x = 41, y = 34, core_region = "europe", earliest_turn = 40, gold = 75, techs = {"Alphabet", "Writing"}},
  persia = {leader = "Cyrus", nation = "Persian", style = "Classical", city = "Parsa", x = 56, y = 36, core_region = "near_east", earliest_turn = 45, gold = 100, techs = {"Horseback Riding", "Bronze Working", "Trade"}, traits = {Expansionist = 30, Aggressive = 25, Builder = 10}},
  rome = {leader = "Romulus", nation = "Roman", style = "Classical", city = "Roma", x = 35, y = 32, core_region = "europe", earliest_turn = 55, gold = 100, techs = {"Warrior Code", "Bronze Working", "Trade"}, traits = {Expansionist = 40, Aggressive = 25, Builder = 10}},
  franks = {leader = "Charlemagne", nation = "French", style = "European", city = "Aachen", x = 30, y = 26, core_region = "europe", earliest_turn = 105, gold = 90, techs = {"Monarchy", "Feudalism"}},
  abbasid = {leader = "Harun al-Rashid", nation = "Arab", style = "Babylonian", city = "Baghdad", x = 50, y = 43, core_region = "near_east", earliest_turn = 110, gold = 100, techs = {"Philosophy", "Mathematics"}},
  chola = {leader = "Rajaraja Chola", nation = "Chola", style = "Classical", city = "Kanchipuram", x = 66, y = 50, core_region = "india", earliest_turn = 115, gold = 105, techs = {"Seafaring", "Trade"}, traits = {Trader = 35, Expansionist = 25, Builder = 15}},
  song = {leader = "Taizu", nation = "Korean", style = "Asian", city = "Kaifeng", x = 79, y = 35, core_region = "china", earliest_turn = 115, gold = 115, techs = {"Invention", "Gunpowder", "Trade"}, traits = {Builder = 35, Expansionist = 20, Trader = 15}},
  steppe = {leader = "Temujin", nation = "Mongol", style = "Asian", city = "Karakorum", x = 82, y = 24, core_region = "steppe", earliest_turn = 125, gold = 115, techs = {"Horseback Riding", "Warrior Code"}, traits = {Aggressive = 45, Expansionist = 35}},
  castile = {leader = "Isabella", nation = "Spanish", style = "European", city = "Toledo", x = 25, y = 32, core_region = "europe", earliest_turn = 160, gold = 125, techs = {"Navigation", "Trade"}, traits = {Expansionist = 30, Trader = 25, Builder = 10}},
  portugal = {leader = "Henry", nation = "Portuguese", style = "European", city = "Lisbon", x = 23, y = 35, core_region = "europe", earliest_turn = 160, gold = 125, techs = {"Seafaring", "Navigation"}, traits = {Expansionist = 35, Trader = 30, Builder = 10}},
  ming = {leader = "Xuande", nation = "Manchu", style = "Asian", city = "Beijing", x = 81, y = 32, core_region = "china", earliest_turn = 160, gold = 115, techs = {"Invention", "Gunpowder"}},
  japan = {leader = "Ashikaga Yoshimasa", nation = "Japanese", style = "Asian", city = "Kyoto", x = 95, y = 35, core_region = "east_asia", earliest_turn = 160, gold = 80, techs = {"Feudalism", "Seafaring"}},
  aztec = {leader = "Moctezuma I", nation = "Aztec", style = "Tropical", city = "Tenochtitlan", x = 142, y = 44, core_region = "americas", earliest_turn = 160, gold = 75, techs = {"Construction", "Warrior Code"}},
  inca = {leader = "Pachacuti", nation = "Inca", style = "Tropical", city = "Cusco", x = 152, y = 62, core_region = "americas", earliest_turn = 160, gold = 75, techs = {"Masonry", "Pottery"}}
}

-- BEGIN GENERATED GLOBAL HISTORY DATA
-- Generated by tools/organic_history/generate_history_artifacts.py.
-- Edit data/organic_history/history/earth_global_4000.json instead.
organic_history_global_scenario_actor_metadata = {
  abbasid = {
    core_cities = {
      Baghdad = true
    },
    core_region = "mesopotamia",
    leader = "Harun al-Rashid",
    nation = "Arab",
    successor_names = {"Abbasid Provincial Secession", "Mesopotamian Emirate"},
    successor_nation = "Arab"
  },
  assyria = {
    core_cities = {
      Ashur = true
    },
    core_region = "mesopotamia",
    leader = "Ashurbanipal",
    nation = "Assyrian",
    successor_names = {"Assyrian Provincial Secession", "Upper Mesopotamian Kingdom"},
    successor_nation = "Assyrian"
  },
  aztec = {
    core_cities = {
      Tenochtitlan = true
    },
    core_region = "mesoamerica",
    leader = "Moctezuma I",
    nation = "Aztec",
    successor_names = {"Central Mexican Secession", "Aztec Tributary Secession"},
    successor_nation = "Aztec"
  },
  carthage = {
    core_cities = {
      Carthage = true
    },
    core_region = "maghreb_punic_west",
    leader = "Hannibal",
    nation = "Carthaginian",
    successor_names = {"Punic Provincial Secession", "Western Mediterranean League"},
    successor_nation = "Carthaginian"
  },
  castile = {
    core_cities = {
      Toledo = true
    },
    core_region = "iberia",
    leader = "Isabella",
    nation = "Spanish",
    successor_names = {"Castilian Crown Secession", "Iberian Frontier Secession"},
    successor_nation = "Spanish"
  },
  celts = {
    core_cities = {
      Bibracte = true
    },
    core_region = "gaul",
    leader = "Vercingetorix",
    nation = "Celtic",
    successor_names = {"Gallic Tribal Secession", "Celtic Confederation"},
    successor_nation = "Celtic"
  },
  china = {
    core_cities = {
      ["Chang'an"] = true
    },
    core_region = "north_china",
    leader = "Qin Shi Huang",
    nation = "Chinese",
    successor_names = {"Chinese Regional Secession", "Yellow River Secession"},
    successor_nation = "Chinese"
  },
  chola = {
    core_cities = {
      Kanchipuram = true
    },
    core_region = "deccan_south_india",
    leader = "Rajaraja Chola",
    nation = "Chola",
    successor_names = {"Tamil Country Secession", "Indian Ocean Polity"},
    successor_nation = "Indian"
  },
  egypt = {
    core_cities = {
      Memphis = true
    },
    core_region = "nile",
    leader = "Narmer",
    nation = "Egyptian",
    successor_names = {"Nile Delta Secession", "Upper Egyptian Secession"},
    successor_nation = "Egyptian"
  },
  franks = {
    core_cities = {
      Aachen = true
    },
    core_region = "gaul",
    leader = "Charlemagne",
    nation = "French",
    successor_names = {"Frankish March Secession", "West Frankish Secession"},
    successor_nation = "French"
  },
  greece = {
    core_cities = {
      Athens = true
    },
    core_region = "balkans_aegean",
    leader = "Pericles",
    nation = "Greek",
    successor_names = {"Hellenic League Secession", "Greek City Secession"},
    successor_nation = "Greek"
  },
  hittite = {
    core_cities = {
      Hattusa = true
    },
    core_region = "anatolia",
    leader = "Suppiluliuma",
    nation = "Hittite",
    successor_names = {"Anatolian Secession", "Hittite Successor Kingdom"},
    successor_nation = "Hittite"
  },
  inca = {
    core_cities = {
      Cusco = true
    },
    core_region = "andes",
    leader = "Pachacuti",
    nation = "Inca",
    successor_names = {"Andean Secession", "Inca Provincial Secession"},
    successor_nation = "Inca"
  },
  india = {
    core_cities = {
      Pataliputra = true
    },
    core_region = "north_india",
    leader = "Chandragupta",
    nation = "Indian",
    successor_names = {"Magadhan Secession", "Indian Regional Secession"},
    successor_nation = "Indian"
  },
  japan = {
    core_cities = {
      Kyoto = true
    },
    core_region = "japan_korea",
    leader = "Ashikaga Yoshimasa",
    nation = "Japanese",
    successor_names = {"Japanese Daimyo Secession", "Eastern Island Secession"},
    successor_nation = "Japanese"
  },
  ming = {
    core_cities = {
      Beijing = true
    },
    core_region = "north_china",
    leader = "Xuande",
    nation = "Manchu",
    successor_names = {"Ming Provincial Secession", "Northern Chinese Secession"},
    successor_nation = "Chinese"
  },
  nubia = {
    core_cities = {
      Napata = true
    },
    core_region = "nile",
    leader = "Piye",
    nation = "Nubian",
    successor_names = {"Kushite Secession", "Upper Nile Kingdom"},
    successor_nation = "Nubian"
  },
  persia = {
    core_cities = {
      Parsa = true
    },
    core_region = "iran",
    leader = "Cyrus",
    nation = "Persian",
    successor_names = {"Persian Satrapy Secession", "Iranian Plateau Secession"},
    successor_nation = "Persian"
  },
  phoenicia = {
    core_cities = {
      Tyre = true
    },
    core_region = "levant",
    leader = "Hiram",
    nation = "Phoenician",
    successor_names = {"Levantine City Secession", "Phoenician Maritime League"},
    successor_nation = "Phoenician"
  },
  portugal = {
    core_cities = {
      Lisbon = true
    },
    core_region = "iberia",
    leader = "Henry",
    nation = "Portuguese",
    successor_names = {"Portuguese Atlantic Secession", "Iberian Port Secession"},
    successor_nation = "Portuguese"
  },
  rome = {
    core_cities = {
      Roma = true
    },
    core_region = "italy",
    leader = "Romulus",
    nation = "Roman",
    successor_names = {"Western Roman Secession", "Italian Roman Secession", "Roman Frontier Secession"},
    successor_nation = "Roman"
  },
  song = {
    core_cities = {
      Kaifeng = true
    },
    core_region = "north_china",
    leader = "Taizu",
    nation = "Korean",
    successor_names = {"Southern Song Secession", "Chinese Provincial Secession"},
    successor_nation = "Chinese"
  },
  steppe = {
    core_cities = {
      Karakorum = true
    },
    core_region = "steppe_mongolia",
    leader = "Temujin",
    nation = "Mongol",
    successor_names = {"Steppe Ulus Secession", "Mongol Horde Secession"},
    successor_nation = "Mongol"
  },
  sumer = {
    core_cities = {
      Uruk = true
    },
    core_region = "mesopotamia",
    leader = "Gilgamesh",
    nation = "Sumerian",
    successor_names = {"Sumerian City Secession", "Mesopotamian Secession"},
    successor_nation = "Sumerian"
  }
}

organic_history_global_scenario_city_metadata = {
  Aachen = {
    actor = "franks",
    core = true,
    region = "gaul",
    x = 30,
    y = 26
  },
  Ashur = {
    actor = "assyria",
    core = true,
    region = "mesopotamia",
    x = 50,
    y = 37
  },
  Athens = {
    actor = "greece",
    core = true,
    region = "balkans_aegean",
    x = 41,
    y = 34
  },
  Baghdad = {
    actor = "abbasid",
    core = true,
    region = "mesopotamia",
    x = 50,
    y = 43
  },
  Beijing = {
    actor = "ming",
    core = true,
    region = "north_china",
    x = 81,
    y = 32
  },
  Bibracte = {
    actor = "celts",
    core = true,
    region = "gaul",
    x = 30,
    y = 28
  },
  Carthage = {
    actor = "carthage",
    core = true,
    region = "maghreb_punic_west",
    x = 35,
    y = 39
  },
  ["Chang'an"] = {
    actor = "china",
    core = true,
    region = "north_china",
    x = 81,
    y = 32
  },
  Cusco = {
    actor = "inca",
    core = true,
    region = "andes",
    x = 152,
    y = 62
  },
  Hattusa = {
    actor = "hittite",
    core = true,
    region = "anatolia",
    x = 45,
    y = 34
  },
  Kaifeng = {
    actor = "song",
    core = true,
    region = "north_china",
    x = 79,
    y = 35
  },
  Kanchipuram = {
    actor = "chola",
    core = true,
    region = "deccan_south_india",
    x = 66,
    y = 50
  },
  Karakorum = {
    actor = "steppe",
    core = true,
    region = "steppe_mongolia",
    x = 82,
    y = 24
  },
  Kyoto = {
    actor = "japan",
    core = true,
    region = "japan_korea",
    x = 95,
    y = 35
  },
  Lisbon = {
    actor = "portugal",
    core = true,
    region = "iberia",
    x = 23,
    y = 35
  },
  Memphis = {
    actor = "egypt",
    core = true,
    region = "nile",
    x = 41,
    y = 40
  },
  Napata = {
    actor = "nubia",
    core = true,
    region = "nile",
    x = 42,
    y = 46
  },
  Parsa = {
    actor = "persia",
    core = true,
    region = "iran",
    x = 56,
    y = 36
  },
  Pataliputra = {
    actor = "india",
    core = true,
    region = "north_india",
    x = 64,
    y = 41
  },
  Roma = {
    actor = "rome",
    core = true,
    region = "italy",
    x = 35,
    y = 32
  },
  Tenochtitlan = {
    actor = "aztec",
    core = true,
    region = "mesoamerica",
    x = 142,
    y = 44
  },
  Toledo = {
    actor = "castile",
    core = true,
    region = "iberia",
    x = 25,
    y = 32
  },
  Tyre = {
    actor = "phoenicia",
    core = true,
    region = "levant",
    x = 46,
    y = 39
  },
  Uruk = {
    actor = "sumer",
    core = true,
    region = "mesopotamia",
    x = 50,
    y = 39
  }
}

organic_history_global_scenario_region_order = {"iberia", "gaul", "italy", "balkans_aegean", "anatolia", "levant", "mesopotamia", "iran", "nile", "maghreb_punic_west", "north_india", "deccan_south_india", "north_china", "south_china", "japan_korea", "steppe_mongolia", "mesoamerica", "andes", "europe", "near_east", "africa", "india", "china", "east_asia", "steppe", "americas"}

organic_history_global_scenario_regions = {
  africa = {
    name = "Africa",
    x_max = 62,
    x_min = 30,
    y_max = 78,
    y_min = 38
  },
  americas = {
    name = "Americas",
    x_max = 159,
    x_min = 118,
    y_max = 78,
    y_min = 15
  },
  anatolia = {
    name = "Anatolia",
    x_max = 48,
    x_min = 44,
    y_max = 37,
    y_min = 32
  },
  andes = {
    name = "Andes",
    x_max = 157,
    x_min = 148,
    y_max = 70,
    y_min = 55
  },
  balkans_aegean = {
    name = "Balkans and Aegean",
    x_max = 43,
    x_min = 38,
    y_max = 37,
    y_min = 30
  },
  china = {
    name = "China",
    x_max = 91,
    x_min = 76,
    y_max = 46,
    y_min = 28
  },
  deccan_south_india = {
    name = "Deccan and South India",
    x_max = 70,
    x_min = 63,
    y_max = 56,
    y_min = 46
  },
  east_asia = {
    name = "East Asia",
    x_max = 110,
    x_min = 92,
    y_max = 42,
    y_min = 24
  },
  europe = {
    name = "Europe",
    x_max = 43,
    x_min = 20,
    y_max = 38,
    y_min = 20
  },
  gaul = {
    name = "Gaul",
    x_max = 34,
    x_min = 28,
    y_max = 31,
    y_min = 23
  },
  iberia = {
    name = "Iberia",
    x_max = 27,
    x_min = 20,
    y_max = 38,
    y_min = 30
  },
  india = {
    name = "India",
    x_max = 76,
    x_min = 60,
    y_max = 56,
    y_min = 38
  },
  iran = {
    name = "Iranian Plateau",
    x_max = 62,
    x_min = 54,
    y_max = 44,
    y_min = 34
  },
  italy = {
    name = "Italy",
    x_max = 37,
    x_min = 34,
    y_max = 36,
    y_min = 30
  },
  japan_korea = {
    name = "Japan and Korea",
    x_max = 110,
    x_min = 92,
    y_max = 42,
    y_min = 24
  },
  levant = {
    name = "Levant",
    x_max = 49,
    x_min = 45,
    y_max = 42,
    y_min = 38
  },
  maghreb_punic_west = {
    name = "Maghreb and Punic West",
    x_max = 38,
    x_min = 30,
    y_max = 45,
    y_min = 38
  },
  mesoamerica = {
    name = "Mesoamerica",
    x_max = 148,
    x_min = 136,
    y_max = 50,
    y_min = 38
  },
  mesopotamia = {
    name = "Mesopotamia",
    x_max = 53,
    x_min = 49,
    y_max = 44,
    y_min = 37
  },
  near_east = {
    name = "Near East",
    x_max = 62,
    x_min = 44,
    y_max = 48,
    y_min = 34
  },
  nile = {
    name = "Nile Valley",
    x_max = 43,
    x_min = 39,
    y_max = 49,
    y_min = 38
  },
  north_china = {
    name = "North China",
    x_max = 86,
    x_min = 76,
    y_max = 36,
    y_min = 28
  },
  north_india = {
    name = "North India",
    x_max = 67,
    x_min = 60,
    y_max = 45,
    y_min = 38
  },
  south_china = {
    name = "South China",
    x_max = 91,
    x_min = 76,
    y_max = 46,
    y_min = 37
  },
  steppe = {
    name = "Steppe",
    x_max = 92,
    x_min = 55,
    y_max = 30,
    y_min = 18
  },
  steppe_mongolia = {
    name = "Mongolian Steppe",
    x_max = 92,
    x_min = 76,
    y_max = 30,
    y_min = 18
  }
}

organic_history_global_actor_region_claims = {
  abbasid = {
    colonial = {},
    contested = {"balkans_aegean"},
    core = {"mesopotamia"},
    cultural = {},
    historical = {"levant", "iran", "nile", "north_india"},
    respawn = {}
  },
  assyria = {
    colonial = {},
    contested = {"steppe_mongolia"},
    core = {"mesopotamia"},
    cultural = {},
    historical = {"levant", "anatolia", "iran", "nile"},
    respawn = {}
  },
  aztec = {
    colonial = {},
    contested = {},
    core = {"mesoamerica"},
    cultural = {},
    historical = {"americas"},
    respawn = {}
  },
  carthage = {
    colonial = {},
    contested = {"levant", "balkans_aegean"},
    core = {"maghreb_punic_west"},
    cultural = {},
    historical = {"iberia", "italy"},
    respawn = {}
  },
  castile = {
    colonial = {"americas"},
    contested = {},
    core = {"iberia"},
    cultural = {},
    historical = {"mesoamerica", "andes", "maghreb_punic_west"},
    respawn = {}
  },
  celts = {
    colonial = {},
    contested = {"italy"},
    core = {"gaul"},
    cultural = {},
    historical = {"iberia", "italy", "europe"},
    respawn = {}
  },
  china = {
    colonial = {},
    contested = {},
    core = {"north_china"},
    cultural = {},
    historical = {"south_china", "japan_korea", "steppe_mongolia"},
    respawn = {}
  },
  chola = {
    colonial = {},
    contested = {},
    core = {"deccan_south_india"},
    cultural = {},
    historical = {"north_india", "east_asia"},
    respawn = {}
  },
  egypt = {
    colonial = {},
    contested = {},
    core = {"nile"},
    cultural = {},
    historical = {"levant", "mesopotamia"},
    respawn = {}
  },
  franks = {
    colonial = {},
    contested = {},
    core = {"gaul"},
    cultural = {},
    historical = {"italy", "iberia", "europe"},
    respawn = {}
  },
  greece = {
    colonial = {},
    contested = {},
    core = {"balkans_aegean"},
    cultural = {},
    historical = {"anatolia", "levant", "italy"},
    respawn = {}
  },
  hittite = {
    colonial = {},
    contested = {"balkans_aegean"},
    core = {"anatolia"},
    cultural = {},
    historical = {"levant", "mesopotamia"},
    respawn = {}
  },
  inca = {
    colonial = {},
    contested = {},
    core = {"andes"},
    cultural = {},
    historical = {"americas"},
    respawn = {}
  },
  india = {
    colonial = {},
    contested = {},
    core = {"north_india"},
    cultural = {},
    historical = {"deccan_south_india", "iran"},
    respawn = {}
  },
  japan = {
    colonial = {},
    contested = {},
    core = {"japan_korea"},
    cultural = {},
    historical = {"north_china", "south_china"},
    respawn = {}
  },
  ming = {
    colonial = {},
    contested = {"steppe_mongolia"},
    core = {"north_china"},
    cultural = {},
    historical = {"south_china", "japan_korea"},
    respawn = {}
  },
  nubia = {
    colonial = {},
    contested = {},
    core = {"nile"},
    cultural = {},
    historical = {"africa", "levant"},
    respawn = {}
  },
  persia = {
    colonial = {},
    contested = {"steppe_mongolia", "balkans_aegean"},
    core = {"iran"},
    cultural = {},
    historical = {"mesopotamia", "levant", "anatolia", "north_india"},
    respawn = {}
  },
  phoenicia = {
    colonial = {},
    contested = {},
    core = {"levant"},
    cultural = {},
    historical = {"maghreb_punic_west", "iberia", "italy", "balkans_aegean"},
    respawn = {}
  },
  portugal = {
    colonial = {"americas", "africa", "india"},
    contested = {},
    core = {"iberia"},
    cultural = {},
    historical = {"maghreb_punic_west", "deccan_south_india", "mesoamerica", "andes"},
    respawn = {}
  },
  rome = {
    colonial = {},
    contested = {"steppe_mongolia"},
    core = {"italy"},
    cultural = {},
    historical = {"iberia", "gaul", "balkans_aegean", "maghreb_punic_west", "levant", "anatolia"},
    respawn = {}
  },
  song = {
    colonial = {},
    contested = {"steppe_mongolia"},
    core = {"north_china"},
    cultural = {},
    historical = {"south_china", "japan_korea"},
    respawn = {}
  },
  steppe = {
    colonial = {},
    contested = {"gaul"},
    core = {"steppe_mongolia"},
    cultural = {},
    historical = {"north_china", "iran", "mesopotamia", "europe"},
    respawn = {}
  },
  sumer = {
    colonial = {},
    contested = {},
    core = {"mesopotamia"},
    cultural = {},
    historical = {"levant", "nile"},
    respawn = {}
  }
}

organic_history_global_actor_flavor_diagnostics = {
  abbasid = {
    policy_hints = {"caliphal_core", "trade_network"},
    uhv_diagnostics = {"mesopotamian_capital", "islamic_golden_age"}
  },
  assyria = {
    policy_hints = {"upper_mesopotamian_core", "military_empire"},
    uhv_diagnostics = {"mesopotamian_core", "near_east_military_pressure"}
  },
  aztec = {
    policy_hints = {"mesoamerican_core", "tributary_expansion"},
    uhv_diagnostics = {"central_mexico_core", "tributary_scale"}
  },
  carthage = {
    policy_hints = {"western_mediterranean_maritime", "punic_rival_pressure"},
    uhv_diagnostics = {"punic_core", "western_mediterranean_reach"}
  },
  castile = {
    policy_hints = {"iberian_core", "atlantic_colonizer"},
    uhv_diagnostics = {"iberian_core", "atlantic_contact"}
  },
  celts = {
    policy_hints = {"tribal_european_core", "anti_imperial_pressure"},
    uhv_diagnostics = {"gallic_core", "european_tribal_pressure"}
  },
  china = {
    policy_hints = {"yellow_river_core", "dynastic_reunification"},
    uhv_diagnostics = {"north_china_core_retention", "dynastic_continuity"}
  },
  chola = {
    policy_hints = {"indian_ocean_maritime", "southern_india_core"},
    uhv_diagnostics = {"southern_india_core", "indian_ocean_trade"}
  },
  egypt = {
    policy_hints = {"river_valley_core", "nile_food_security"},
    uhv_diagnostics = {"nile_core_retention", "early_monumental_growth"}
  },
  franks = {
    policy_hints = {"post_roman_successor", "feudal_core"},
    uhv_diagnostics = {"western_europe_core", "post_roman_recovery"}
  },
  greece = {
    policy_hints = {"mediterranean_maritime", "city_state_core"},
    uhv_diagnostics = {"aegean_city_density", "classical_knowledge"}
  },
  hittite = {
    policy_hints = {"anatolian_core", "bronze_age_rival"},
    uhv_diagnostics = {"anatolian_core", "bronze_age_balance"}
  },
  inca = {
    policy_hints = {"andean_core", "mountain_empire"},
    uhv_diagnostics = {"cusco_core", "andean_reach"}
  },
  india = {
    policy_hints = {"subcontinental_core", "river_plain_growth"},
    uhv_diagnostics = {"ganges_core_retention", "subcontinental_scale"}
  },
  japan = {
    policy_hints = {"island_core", "maritime_defense"},
    uhv_diagnostics = {"kyoto_core", "island_unification"}
  },
  ming = {
    policy_hints = {"northern_china_capital", "dynastic_reunification"},
    uhv_diagnostics = {"beijing_core", "dynastic_recovery"}
  },
  nubia = {
    policy_hints = {"upper_nile_core", "egyptian_successor_pressure"},
    uhv_diagnostics = {"upper_nile_core", "nile_corridor_pressure"}
  },
  persia = {
    policy_hints = {"imperial_successor", "satrapy_overextension"},
    uhv_diagnostics = {"iranian_core_retention", "near_east_imperial_scale"}
  },
  phoenicia = {
    policy_hints = {"levantine_maritime", "trade_network"},
    uhv_diagnostics = {"levantine_core", "mediterranean_trade"}
  },
  portugal = {
    policy_hints = {"atlantic_maritime", "trade_post_colonizer"},
    uhv_diagnostics = {"lisbon_core", "oceanic_trade_reach"}
  },
  rome = {
    policy_hints = {"italian_core", "mediterranean_empire", "frontier_pressure"},
    uhv_diagnostics = {"italian_core_retention", "mediterranean_reach", "late_imperial_stress"}
  },
  song = {
    policy_hints = {"chinese_reunification", "commercial_bureaucracy"},
    uhv_diagnostics = {"kaifeng_core", "commercial_and_tech_growth"}
  },
  steppe = {
    policy_hints = {"nomadic_pressure", "horse_archer_expansion"},
    uhv_diagnostics = {"steppe_core", "eurasian_reach"}
  },
  sumer = {
    policy_hints = {"city_state_core", "mesopotamian_irrigation"},
    uhv_diagnostics = {"early_writing", "mesopotamian_city_density"}
  }
}

organic_history_global_actor_objectives = {
  abbasid = {{
    cityName = "Abbasid Provincial Centre",
    cooldownTurns = 20,
    createCity = true,
    defenders = 1,
    durationTurns = 90,
    escapeRoutes = {"on_target", "missing_site", "site_already_filled"},
    gold = 30,
    id = "abbasid_corridor_consolidation",
    maxApplications = 1,
    settlers = 0,
    startTurnAfterBirth = 0,
    targetCities = 4,
    targetRegions = {"mesopotamia", "levant", "iran"},
    type = "settlement"
  }},
  castile = {{
    cooldownTurns = 18,
    defenders = 1,
    durationTurns = 80,
    escapeRoutes = {"on_target", "missing_site", "site_already_filled"},
    fallbackRegions = {"maghreb_punic_west"},
    gold = 30,
    id = "castile_iberian_consolidation",
    maxApplications = 2,
    settlers = 1,
    startTurnAfterBirth = 0,
    targetCities = 3,
    targetRegions = {"iberia"},
    type = "settlement"
  }},
  portugal = {{
    cooldownTurns = 18,
    defenders = 1,
    durationTurns = 80,
    escapeRoutes = {"on_target", "missing_site", "site_already_filled"},
    fallbackRegions = {"maghreb_punic_west"},
    gold = 35,
    id = "portugal_iberian_port_consolidation",
    maxApplications = 2,
    settlers = 1,
    ships = 1,
    startTurnAfterBirth = 0,
    targetCities = 2,
    targetRegions = {"iberia"},
    type = "settlement"
  }},
  rome = {{
    cooldownTurns = 18,
    declareWar = true,
    defenders = 1,
    durationTurns = 100,
    escapeRoutes = {"on_target", "no_rival_target", "high_city_scale", "unreachable_target"},
    expeditionaryStaging = true,
    gold = 45,
    holdDefenders = 0,
    holdGold = 0,
    id = "rome_mediterranean_conquest",
    maxApplications = 3,
    minCities = 1,
    minRivalCities = 1,
    offensiveUnits = 2,
    startTurnAfterBirth = 8,
    targetCities = 10,
    targetRegions = {"italy", "gaul", "iberia"},
    type = "conquest"
  }}
}

organic_history_global_historical_gravity = {
  conditionGates = {
    collapseOrContraction = {"sustained_high_collapse_risk", "overextension", "low_core_control", "low_mandate", "low_cohesion", "high_unrest_or_autonomy", "fiscal_or_war_stress", "validated_release_candidates"},
    contactShock = {"actual_old_world_new_world_contact", "isolation_or_low_contact_immunity", "population_density_or_city_size", "development_and_diplomacy_modifiers"},
    dynasticTransfer = {"successor_window_open", "predecessor_low_mandate_or_fragmented", "successor_core_controlled_by_predecessor_or_foreign_holder", "validated_core_transfer_or_claimant_site", "no_recent_birth_protection"},
    regionalExpansionPressure = {"below_target_city_curve", "under_owned_core_or_historical_region", "nearby_weak_holder_or_vacant_site", "sufficient_economy_or_profile_bootstrap", "no_active_collapse_crisis"}
  },
  escapeRoutes = {
    examples = {
      china = "A high-mandate, unified China should continue or reform instead of always being replaced by Song or Ming.",
      new_world = "Aztec/Inca outcomes after contact should vary with development, diplomacy, geography, and preparedness.",
      rome = "A Rome with strong Italy/core control, good cohesion, and restrained frontier overreach should avoid collapse pressure."
    },
    generic = {"high_core_control", "high_mandate", "high_cohesion", "low_unrest", "positive_economy", "adequate_garrisons", "defensive_investment", "successful_reform", "good_diplomacy", "restrained_expansion"}
  },
  mechanicSeparation = {
    forbiddenPattern = "Do not fire events only because an actor and calendar date match history.",
    historicalDataRole = "Defines claims, niches, successor identities, expected pressures, and flavor.",
    mechanicTriggerRole = "Generic mechanics decide whether current overextension, mandate, core control, contact, war, or economy conditions justify pressure."
  },
  outcomeWeights = {
    collapsePressure = {
      autonomy_increase = 25,
      no_event = 5,
      recovery = 20,
      reform = 20,
      regional_cluster_release = 10,
      single_city_release = 20
    },
    dynasticPressure = {
      claimant_spawn = 20,
      continuity = 25,
      core_inheritance = 20,
      delay = 10,
      reform_or_rename = 25
    },
    expansionPressure = {
      defensive_support = 20,
      economic_support = 15,
      no_event = 10,
      offensive_support = 20,
      settlement_support = 35
    }
  },
  principle = "Historical roles are pressure and opportunity, not scripted destiny. Mechanics must be condition-gated, avoidable through good management, and probabilistic when pressure is high."
}

organic_history_global_lifecycle_archetypes = {
  dynastic_successor = {
    birthProtectionTurns = 15,
    bootstrapPackage = {
      defenders = 3,
      gold = 155,
      offensiveUnits = 2,
      settlers = 2,
      ships = 0,
      workers = 1
    },
    contractionRules = {
      firstEffect = "autonomy_increase",
      minCities = 8,
      sustainedRiskTurns = 10
    },
    description = "Successor identities that should often transform or inherit from predecessors instead of appearing as weak one-city rivals.",
    escapeRoutes = {"predecessor_high_mandate", "predecessor_high_core_control", "peaceful_reform", "strong_defense"},
    outcomeWeights = {
      claimant_spawn = 15,
      continuity = 25,
      core_inheritance = 20,
      delay = 5,
      reform_or_rename = 25,
      regional_split = 10
    },
    successorMode = {"continuity", "reform_or_rename", "core_inheritance", "regional_split", "claimant_spawn", "delay"},
    targetCityCurve = {
      turnsAfterBirth10 = {2, 4},
      turnsAfterBirth30 = {3, 9},
      turnsAfterBirth60 = {5, 15}
    }
  },
  imperial_claimant = {
    birthProtectionTurns = 12,
    bootstrapPackage = {
      defenders = 3,
      gold = 150,
      offensiveUnits = 4,
      settlers = 2,
      ships = 0,
      workers = 1
    },
    contractionRules = {
      firstEffect = "autonomy_increase",
      minCities = 8,
      sustainedRiskTurns = 10
    },
    description = "Expansion-oriented land empires that need enough early agency to reach regional scale before collapse pressure matters.",
    escapeRoutes = {"core_consolidation", "successful_reform", "high_garrison_ratio", "positive_economy"},
    outcomeWeights = {
      claimant_pressure = 20,
      defensive_support = 20,
      delay = 15,
      expansion_support = 35,
      no_event = 10
    },
    successorMode = {"claimant_spawn", "core_inheritance", "regional_split", "delay"},
    targetCityCurve = {
      turnsAfterBirth10 = {2, 4},
      turnsAfterBirth30 = {4, 8},
      turnsAfterBirth60 = {6, 14}
    }
  },
  initial_core = {
    birthProtectionTurns = 0,
    bootstrapPackage = {
      defenders = 0,
      gold = 0,
      settlers = 0,
      ships = 0,
      workers = 0
    },
    contractionRules = {
      firstEffect = "autonomy_increase",
      minCities = 12,
      sustainedRiskTurns = 12
    },
    description = "Original 4000 BCE cores that should face pressure, reform, contraction, and successors rather than simple scripted death.",
    escapeRoutes = {"high_core_control", "high_mandate", "high_cohesion", "positive_economy", "restrained_expansion"},
    outcomeWeights = {
      claimant_spawn = 10,
      continuity = 30,
      no_event = 10,
      reform = 25,
      regional_split = 25
    },
    successorMode = {"continuity", "reform_or_rename", "regional_split", "claimant_spawn"},
    targetCityCurve = {
      turnsAfterBirth10 = {1, 8},
      turnsAfterBirth30 = {2, 16},
      turnsAfterBirth60 = {3, 28}
    }
  },
  island_core = {
    birthProtectionTurns = 20,
    bootstrapPackage = {
      defenders = 2,
      gold = 100,
      offensiveUnits = 0,
      settlers = 2,
      ships = 1,
      workers = 1
    },
    contractionRules = {
      firstEffect = "autonomy_increase",
      minCities = 6,
      sustainedRiskTurns = 12
    },
    description = "Island civilizations that need durable island setup and protection from premature extinction.",
    escapeRoutes = {"island_core_control", "naval_security", "defensive_investment"},
    outcomeWeights = {
      defensive_support = 35,
      naval_support = 20,
      no_event = 20,
      settlement_support = 25
    },
    successorMode = {"continuity", "island_consolidation", "delay"},
    targetCityCurve = {
      turnsAfterBirth10 = {1, 3},
      turnsAfterBirth30 = {2, 5},
      turnsAfterBirth60 = {3, 7}
    }
  },
  maritime_trader = {
    birthProtectionTurns = 12,
    bootstrapPackage = {
      defenders = 3,
      gold = 175,
      offensiveUnits = 1,
      settlers = 3,
      ships = 2,
      workers = 1
    },
    contractionRules = {
      firstEffect = "autonomy_increase",
      minCities = 6,
      sustainedRiskTurns = 10
    },
    description = "Coastal trade and colonial powers that need ships, settlers, and coastal pressure rather than inland empire behavior.",
    escapeRoutes = {"naval_security", "coastal_core_control", "positive_economy", "good_diplomacy"},
    outcomeWeights = {
      claimant_pressure = 15,
      defensive_support = 15,
      no_event = 10,
      ship_settler_support = 35,
      trade_support = 25
    },
    successorMode = {"claimant_spawn", "maritime_colony", "trade_network", "delay"},
    targetCityCurve = {
      turnsAfterBirth10 = {2, 4},
      turnsAfterBirth30 = {3, 7},
      turnsAfterBirth60 = {4, 12}
    }
  },
  nubian_regional_kingdom = {
    birthProtectionTurns = 12,
    bootstrapPackage = {
      defenders = 1,
      gold = 85,
      offensiveUnits = 1,
      settlers = 1,
      ships = 0,
      workers = 1
    },
    contractionRules = {
      clusterPeripheralShare = 0.12,
      clusterRiskThreshold = 0.58,
      debtOverextensionThreshold = 0.12,
      debtPeripheralThreshold = 0.1,
      debtRequired = 3,
      debtThresholdBonus = 0.08,
      firstEffect = "autonomy_increase",
      maxReleaseCities = 2,
      minCities = 8,
      riskThreshold = 0.48,
      sustainedRiskTurns = 6
    },
    description = "Upper Nile regional kingdom that should keep a compact core and shed excess peripheral expansion more readily than generic regional powers.",
    escapeRoutes = {"core_consolidation", "defensive_investment", "good_diplomacy", "positive_economy"},
    outcomeWeights = {
      absorption = 20,
      autonomy = 25,
      no_event = 20,
      regional_pressure = 35
    },
    successorMode = {"claimant_spawn", "regional_consolidation", "delay"},
    targetCityCurve = {
      turnsAfterBirth10 = {1, 3},
      turnsAfterBirth30 = {2, 5},
      turnsAfterBirth60 = {3, 8}
    }
  },
  regional_kingdom = {
    birthProtectionTurns = 12,
    bootstrapPackage = {
      defenders = 1,
      gold = 85,
      offensiveUnits = 1,
      settlers = 1,
      ships = 0,
      workers = 1
    },
    contractionRules = {
      firstEffect = "autonomy_increase",
      minCities = 7,
      sustainedRiskTurns = 10
    },
    description = "Regional powers that should consolidate a local core without necessarily becoming world empires.",
    escapeRoutes = {"core_consolidation", "defensive_investment", "good_diplomacy", "positive_economy"},
    outcomeWeights = {
      defensive_support = 25,
      delay = 15,
      no_event = 10,
      regional_pressure = 20,
      settlement_support = 30
    },
    successorMode = {"claimant_spawn", "regional_consolidation", "delay"},
    targetCityCurve = {
      turnsAfterBirth10 = {1, 3},
      turnsAfterBirth30 = {2, 6},
      turnsAfterBirth60 = {3, 9}
    }
  },
  steppe_conqueror = {
    birthProtectionTurns = 12,
    bootstrapPackage = {
      defenders = 1,
      gold = 150,
      offensiveUnits = 7,
      settlers = 1,
      ships = 0,
      workers = 0
    },
    contractionRules = {
      firstEffect = "autonomy_increase",
      minCities = 8,
      sustainedRiskTurns = 8
    },
    description = "Mobile steppe polities that should get burst potential against rich, fragmented, under-defended neighbors.",
    escapeRoutes = {"neighbor_strong_defense", "poor_steppe_economy", "failed_conquest", "good_diplomacy"},
    outcomeWeights = {
      claimant_pressure = 20,
      delay = 15,
      mobile_army_support = 40,
      no_event = 10,
      regional_split = 15
    },
    successorMode = {"conquest_burst", "regional_split", "delay"},
    targetCityCurve = {
      turnsAfterBirth10 = {1, 3},
      turnsAfterBirth30 = {3, 9},
      turnsAfterBirth60 = {5, 18}
    }
  },
  tribal_horizon = {
    birthProtectionTurns = 10,
    bootstrapPackage = {
      defenders = 1,
      gold = 70,
      offensiveUnits = 1,
      settlers = 1,
      ships = 0,
      workers = 0
    },
    contractionRules = {
      firstEffect = "autonomy_increase",
      minCities = 6,
      sustainedRiskTurns = 8
    },
    description = "Broad cultural/tribal horizons that should exert regional pressure without necessarily becoming durable centralized empires.",
    escapeRoutes = {"regional_autonomy", "good_relations_with_empires", "defensive_terrain"},
    outcomeWeights = {
      absorption = 20,
      autonomy = 25,
      no_event = 20,
      regional_pressure = 35
    },
    successorMode = {"cultural_pressure", "regional_absorption", "delay"},
    targetCityCurve = {
      turnsAfterBirth10 = {1, 4},
      turnsAfterBirth30 = {2, 7},
      turnsAfterBirth60 = {2, 9}
    }
  }
}

organic_history_global_actor_lifecycle_types = {
  abbasid = "dynastic_successor",
  assyria = "imperial_claimant",
  aztec = "regional_kingdom",
  carthage = "maritime_trader",
  castile = "maritime_trader",
  celts = "tribal_horizon",
  china = "initial_core",
  chola = "dynastic_successor",
  egypt = "initial_core",
  franks = "dynastic_successor",
  greece = "regional_kingdom",
  hittite = "imperial_claimant",
  inca = "regional_kingdom",
  india = "initial_core",
  japan = "island_core",
  ming = "dynastic_successor",
  nubia = "nubian_regional_kingdom",
  persia = "imperial_claimant",
  phoenicia = "maritime_trader",
  portugal = "maritime_trader",
  rome = "imperial_claimant",
  song = "dynastic_successor",
  steppe = "steppe_conqueror",
  sumer = "initial_core"
}

organic_history_global_emergence_actors = {
  abbasid = {
    bootstrapPackage = {
      defenders = 3,
      gold = 190,
      offensiveUnits = 2,
      settlers = 3,
      ships = 0,
      workers = 1
    },
    city = "Baghdad",
    core_region = "mesopotamia",
    earliest_turn = 110,
    fallback_regions = {"levant", "iran"},
    gold = 100,
    leader = "Harun al-Rashid",
    nation = "Arab",
    predecessors = {"sumer", "persia"},
    probability = 85,
    style = "Babylonian",
    techs = {"Philosophy", "Mathematics"},
    x = 50,
    y = 43
  },
  assyria = {
    bootstrapPackage = {
      defenders = 2,
      gold = 170,
      offensiveUnits = 4,
      settlers = 1,
      ships = 0,
      workers = 0
    },
    burst = {
      archetype = "near_east_military",
      cooldownTurns = 12,
      durationTurns = 42,
      gold = 45,
      maxApplications = 3,
      offensiveUnits = 3,
      startTurnAfterBirth = 0
    },
    city = "Ashur",
    core_region = "mesopotamia",
    earliest_turn = 38,
    fallback_regions = {"levant", "anatolia", "iran"},
    gold = 95,
    leader = "Ashurbanipal",
    nation = "Assyrian",
    predecessors = {"sumer"},
    style = "Babylonian",
    techs = {"Bronze Working", "Warrior Code"},
    traits = {
      Aggressive = 35,
      Expansionist = 20
    },
    x = 50,
    y = 37
  },
  aztec = {
    city = "Tenochtitlan",
    core_region = "mesoamerica",
    earliest_turn = 160,
    gold = 75,
    leader = "Moctezuma I",
    nation = "Aztec",
    predecessors = {},
    style = "Tropical",
    techs = {"Construction", "Warrior Code"},
    x = 142,
    y = 44
  },
  carthage = {
    city = "Carthage",
    core_region = "maghreb_punic_west",
    earliest_turn = 70,
    gold = 130,
    leader = "Hannibal",
    nation = "Carthaginian",
    predecessors = {"phoenicia"},
    style = "Classical",
    techs = {"Seafaring", "Trade", "Warrior Code"},
    traits = {
      Aggressive = 20,
      Expansionist = 25,
      Trader = 30
    },
    x = 35,
    y = 39
  },
  castile = {
    bootstrapPackage = {
      defenders = 4,
      gold = 190,
      offensiveUnits = 1,
      settlers = 3,
      ships = 1,
      workers = 1
    },
    city = "Toledo",
    core_region = "iberia",
    earliest_turn = 160,
    fallback_regions = {"maghreb_punic_west", "gaul"},
    gold = 150,
    leader = "Isabella",
    nation = "Spanish",
    predecessors = {"rome", "franks"},
    probability = 90,
    style = "European",
    techs = {"Navigation", "Trade"},
    traits = {
      Builder = 10,
      Expansionist = 35,
      Trader = 35
    },
    x = 25,
    y = 32
  },
  celts = {
    city = "Bibracte",
    core_region = "gaul",
    earliest_turn = 75,
    gold = 80,
    leader = "Vercingetorix",
    nation = "Celtic",
    predecessors = {},
    style = "Celtic",
    techs = {"Warrior Code", "Horseback Riding"},
    traits = {
      Aggressive = 25,
      Expansionist = 20
    },
    x = 30,
    y = 28
  },
  chola = {
    city = "Kanchipuram",
    core_region = "deccan_south_india",
    earliest_turn = 115,
    gold = 105,
    leader = "Rajaraja Chola",
    nation = "Chola",
    predecessors = {"india"},
    style = "Classical",
    techs = {"Seafaring", "Trade"},
    traits = {
      Builder = 15,
      Expansionist = 25,
      Trader = 35
    },
    x = 66,
    y = 50
  },
  franks = {
    bootstrapPackage = {
      defenders = 3,
      gold = 170,
      offensiveUnits = 2,
      settlers = 2,
      ships = 0,
      workers = 1
    },
    city = "Aachen",
    core_region = "gaul",
    earliest_turn = 105,
    fallback_regions = {"europe", "italy"},
    gold = 90,
    leader = "Charlemagne",
    nation = "French",
    predecessors = {"rome"},
    probability = 85,
    style = "European",
    techs = {"Monarchy", "Feudalism"},
    x = 30,
    y = 26
  },
  greece = {
    city = "Athens",
    core_region = "balkans_aegean",
    earliest_turn = 40,
    gold = 75,
    leader = "Pericles",
    nation = "Greek",
    predecessors = {},
    style = "Classical",
    techs = {"Alphabet", "Writing"},
    traits = {
      Builder = 10
    },
    x = 41,
    y = 34
  },
  hittite = {
    city = "Hattusa",
    core_region = "anatolia",
    earliest_turn = 42,
    gold = 85,
    leader = "Suppiluliuma",
    nation = "Hittite",
    predecessors = {"sumer"},
    style = "Classical",
    techs = {"Bronze Working", "Horseback Riding"},
    traits = {
      Aggressive = 20,
      Builder = 15
    },
    x = 45,
    y = 34
  },
  inca = {
    city = "Cusco",
    core_region = "andes",
    earliest_turn = 160,
    gold = 75,
    leader = "Pachacuti",
    nation = "Inca",
    predecessors = {},
    style = "Tropical",
    techs = {"Masonry", "Pottery"},
    x = 152,
    y = 62
  },
  japan = {
    city = "Kyoto",
    core_region = "japan_korea",
    earliest_turn = 160,
    gold = 100,
    leader = "Ashikaga Yoshimasa",
    nation = "Japanese",
    predecessors = {},
    style = "Asian",
    techs = {"Feudalism", "Seafaring"},
    x = 95,
    y = 35
  },
  ming = {
    bootstrapPackage = {
      defenders = 3,
      gold = 200,
      offensiveUnits = 3,
      settlers = 2,
      ships = 0,
      workers = 1
    },
    city = "Beijing",
    core_region = "north_china",
    earliest_turn = 160,
    fallback_regions = {"south_china", "japan_korea"},
    gold = 115,
    leader = "Xuande",
    nation = "Manchu",
    predecessors = {"china", "song"},
    probability = 90,
    style = "Asian",
    techs = {"Invention", "Gunpowder"},
    x = 81,
    y = 32
  },
  nubia = {
    city = "Napata",
    core_region = "nile",
    earliest_turn = 35,
    gold = 80,
    leader = "Piye",
    nation = "Nubian",
    predecessors = {"egypt"},
    style = "Classical",
    techs = {"Masonry", "Bronze Working"},
    traits = {
      Aggressive = 10,
      Builder = 15
    },
    x = 42,
    y = 46
  },
  persia = {
    burst = {
      archetype = "iranian_imperial",
      cooldownTurns = 16,
      durationTurns = 45,
      gold = 35,
      maxApplications = 2,
      offensiveUnits = 2,
      startTurnAfterBirth = 0
    },
    city = "Parsa",
    core_region = "iran",
    earliest_turn = 45,
    gold = 100,
    leader = "Cyrus",
    nation = "Persian",
    predecessors = {"sumer"},
    style = "Classical",
    techs = {"Horseback Riding", "Bronze Working", "Trade"},
    traits = {
      Aggressive = 25,
      Builder = 10,
      Expansionist = 30
    },
    x = 56,
    y = 36
  },
  phoenicia = {
    city = "Tyre",
    core_region = "levant",
    earliest_turn = 50,
    gold = 90,
    leader = "Hiram",
    nation = "Phoenician",
    predecessors = {"sumer", "egypt"},
    style = "Classical",
    techs = {"Seafaring", "Trade"},
    traits = {
      Expansionist = 15,
      Trader = 35
    },
    x = 46,
    y = 39
  },
  portugal = {
    bootstrapPackage = {
      defenders = 3,
      gold = 200,
      offensiveUnits = 1,
      settlers = 3,
      ships = 3,
      workers = 1
    },
    city = "Lisbon",
    core_region = "iberia",
    earliest_turn = 160,
    fallback_regions = {"maghreb_punic_west", "gaul", "africa"},
    gold = 150,
    leader = "Henry",
    nation = "Portuguese",
    predecessors = {"rome", "franks"},
    probability = 90,
    style = "European",
    techs = {"Seafaring", "Navigation"},
    traits = {
      Builder = 10,
      Expansionist = 40,
      Trader = 40
    },
    x = 23,
    y = 35
  },
  rome = {
    burst = {
      archetype = "mediterranean_imperial",
      cooldownTurns = 16,
      durationTurns = 80,
      gold = 55,
      maxApplications = 3,
      offensiveUnits = 3,
      startTurnAfterBirth = 0
    },
    city = "Roma",
    core_region = "italy",
    earliest_turn = 55,
    fallback_regions = {"balkans_aegean", "gaul"},
    gold = 100,
    leader = "Romulus",
    nation = "Roman",
    predecessors = {"greece"},
    style = "Classical",
    techs = {"Warrior Code", "Bronze Working", "Trade"},
    traits = {
      Aggressive = 30,
      Builder = 10,
      Expansionist = 50
    },
    x = 35,
    y = 32
  },
  song = {
    bootstrapPackage = {
      defenders = 3,
      gold = 180,
      offensiveUnits = 2,
      settlers = 2,
      ships = 0,
      workers = 1
    },
    city = "Kaifeng",
    core_region = "north_china",
    earliest_turn = 115,
    fallback_regions = {"south_china"},
    gold = 135,
    leader = "Taizu",
    nation = "Korean",
    predecessors = {"china"},
    probability = 85,
    style = "Asian",
    techs = {"Invention", "Gunpowder", "Trade"},
    traits = {
      Builder = 35,
      Expansionist = 20,
      Trader = 15
    },
    x = 79,
    y = 35
  },
  steppe = {
    burst = {
      archetype = "steppe_conquest",
      cooldownTurns = 12,
      durationTurns = 70,
      gold = 45,
      maxApplications = 4,
      offensiveUnits = 4,
      startTurnAfterBirth = 0
    },
    city = "Karakorum",
    core_region = "steppe_mongolia",
    earliest_turn = 125,
    fallback_regions = {"steppe", "north_china"},
    gold = 115,
    leader = "Temujin",
    nation = "Mongol",
    predecessors = {},
    probability = 85,
    style = "Asian",
    techs = {"Horseback Riding", "Warrior Code"},
    traits = {
      Aggressive = 55,
      Expansionist = 45
    },
    x = 82,
    y = 24
  }
}
-- END GENERATED GLOBAL HISTORY DATA

organic_history_scenario_metadata_active_cache = nil
organic_history_scenario_metadata_match_cache = nil
organic_history_global_scenario_metadata_active_cache = nil
organic_history_global_scenario_metadata_match_cache = nil
organic_history_map_dimensions_cache = nil

function organic_history_map_dimensions()
  if organic_history_map_dimensions_cache ~= nil then
    return organic_history_map_dimensions_cache
  end

  local max_x = 0
  local max_y = 0

  for tile in whole_map_iterate() do
    if tile.x > max_x then
      max_x = tile.x
    end
    if tile.y > max_y then
      max_y = tile.y
    end
  end

  organic_history_map_dimensions_cache = {width = max_x + 1, height = max_y + 1}
  return organic_history_map_dimensions_cache
end

function organic_history_global_scenario_metadata_active()
  if organic_history_global_scenario_metadata_active_cache ~= nil then
    return organic_history_global_scenario_metadata_active_cache
  end
  if organic_history_global_scenario_city_metadata == nil then
    organic_history_global_scenario_metadata_active_cache = false
    organic_history_global_scenario_metadata_match_cache = 0
    return false
  end

  local matches = 0

  for player in players_iterate() do
    for city in player:cities_iterate() do
      local metadata = organic_history_global_scenario_city_metadata[city.name]

      if city.tile ~= nil and metadata ~= nil and metadata.x ~= nil
         and metadata.y ~= nil and city.tile.x == metadata.x
         and city.tile.y == metadata.y then
        matches = matches + 1
      end
    end
  end

  organic_history_global_scenario_metadata_match_cache = matches
  organic_history_global_scenario_metadata_active_cache = matches >= 3
  return organic_history_global_scenario_metadata_active_cache
end

function organic_history_large_earth_active()
  local dimensions = organic_history_map_dimensions()

  return dimensions.width > 100 or dimensions.height > 60
         or organic_history_global_scenario_metadata_active()
end

function organic_history_active_regions()
  if organic_history_large_earth_active()
     and organic_history_global_scenario_regions ~= nil then
    return organic_history_global_scenario_regions
  end

  if organic_history_large_earth_active() then
    return organic_history_scenario_regions_large
  end

  return organic_history_scenario_regions
end

function organic_history_active_region_order()
  if organic_history_large_earth_active()
     and organic_history_global_scenario_region_order ~= nil then
    return organic_history_global_scenario_region_order
  end

  return organic_history_scenario_region_order
end

function organic_history_active_city_metadata()
  if organic_history_large_earth_active()
     and organic_history_global_scenario_city_metadata ~= nil then
    return organic_history_global_scenario_city_metadata
  elseif organic_history_large_earth_active() then
    return organic_history_scenario_city_metadata_large
  end

  return organic_history_scenario_city_metadata
end

function organic_history_active_actor_metadata()
  if organic_history_large_earth_active()
     and organic_history_global_scenario_actor_metadata ~= nil then
    return organic_history_global_scenario_actor_metadata
  end

  return organic_history_scenario_actor_metadata
end

function organic_history_active_actor_region_claims()
  if organic_history_large_earth_active()
     and organic_history_global_actor_region_claims ~= nil then
    return organic_history_global_actor_region_claims
  end

  return organic_history_actor_region_claims
end

function organic_history_active_emergence_actors()
  if organic_history_large_earth_active()
     and organic_history_global_emergence_actors ~= nil then
    return organic_history_global_emergence_actors
  end

  return organic_history_emergence_actors
end

function organic_history_active_actor_flavor_diagnostics()
  if organic_history_large_earth_active()
     and organic_history_global_actor_flavor_diagnostics ~= nil then
    return organic_history_global_actor_flavor_diagnostics
  end

  return {}
end

function organic_history_active_actor_objectives()
  if organic_history_large_earth_active()
     and organic_history_global_actor_objectives ~= nil then
    return organic_history_global_actor_objectives
  end

  return {}
end

function organic_history_active_actor_lifecycle_types()
  if organic_history_large_earth_active()
     and organic_history_global_actor_lifecycle_types ~= nil then
    return organic_history_global_actor_lifecycle_types
  end

  return {}
end

function organic_history_active_lifecycle_archetypes()
  if organic_history_large_earth_active()
     and organic_history_global_lifecycle_archetypes ~= nil then
    return organic_history_global_lifecycle_archetypes
  end

  return {}
end

function organic_history_region_for_tile(tile)
  if tile == nil then
    return "unknown", "Unknown"
  end

  for _, region_id in ipairs(organic_history_active_region_order()) do
    local region = organic_history_active_regions()[region_id]
    if region ~= nil
       and tile.x >= region.x_min and tile.x <= region.x_max
       and tile.y >= region.y_min and tile.y <= region.y_max then
      return region_id, region.name
    end
  end

  return "unknown", "Unknown"
end

function organic_history_region_name(region_id)
  local region = organic_history_active_regions()[region_id]

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

  local metadata = organic_history_active_city_metadata()[city.name]

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

  for actor_id, metadata in pairs(organic_history_active_actor_metadata()) do
    if metadata.leader == player_name and metadata.nation == nation then
      return metadata, actor_id
    end
  end

  for actor_id, metadata in pairs(organic_history_active_actor_metadata()) do
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
      local metadata = organic_history_active_city_metadata()[city.name]

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

function organic_history_actor_exists(actor)
  local player = organic_history_find_actor_player(actor)

  return player ~= nil and player:num_cities() > 0
end

function organic_history_emergence_region_context(actor_id, actor)
  local region_id = actor.core_region or "unknown"
  local holders = {}
  local total = 0
  local leader = nil
  local leader_cities = 0

  for player in players_iterate() do
    if player.is_alive then
      local player_id = organic_history_player_id(player)
      for city in player:cities_iterate() do
        local city_region = organic_history_region_for_city(city)
        if city_region == region_id then
          holders[player_id] = (holders[player_id] or 0) + 1
          total = total + 1
          if holders[player_id] > leader_cities then
            leader = player
            leader_cities = holders[player_id]
          end
        end
      end
    end
  end

  local leader_share = 0
  local leader_actor = "none"
  if total > 0 and leader ~= nil then
    leader_share = leader_cities / total
    local _, detected_actor_id = organic_history_actor_metadata_for(leader)
    if detected_actor_id ~= nil then
      leader_actor = detected_actor_id
    end
  end

  return {
    region_id = region_id,
    total = total,
    leader = leader,
    leader_share = leader_share,
    leader_actor = leader_actor
  }
end

function organic_history_actor_in_lineage(actor_id, actor, candidate_actor_id)
  if candidate_actor_id == nil or candidate_actor_id == "none" then
    return false
  elseif candidate_actor_id == actor_id then
    return true
  end

  for _, predecessor_id in ipairs(actor.predecessors or {}) do
    if predecessor_id == candidate_actor_id then
      return true
    end
  end

  return false
end

function organic_history_actor_uses_dynastic_transfer(actor_id, actor)
  local lifecycle_type = organic_history_active_actor_lifecycle_types()[actor_id]

  if lifecycle_type == "dynastic_successor" then
    return true
  end

  return organic_history_iberian_successor_transfer_enabled
      and actor ~= nil
      and actor.core_region == "iberia"
      and actor.predecessors ~= nil
      and #actor.predecessors > 0
end

function organic_history_player_weak_for_emergence(player)
  if player == nil then
    return false
  end

  local player_id = organic_history_player_id(player)
  local state = organic_history_state_capacity[player_id] or {}
  local mandate = organic_history_mandates[player_id] or {}
  local crisis = state.crisis or 0
  local mandate_score = mandate.mandate or state.mandate or 1

  return crisis >= organic_history_emergence_weak_holder_crisis_threshold
         or mandate_score < organic_history_mandate_loss_threshold
end

function organic_history_emergence_mode(actor_id, actor, context)
  if not organic_history_emergence_conditional_enabled then
    return "legacy", false
  elseif context.total <= 0 then
    return "empty_core", false
  elseif organic_history_actor_in_lineage(actor_id, actor, context.leader_actor) then
    return "lineage_successor", false
  elseif organic_history_player_weak_for_emergence(context.leader) then
    return "weak_holder", true
  end

  return "foreign_core_claimant", false
end

function organic_history_can_create_city_for_player(player, tile)
  if player ~= nil and edit.can_create_city ~= nil then
    return edit.can_create_city(player, tile)
  end

  return organic_history_tile_can_host_emergence_city(tile)
end

function organic_history_append_emergence_candidate(candidates, seen, tile,
                                                    player)
  if tile == nil or tile:city() ~= nil or seen[tile.id]
     or not organic_history_can_create_city_for_player(player, tile) then
    return
  end

  seen[tile.id] = true
  table.insert(candidates, tile)
end

function organic_history_tile_can_host_emergence_city(tile)
  if tile == nil or tile.terrain == nil then
    return false
  end

  local terrain = organic_history_rule_name(tile.terrain)
  return terrain ~= "Ocean"
         and terrain ~= "Deep Ocean"
         and terrain ~= "Lake"
         and terrain ~= "Glacier"
end

function organic_history_emergence_candidate_limit()
  return 512
end

function organic_history_append_region_emergence_candidates(candidates, seen,
                                                           region_id,
                                                           player)
  local region = organic_history_active_regions()[region_id]

  if region == nil then
    return
  end

  local center_x = math.floor((region.x_min + region.x_max) / 2)
  local center_y = math.floor((region.y_min + region.y_max) / 2)
  local center = find.tile(center_x, center_y)
  local radius_limit = math.max(region.x_max - region.x_min,
                                region.y_max - region.y_min) + 6

  if center == nil then
    return
  end

  organic_history_append_emergence_candidate(candidates, seen, center, player)
  for radius = 1, radius_limit do
    for candidate in center:circle_iterate(radius) do
      local candidate_region = organic_history_region_for_tile(candidate)

      if candidate_region == region_id then
        organic_history_append_emergence_candidate(candidates, seen, candidate,
                                                  player)
        if #candidates >= organic_history_emergence_candidate_limit() then
          return
        end
      end
    end
  end
end

function organic_history_emergence_candidate_tiles(actor, player)
  local candidates = {}
  local seen = {}
  local tile = find.tile(actor.x, actor.y)

  if tile == nil then
    return candidates, "missing_tile"
  end

  organic_history_append_emergence_candidate(candidates, seen, tile, player)
  if not organic_history_emergence_conditional_enabled then
    return candidates, #candidates > 0 and "target_tile" or "occupied_tile"
  end

  for radius = 1, organic_history_emergence_relocation_radius do
    for candidate in tile:circle_iterate(radius) do
      local region_id = organic_history_region_for_tile(candidate)
      if candidate.id ~= tile.id and region_id == actor.core_region then
        organic_history_append_emergence_candidate(candidates, seen, candidate,
                                                  player)
        if #candidates >= organic_history_emergence_candidate_limit() then
          return candidates, "candidate_sites"
        end
      end
    end
  end

  for _, fallback_region in ipairs(actor.fallback_regions or {}) do
    organic_history_append_region_emergence_candidates(candidates, seen,
                                                      fallback_region,
                                                      player)
    if #candidates >= organic_history_emergence_candidate_limit() then
      return candidates, "fallback_sites"
    end
  end

  if #candidates > 0 then
    return candidates, "candidate_sites"
  end

  return candidates, "occupied_tile_no_site"
end

function organic_history_sumer_urbanization_log(turn, action, reason, extra)
  log.normal('organic_history_urbanization turn=%d actor="sumer" action=%q reason=%q %s',
             turn, action, reason, extra or "")
end

function organic_history_sumer_urbanization_city_count(player)
  if player == nil then
    return 0
  end

  return player:num_cities()
end

function organic_history_sumer_urbanization_candidates(player)
  local candidates = {}
  local seen = {}
  local specs = {
    {50, 43, "Akkad"},
    {53, 43, "Lagash"},
    {54, 41, "Nippur"},
    {49, 42, "Eridu"},
    {51, 41, "Kish"}
  }

  for _, spec in ipairs(specs) do
    local tile = find.tile(spec[1], spec[2])
    local region_id = organic_history_region_for_tile(tile)

    if tile ~= nil and not seen[tile.id] and tile:city() == nil
       and region_id == "mesopotamia"
       and organic_history_tile_can_host_emergence_city(tile) then
      table.insert(candidates, {tile = tile, name = spec[3]})
      seen[tile.id] = true
    end
  end

  if player ~= nil then
    for city in player:cities_iterate() do
      if organic_history_region_for_city(city) == "mesopotamia" then
        for radius = 1, 8 do
          for tile in city.tile:circle_iterate(radius) do
            local region_id = organic_history_region_for_tile(tile)

            if not seen[tile.id] and tile:city() == nil
               and region_id == "mesopotamia"
               and organic_history_tile_can_host_emergence_city(tile) then
              table.insert(candidates, {
                tile = tile,
                name = "Sumerian Quarter " .. tostring(#candidates + 1)
              })
              seen[tile.id] = true
              if #candidates >= 8 then
                return candidates
              end
            end
          end
        end
      end
    end
  end

  return candidates
end

function organic_history_check_sumer_urbanization(turn)
  if not (organic_history_mechanics_enabled
          and organic_history_sumer_urbanization_enabled
          and organic_history_large_earth_active()) then
    return
  end

  local player = organic_history_player_for_actor_id("sumer")
  local cities = organic_history_sumer_urbanization_city_count(player)
  local target = organic_history_sumer_urbanization_target_cities or 3
  local max_created = organic_history_sumer_urbanization_max_cities or 2
  local cooldown = organic_history_sumer_urbanization_cooldown or 20
  local created_so_far = organic_history_sumer_urbanization_created or 0
  local extra = "cities=" .. cities
      .. " target_cities=" .. target
      .. " created_so_far=" .. created_so_far
      .. " max_created=" .. max_created
      .. " cooldown=" .. cooldown
      .. " applied=false"

  if player == nil or not player.is_alive then
    organic_history_sumer_urbanization_log(turn, "skip", "missing_sumer",
                                           extra)
    return
  elseif cities >= target then
    organic_history_sumer_urbanization_log(turn, "protected", "on_target",
                                           extra)
    return
  elseif created_so_far >= max_created then
    organic_history_sumer_urbanization_log(turn, "protected", "city_cap",
                                           extra)
    return
  elseif turn < organic_history_sumer_urbanization_last_turn + cooldown then
    organic_history_sumer_urbanization_log(
        turn, "protected", "cooldown",
        extra .. " cooldown_until="
        .. (organic_history_sumer_urbanization_last_turn + cooldown))
    return
  end

  local candidates = organic_history_sumer_urbanization_candidates(player)
  if #candidates <= 0 then
    organic_history_sumer_urbanization_log(turn, "noop", "missing_site",
                                           extra)
    return
  end

  local candidate = candidates[1]
  local ok = edit.city_create(player, candidate.tile, candidate.name, nil)
  if not ok then
    organic_history_sumer_urbanization_log(
        turn, "noop", "city_create_failed",
        extra .. " candidate_city=" .. string.format("%q", candidate.name)
        .. " x=" .. candidate.tile.x .. " y=" .. candidate.tile.y)
    return
  end

  organic_history_sumer_urbanization_created = created_so_far + 1
  organic_history_sumer_urbanization_last_turn = turn
  organic_history_sumer_urbanization_log(
      turn, "created", "mesopotamian_city_density",
      string.gsub(extra, " applied=false", " applied=true")
      .. " candidate_city=" .. string.format("%q", candidate.name)
      .. " x=" .. candidate.tile.x .. " y=" .. candidate.tile.y
      .. " created=1")
end

function organic_history_find_actor_player(actor)
  for player in players_iterate() do
    if organic_history_player_name(player) == actor.leader
       and organic_history_rule_name(player.nation) == actor.nation then
      return player
    end
  end

  return nil
end

function organic_history_give_emergence_setup(player, actor)
  local gold_delta = (actor.gold or 50) - player:gold()

  if gold_delta ~= 0 then
    edit.change_gold(player, gold_delta)
  end

  if actor.techs ~= nil then
    for _, tech_name in ipairs(actor.techs) do
      local tech = find.tech_type(tech_name)

      if tech ~= nil then
        edit.give_tech(player, tech, 0, false, "organic_history_emergence")
      end
    end
  end

  if actor.traits ~= nil then
    for trait_name, trait_mod in pairs(actor.traits) do
      edit.trait_mod(player, trait_name, trait_mod)
    end
  end
end

function organic_history_actor_lifecycle(actor_id)
  local lifecycle_type = organic_history_active_actor_lifecycle_types()[actor_id]
  if lifecycle_type == nil then
    return nil, nil
  end

  return lifecycle_type, organic_history_active_lifecycle_archetypes()[lifecycle_type]
end

function organic_history_bootstrap_package(actor_id)
  local lifecycle_type, lifecycle = organic_history_actor_lifecycle(actor_id)
  if lifecycle == nil then
    return lifecycle_type, nil
  end

  return lifecycle_type, lifecycle.bootstrapPackage
end

function organic_history_find_city_at_tile(player, tile)
  if player == nil or tile == nil then
    return nil
  end

  for city in player:cities_iterate() do
    if city.tile ~= nil and city.tile.id == tile.id then
      return city
    end
  end

  return nil
end

function organic_history_bootstrap_find_unit_type(player, roles)
  for _, role in ipairs(roles) do
    local unit_type = find.role_unit_type(role, player)

    if unit_type ~= nil then
      return unit_type, role
    end
  end

  return nil, nil
end

function organic_history_bootstrap_unit_tiles(tile, unit_type, min_radius,
                                              max_radius)
  local candidates = {}
  local seen = {}
  local first_radius = min_radius or 0
  local last_radius = max_radius or 2

  if first_radius <= 0 and tile ~= nil and unit_type ~= nil
     and unit_type:can_exist_at_tile(tile) then
    candidates[#candidates + 1] = tile
    seen[tile.id] = true
  end

  if tile ~= nil and unit_type ~= nil then
    for radius = math.max(1, first_radius), last_radius do
      for candidate in tile:circle_iterate(radius) do
        if not seen[candidate.id] and unit_type:can_exist_at_tile(candidate) then
          candidates[#candidates + 1] = candidate
          seen[candidate.id] = true
        end
      end
    end
  end

  return candidates
end

function organic_history_bootstrap_create_units(player, homecity, tile, count,
                                                roles, min_radius, max_radius)
  if count == nil or count <= 0 then
    return 0, 0, "none", "none"
  end

  local unit_type, role = organic_history_bootstrap_find_unit_type(player, roles)
  if unit_type == nil then
    return 0, count, "none", "missing_unit_type"
  end

  local candidates = organic_history_bootstrap_unit_tiles(tile, unit_type,
                                                         min_radius,
                                                         max_radius)
  if #candidates <= 0 then
    return 0, count, organic_history_rule_name(unit_type), "missing_unit_tile"
  end

  local created = 0
  for i = 1, count do
    local target = candidates[((i - 1) % #candidates) + 1]
    local unit = player:create_unit(target, unit_type, 0, homecity, -1)

    if unit ~= nil then
      created = created + 1
    end
  end

  return created, count - created, organic_history_rule_name(unit_type), role
end

function organic_history_settler_conversion_log(turn, actor_id, action,
                                                reason, extra)
  log.normal('organic_history_settler_conversion turn=%d actor=%q action=%q reason=%q %s',
             turn, actor_id, action, reason, extra or "")
end

function organic_history_track_settler_conversion(turn, actor_id, player,
                                                  source, created_settlers,
                                                  skipped_settlers)
  if created_settlers == nil or created_settlers <= 0 or player == nil then
    return
  end

  local id = organic_history_settler_conversion_next_id
  organic_history_settler_conversion_next_id = id + 1
  organic_history_settler_conversion_tracking[id] = {
    actor_id = actor_id,
    player_id = organic_history_player_id(player),
    source = source,
    start_turn = turn,
    initial_cities = player:num_cities(),
    max_cities = player:num_cities(),
    created_settlers = created_settlers,
    skipped_settlers = skipped_settlers or 0
  }

  organic_history_settler_conversion_log(
      turn, actor_id, "tracking", "settlers_created",
      "id=" .. id
      .. " source=" .. string.format("%q", source)
      .. " player=" .. organic_history_player_id(player)
      .. " initial_cities=" .. player:num_cities()
      .. " created_settlers=" .. created_settlers
      .. " skipped_settlers=" .. (skipped_settlers or 0))
end

function organic_history_check_settler_conversions(turn)
  local observation_turns = 30

  for id, entry in pairs(organic_history_settler_conversion_tracking) do
    local player = organic_history_player_for_actor_id(entry.actor_id)
    if player == nil or not player.is_alive then
      organic_history_settler_conversion_log(
          turn, entry.actor_id, "resolved", "actor_lost",
          "id=" .. id
          .. " source=" .. string.format("%q", entry.source)
          .. " start_turn=" .. entry.start_turn
          .. " age=" .. (turn - entry.start_turn)
          .. " initial_cities=" .. entry.initial_cities
          .. " current_cities=0"
          .. " max_cities=" .. entry.max_cities
          .. " created_settlers=" .. entry.created_settlers
          .. " skipped_settlers=" .. entry.skipped_settlers)
      organic_history_settler_conversion_tracking[id] = nil
    else
      local current_cities = player:num_cities()
      if current_cities > entry.max_cities then
        entry.max_cities = current_cities
      end

      if turn >= entry.start_turn + observation_turns then
        local city_gain = current_cities - entry.initial_cities
        local peak_gain = entry.max_cities - entry.initial_cities
        local reason = "no_city_gain"
        if city_gain > 0 then
          reason = "city_gain"
        elseif peak_gain > 0 then
          reason = "city_gain_lost"
        end

        organic_history_settler_conversion_log(
            turn, entry.actor_id, "resolved", reason,
            "id=" .. id
            .. " source=" .. string.format("%q", entry.source)
            .. " start_turn=" .. entry.start_turn
            .. " age=" .. (turn - entry.start_turn)
            .. " initial_cities=" .. entry.initial_cities
            .. " current_cities=" .. current_cities
            .. " max_cities=" .. entry.max_cities
            .. " city_gain=" .. city_gain
            .. " peak_city_gain=" .. peak_gain
            .. " created_settlers=" .. entry.created_settlers
            .. " skipped_settlers=" .. entry.skipped_settlers)
        organic_history_settler_conversion_tracking[id] = nil
      end
    end
  end
end

function organic_history_bootstrap_take(requested, remaining)
  if requested == nil or requested <= 0 or remaining <= 0 then
    return 0, remaining
  end

  local allowed = math.min(math.floor(requested), remaining)

  return allowed, remaining - allowed
end

function organic_history_count_known_techs(player)
  local count = 0
  if player == nil then
    return 0
  end
  for i = 0, organic_history_tech_floor_iteration_cap - 1 do
    local tech = find.tech_type(i)
    if tech == nil then
      break
    end
    if player:knows_tech(tech) then
      count = count + 1
    end
  end
  return count
end

function organic_history_alive_player_tech_counts(skip_player)
  local counts = {}
  for player in players_iterate() do
    if player ~= skip_player and player.is_alive
       and player:num_cities() > 0 then
      table.insert(counts, organic_history_count_known_techs(player))
    end
  end
  return counts
end

function organic_history_integer_median(values)
  local n = #values
  if n == 0 then
    return 0
  end
  local sorted = {}
  for i = 1, n do
    sorted[i] = values[i]
  end
  table.sort(sorted)
  if n % 2 == 1 then
    return sorted[(n + 1) / 2]
  end
  local lo = sorted[n / 2]
  local hi = sorted[n / 2 + 1]
  return math.floor((lo + hi) / 2)
end

function organic_history_tech_popularity(skip_player)
  local techs = {}
  local pop = {}
  for i = 0, organic_history_tech_floor_iteration_cap - 1 do
    local tech = find.tech_type(i)
    if tech == nil then
      break
    end
    table.insert(techs, tech)
    pop[tech.id] = 0
  end
  for player in players_iterate() do
    if player ~= skip_player and player.is_alive
       and player:num_cities() > 0 then
      for _, tech in ipairs(techs) do
        if player:knows_tech(tech) then
          pop[tech.id] = pop[tech.id] + 1
        end
      end
    end
  end
  return techs, pop
end

function organic_history_tech_floor_delta_for(actor, archetype)
  local delta = organic_history_tech_floor_delta
  if archetype ~= nil and archetype.techFloor ~= nil
     and archetype.techFloor.delta ~= nil then
    delta = archetype.techFloor.delta
  end
  if actor ~= nil and actor.techFloor ~= nil
     and actor.techFloor.delta ~= nil then
    delta = actor.techFloor.delta
  end
  return delta
end

function organic_history_tech_floor_max_grant_for(actor, archetype)
  local cap = organic_history_tech_floor_max_techs
  if archetype ~= nil and archetype.techFloor ~= nil
     and archetype.techFloor.maxGrant ~= nil then
    cap = archetype.techFloor.maxGrant
  end
  if actor ~= nil and actor.techFloor ~= nil
     and actor.techFloor.maxGrant ~= nil then
    cap = actor.techFloor.maxGrant
  end
  return cap
end

function organic_history_apply_tech_floor(actor_id, player, actor, turn, reason)
  if not organic_history_tech_floor_enabled then
    return
  end
  if organic_history_tech_floor_applied[actor_id] ~= nil then
    return
  end
  if player == nil or not player.is_alive then
    log.normal('organic_history_tech_floor turn=%d actor=%q reason=%q applied=false skip_reason="player_unavailable"',
               turn, actor_id, reason or "unknown")
    return
  end

  local lifecycle_type, archetype = organic_history_actor_lifecycle(actor_id)
  local delta = organic_history_tech_floor_delta_for(actor, archetype)
  local max_grant = organic_history_tech_floor_max_grant_for(actor, archetype)
  local counts = organic_history_alive_player_tech_counts(player)
  local peers = #counts
  local median = organic_history_integer_median(counts)
  local actor_known = organic_history_count_known_techs(player)

  if peers < organic_history_tech_floor_min_alive_peers then
    log.normal('organic_history_tech_floor turn=%d actor=%q reason=%q applied=false skip_reason="not_enough_peers" lifecycle_type=%q median=%d delta=%d target=0 actor_known=%d peers=%d',
               turn, actor_id, reason or "unknown",
               lifecycle_type or "unknown", median, delta, actor_known, peers)
    organic_history_tech_floor_applied[actor_id] = turn
    return
  end

  local target = median - delta
  if target < 0 then
    target = 0
  end

  if actor_known >= target then
    log.normal('organic_history_tech_floor turn=%d actor=%q reason=%q applied=false skip_reason="already_above_floor" lifecycle_type=%q median=%d delta=%d target=%d actor_known=%d peers=%d',
               turn, actor_id, reason or "unknown",
               lifecycle_type or "unknown", median, delta, target,
               actor_known, peers)
    organic_history_tech_floor_applied[actor_id] = turn
    return
  end

  local techs, pop = organic_history_tech_popularity(player)
  local candidates = {}
  for _, tech in ipairs(techs) do
    if not player:knows_tech(tech)
       and (pop[tech.id] or 0) >= organic_history_tech_floor_min_popularity then
      table.insert(candidates,
                   {tech = tech, count = pop[tech.id]})
    end
  end
  table.sort(candidates, function(a, b)
    if a.count == b.count then
      return a.tech:rule_name() < b.tech:rule_name()
    end
    return a.count > b.count
  end)

  local needed = target - actor_known
  local granted = 0
  local attempted = 0
  for _, entry in ipairs(candidates) do
    if granted >= needed or granted >= max_grant then
      break
    end
    attempted = attempted + 1
    if player:give_tech(entry.tech, 0, false, "organic_history_tech_floor") then
      granted = granted + 1
    end
  end

  organic_history_tech_floor_applied[actor_id] = turn
  log.normal('organic_history_tech_floor turn=%d actor=%q reason=%q applied=true lifecycle_type=%q median=%d delta=%d target=%d actor_known_before=%d granted=%d attempted=%d candidates=%d max_grant=%d peers=%d',
             turn, actor_id, reason or "unknown",
             lifecycle_type or "unknown", median, delta, target, actor_known,
             granted, attempted, #candidates, max_grant, peers)
end

function organic_history_apply_bootstrap(actor_id, player, actor, tile, turn)
  if not organic_history_bootstrap_enabled then
    return
  end
  if organic_history_bootstrap_applied[actor_id] ~= nil then
    return
  end

  local lifecycle_type, package = organic_history_bootstrap_package(actor_id)
  if actor.bootstrapPackage ~= nil then
    package = actor.bootstrapPackage
  end
  if package == nil then
    log.normal('organic_history_bootstrap turn=%d actor=%q applied=false reason="missing_package"',
               turn, actor_id)
    return
  end

  local homecity = organic_history_find_city_at_tile(player, tile)
  local gold = math.min(math.floor(package.gold or 0),
                        organic_history_bootstrap_max_gold)
  local remaining_units = organic_history_bootstrap_max_units
  local defenders, offensive, settlers, workers, ships = 0, 0, 0, 0, 0
  defenders, remaining_units =
      organic_history_bootstrap_take(package.defenders, remaining_units)
  offensive, remaining_units =
      organic_history_bootstrap_take(package.offensiveUnits, remaining_units)
  settlers, remaining_units =
      organic_history_bootstrap_take(package.settlers, remaining_units)
  workers, remaining_units =
      organic_history_bootstrap_take(package.workers, remaining_units)
  ships, remaining_units =
      organic_history_bootstrap_take(package.ships, remaining_units)

  if gold > 0 then
    edit.change_gold(player, gold)
  end

  local created_defenders, skipped_defenders =
      organic_history_bootstrap_create_units(
          player, homecity, tile, defenders,
          {"DefendGoodStartUnit", "DefendGood", "DefendOkStartUnit",
           "DefendOk", "FirstBuild"})
  local created_offensive, skipped_offensive =
      organic_history_bootstrap_create_units(
          player, homecity, tile, offensive,
          {"AttackStrongStartUnit", "AttackFastStartUnit", "Hut",
           "FirstBuild"})
  local created_settlers, skipped_settlers =
      organic_history_bootstrap_create_units(
          player, homecity, tile, settlers,
          {"Cities", "Settlers", "CitiesStartUnit"}, 3, 5)
  local created_workers, skipped_workers =
      organic_history_bootstrap_create_units(
          player, homecity, tile, workers,
          {"WorkerStartUnit"})
  local created_ships, skipped_ships =
      organic_history_bootstrap_create_units(
          player, homecity, tile, ships,
          {"Ferryboat", "FerryStartUnit"})
  local skipped = skipped_defenders + skipped_offensive + skipped_settlers
                  + skipped_workers + skipped_ships

  organic_history_bootstrap_applied[actor_id] = turn
  log.normal('organic_history_bootstrap turn=%d actor=%q lifecycle_type=%q applied=true gold=%d defenders=%d offensive=%d settlers=%d workers=%d ships=%d skipped_units=%d city=%q x=%d y=%d',
             turn, actor_id, lifecycle_type or "unknown", gold,
             created_defenders, created_offensive, created_settlers,
             created_workers, created_ships, skipped, actor.city,
             tile.x, tile.y)
  organic_history_track_settler_conversion(turn, actor_id, player,
                                           "bootstrap",
                                           created_settlers,
                                           skipped_settlers)
end

function organic_history_iberian_successor_diagnostic(turn, actor_id, context)
  if actor_id ~= "castile" and actor_id ~= "portugal" then
    return
  end

  local castile_player = organic_history_player_for_actor_id("castile")
  local portugal_player = organic_history_player_for_actor_id("portugal")
  local castile_cities = 0
  local portugal_cities = 0

  if castile_player ~= nil then
    castile_cities = castile_player:num_cities()
  end
  if portugal_player ~= nil then
    portugal_cities = portugal_player:num_cities()
  end

  local other_present = false
  if actor_id == "castile" then
    other_present = portugal_cities > 0
  else
    other_present = castile_cities > 0
  end

  log.normal('organic_history_iberian_successor turn=%d actor=%q castile_cities=%d portugal_cities=%d other_successor_present=%s core_region=%q total_core_cities=%d leader_actor=%q leader_share=%.3f',
             turn, actor_id, castile_cities, portugal_cities,
             tostring(other_present), context.region_id, context.total,
             context.leader_actor, context.leader_share)
end

function organic_history_count_map_string(counts)
  local values = {}

  for key, value in pairs(counts or {}) do
    table.insert(values, tostring(key) .. ":" .. tostring(value))
  end
  table.sort(values)

  return table.concat(values, "|")
end

function organic_history_city_site_pool_counts(player, region_id)
  local counts = {
    checked = 0,
    city_occupied = 0,
    unit_occupied = 0,
    terrain_blocked = 0,
    empty_sites = 0,
    legal_sites = 0,
    illegal_sites = 0,
    holders = {}
  }
  local region = organic_history_active_regions()[region_id]

  if region == nil then
    return counts
  end

  for x = region.x_min, region.x_max do
    for y = region.y_min, region.y_max do
      local tile = find.tile(x, y)

      if tile ~= nil then
        counts.checked = counts.checked + 1
        local city = tile:city()
        if city ~= nil then
          counts.city_occupied = counts.city_occupied + 1
          local _, holder_actor_id =
              organic_history_actor_metadata_for(city.owner)
          local holder = holder_actor_id or organic_history_player_name(
              city.owner)
          counts.holders[holder] = (counts.holders[holder] or 0) + 1
        elseif not organic_history_tile_can_host_emergence_city(tile) then
          counts.terrain_blocked = counts.terrain_blocked + 1
        else
          counts.empty_sites = counts.empty_sites + 1
          if tile:num_units() > 0 then
            counts.unit_occupied = counts.unit_occupied + 1
          end
          if organic_history_can_create_city_for_player(player, tile) then
            counts.legal_sites = counts.legal_sites + 1
          else
            counts.illegal_sites = counts.illegal_sites + 1
          end
        end
      end
    end
  end

  return counts
end

function organic_history_iberian_site_pool_diagnostic(turn, actor_id, actor,
                                                      actor_player)
  if actor_id ~= "castile" and actor_id ~= "portugal" then
    return
  end

  local regions = {}
  local seen = {}

  local function add_region(region_id, scope)
    if region_id == nil or seen[region_id] then
      return
    end
    seen[region_id] = true
    table.insert(regions, {id = region_id, scope = scope})
  end

  add_region(actor.core_region, "core")
  add_region("iberia", "iberia")
  for _, fallback_region in ipairs(actor.fallback_regions or {}) do
    add_region(fallback_region, "fallback")
  end

  for _, entry in ipairs(regions) do
    local counts =
        organic_history_city_site_pool_counts(actor_player, entry.id)

    log.normal('organic_history_iberian_site_pool turn=%d actor=%q region=%q scope=%q checked=%d city_occupied=%d unit_occupied=%d terrain_blocked=%d empty_sites=%d legal_sites=%d illegal_sites=%d holder_counts=%q',
               turn, actor_id, entry.id, entry.scope, counts.checked,
               counts.city_occupied, counts.unit_occupied,
               counts.terrain_blocked, counts.empty_sites,
               counts.legal_sites, counts.illegal_sites,
               organic_history_count_map_string(counts.holders))
  end
end

function organic_history_iberian_site_diagnostic(turn, actor_id, actor,
                                                 context, candidates,
                                                 placement)
  if actor_id ~= "castile" and actor_id ~= "portugal" then
    return
  end

  local target_tile = find.tile(actor.x, actor.y)
  local target_city = nil
  local target_holder = "none"
  local target_region = "none"
  local target_units = 0
  if target_tile ~= nil then
    target_city = target_tile:city()
    target_region = organic_history_region_for_tile(target_tile) or "none"
    target_units = target_tile:num_units()
    if target_city ~= nil and target_city.owner ~= nil then
      local _, holder_actor_id =
          organic_history_actor_metadata_for(target_city.owner)
      target_holder = holder_actor_id or organic_history_player_name(
          target_city.owner)
    end
  end

  local iberian_sites = 0
  local core_sites = 0
  local fallback_sites = 0
  local legal_iberian_sites = 0
  local legal_core_sites = 0
  local legal_fallback_sites = 0
  local actor_player = organic_history_find_actor_player(actor)
  local seen = {}
  if target_tile ~= nil then
    seen[target_tile.id] = true
    if target_tile:city() == nil
       and organic_history_region_for_tile(target_tile) == "iberia"
       and organic_history_tile_can_host_emergence_city(target_tile) then
      iberian_sites = iberian_sites + 1
      if organic_history_can_create_city_for_player(actor_player,
                                                    target_tile) then
        legal_iberian_sites = legal_iberian_sites + 1
      end
    end
    if target_tile:city() == nil
       and organic_history_region_for_tile(target_tile) == actor.core_region
       and organic_history_tile_can_host_emergence_city(target_tile) then
      core_sites = core_sites + 1
      if organic_history_can_create_city_for_player(actor_player,
                                                    target_tile) then
        legal_core_sites = legal_core_sites + 1
      end
    end
    for radius = 1, organic_history_emergence_relocation_radius do
      for tile in target_tile:circle_iterate(radius) do
        if not seen[tile.id] then
          seen[tile.id] = true
          if tile:city() == nil
             and organic_history_region_for_tile(tile) == "iberia"
             and organic_history_tile_can_host_emergence_city(tile) then
            iberian_sites = iberian_sites + 1
            if organic_history_can_create_city_for_player(actor_player, tile) then
              legal_iberian_sites = legal_iberian_sites + 1
            end
          end
          if tile:city() == nil
             and organic_history_region_for_tile(tile) == actor.core_region
             and organic_history_tile_can_host_emergence_city(tile) then
            core_sites = core_sites + 1
            if organic_history_can_create_city_for_player(actor_player, tile) then
              legal_core_sites = legal_core_sites + 1
            end
          end
        end
      end
    end
  end

  for _, fallback_region in ipairs(actor.fallback_regions or {}) do
    local region_candidates = {}
    organic_history_append_region_emergence_candidates(region_candidates, {},
                                                       fallback_region,
                                                       actor_player)
    fallback_sites = fallback_sites + #region_candidates
    legal_fallback_sites = legal_fallback_sites + #region_candidates
  end

  log.normal('organic_history_iberian_site turn=%d actor=%q placement=%q candidate_count=%d core_region=%q core_sites=%d legal_core_sites=%d iberian_sites=%d legal_iberian_sites=%d fallback_sites=%d legal_fallback_sites=%d target_region=%q target_occupied=%s target_holder=%q target_units=%d total_core_cities=%d leader_actor=%q leader_share=%.3f',
             turn, actor_id, placement or "unknown", #candidates,
             actor.core_region or "unknown", core_sites, legal_core_sites,
             iberian_sites, legal_iberian_sites, fallback_sites,
             legal_fallback_sites, target_region, tostring(target_city ~= nil),
             target_holder, target_units, context.total,
             context.leader_actor, context.leader_share)
  organic_history_iberian_site_pool_diagnostic(turn, actor_id, actor,
                                               actor_player)
end

function organic_history_iberian_activation_order_log(turn, actor_id, action,
                                                      placement)
  if actor_id ~= "castile" and actor_id ~= "portugal" then
    return
  end
  if organic_history_iberian_activation_logged[actor_id] then
    return
  end

  organic_history_iberian_activation_sequence =
      organic_history_iberian_activation_sequence + 1
  organic_history_iberian_activation_logged[actor_id] =
      organic_history_iberian_activation_sequence

  local castile = organic_history_player_for_actor_id("castile")
  local portugal = organic_history_player_for_actor_id("portugal")
  local castile_cities = 0
  local portugal_cities = 0

  if castile ~= nil then
    castile_cities = castile:num_cities()
  end
  if portugal ~= nil then
    portugal_cities = portugal:num_cities()
  end

  log.normal('organic_history_iberian_activation_order turn=%d actor=%q order=%d action=%q placement=%q castile_cities=%d portugal_cities=%d',
             turn, actor_id, organic_history_iberian_activation_sequence,
             action, placement or "unknown", castile_cities,
             portugal_cities)
end

function organic_history_burst_log(turn, actor_id, action, reason, extra)
  log.normal('organic_history_burst turn=%d actor=%q action=%q reason=%q %s',
             turn, actor_id, action, reason, extra or "")
end

function organic_history_burst_home_city(player)
  local fallback = nil

  if player == nil then
    return nil
  end

  for city in player:cities_iterate() do
    if fallback == nil then
      fallback = city
    end
    if city:is_primary_capital() or city:is_capital() then
      return city
    end
  end

  return fallback
end

function organic_history_check_burst_actor(turn, actor_id, actor)
  if actor == nil or actor.burst == nil then
    return
  end

  local player = organic_history_player_for_actor_id(actor_id)
  local burst = actor.burst
  local birth_turn = organic_history_actor_birth_turn(actor_id, turn)
  local age = math.max(0, turn - birth_turn)
  local start_age = burst.startTurnAfterBirth or 0
  local duration = burst.durationTurns or 40
  local applications = organic_history_burst_applications[actor_id] or 0
  local max_applications = burst.maxApplications or 1
  local cooldown = burst.cooldownTurns or 15
  local last_turn = organic_history_burst_last_turn[actor_id] or -999999
  local lifecycle_type, lifecycle = organic_history_actor_lifecycle(actor_id)
  local target_min, target_max, window = nil, nil, "no_target"

  if lifecycle ~= nil then
    target_min, target_max, window =
        organic_history_lifecycle_target_range(lifecycle, age)
  end

  local city_count = 0
  if player ~= nil then
    city_count = player:num_cities()
  end

  local extra = "archetype=" .. string.format("%q", burst.archetype
                                             or "unknown")
      .. " lifecycle_type=" .. string.format("%q", lifecycle_type or "unknown")
      .. " age=" .. age
      .. " start_age=" .. start_age
      .. " duration=" .. duration
      .. " cities=" .. city_count
      .. " target_min=" .. (target_min or -1)
      .. " target_max=" .. (target_max or -1)
      .. " target_window=" .. string.format("%q", window)
      .. " applications=" .. applications
      .. " max_applications=" .. max_applications
      .. " cooldown=" .. cooldown
      .. " applied=false"

  if player == nil or not player.is_alive or city_count <= 0 then
    organic_history_burst_log(turn, actor_id, "skip", "missing_actor", extra)
    return
  elseif age < start_age then
    organic_history_burst_log(turn, actor_id, "skip", "before_window", extra)
    return
  elseif age > start_age + duration then
    organic_history_burst_log(turn, actor_id, "protected", "after_window",
                             extra)
    return
  elseif applications >= max_applications then
    organic_history_burst_log(turn, actor_id, "protected", "application_cap",
                             extra)
    return
  elseif turn < last_turn + cooldown then
    organic_history_burst_log(turn, actor_id, "protected", "cooldown",
                             extra .. " cooldown_until="
                             .. (last_turn + cooldown))
    return
  elseif target_max ~= nil and city_count >= target_max then
    organic_history_burst_log(turn, actor_id, "protected", "on_target",
                             extra)
    return
  end

  local homecity = organic_history_burst_home_city(player)
  if homecity == nil or homecity.tile == nil then
    organic_history_burst_log(turn, actor_id, "noop", "missing_home_city",
                             extra)
    return
  end

  local gold = math.min(math.floor(burst.gold or 0),
                       organic_history_burst_max_gold)
  local units = math.min(math.floor(burst.offensiveUnits or 0),
                        organic_history_burst_max_units)

  if gold > 0 then
    edit.change_gold(player, gold)
  end

  local created_units, skipped_units =
      organic_history_bootstrap_create_units(
          player, homecity, homecity.tile, units,
          {"AttackFastStartUnit", "AttackStrongStartUnit", "Hut",
           "FirstBuild"})

  organic_history_burst_applications[actor_id] = applications + 1
  organic_history_burst_last_turn[actor_id] = turn
  organic_history_burst_log(
      turn, actor_id, "applied", "bounded_burst_support",
      string.gsub(extra, " applied=false", " applied=true")
      .. " gold=" .. gold
      .. " requested_units=" .. units
      .. " created_units=" .. created_units
      .. " skipped_units=" .. skipped_units
      .. " home_city=" .. string.format("%q", homecity.name)
      .. " x=" .. homecity.tile.x
      .. " y=" .. homecity.tile.y)
end

function organic_history_check_bursts(turn)
  if not (organic_history_mechanics_enabled
          and organic_history_burst_enabled
          and organic_history_large_earth_active()) then
    return
  end

  for actor_id, actor in pairs(organic_history_active_emergence_actors()) do
    organic_history_check_burst_actor(turn, actor_id, actor)
  end
end

function organic_history_near_east_handoff_log(turn, actor_id, action, reason,
                                               extra)
  log.normal('organic_history_near_east_handoff turn=%d actor=%q action=%q reason=%q %s',
             turn, actor_id, action, reason, extra or "")
end

function organic_history_near_east_corridor_counts(player)
  local counts = {mesopotamia = 0, levant = 0, iran = 0, anatolia = 0,
                  total = 0}

  if player == nil then
    return counts
  end

  for city in player:cities_iterate() do
    local region = organic_history_region_for_city(city)
    if counts[region] ~= nil then
      counts[region] = counts[region] + 1
      counts.total = counts.total + 1
    end
  end

  return counts
end

function organic_history_near_east_support_rule(actor_id)
  local rules = {
    abbasid = {maxApplications = 3, cooldown = 18, gold = 50,
               offensiveUnits = 1, settlers = 1},
    assyria = {maxApplications = 2, cooldown = 14, gold = 45,
               offensiveUnits = 2, settlers = 0},
    persia = {maxApplications = 1, cooldown = 18, gold = 35,
              offensiveUnits = 1, settlers = 0},
    sumer = {maxApplications = 0, cooldown = 99, gold = 0,
             offensiveUnits = 0, settlers = 0}
  }

  return rules[actor_id]
end

function organic_history_check_near_east_handoff_actor(turn, actor_id)
  local rule = organic_history_near_east_support_rule(actor_id)
  if rule == nil then
    return
  end

  local player = organic_history_player_for_actor_id(actor_id)
  local actor = organic_history_active_emergence_actors()[actor_id] or {}
  local counts = organic_history_near_east_corridor_counts(player)
  local cities = 0
  if player ~= nil then
    cities = player:num_cities()
  end

  local birth_turn = organic_history_actor_birth_turn(actor_id, turn)
  local age = math.max(0, turn - birth_turn)
  local _, lifecycle = organic_history_actor_lifecycle(actor_id)
  local target_min, target_max, window = nil, nil, "no_target"
  if lifecycle ~= nil then
    target_min, target_max, window =
        organic_history_lifecycle_target_range(lifecycle, age)
  end

  local applications =
      organic_history_near_east_handoff_applications[actor_id] or 0
  local last_turn =
      organic_history_near_east_handoff_last_turn[actor_id] or -999999
  local extra = "cities=" .. cities
      .. " corridor_cities=" .. counts.total
      .. " mesopotamia=" .. counts.mesopotamia
      .. " levant=" .. counts.levant
      .. " iran=" .. counts.iran
      .. " anatolia=" .. counts.anatolia
      .. " age=" .. age
      .. " target_min=" .. (target_min or -1)
      .. " target_max=" .. (target_max or -1)
      .. " target_window=" .. string.format("%q", window)
      .. " applications=" .. applications
      .. " max_applications=" .. rule.maxApplications
      .. " applied=false"

  if player == nil or not player.is_alive or cities <= 0 then
    organic_history_near_east_handoff_log(turn, actor_id, "skip",
                                          "missing_actor", extra)
    return
  elseif rule.maxApplications <= 0 then
    organic_history_near_east_handoff_log(turn, actor_id, "protected",
                                          "diagnostics_only", extra)
    return
  elseif target_max ~= nil and cities >= target_max then
    organic_history_near_east_handoff_log(turn, actor_id, "protected",
                                          "on_target", extra)
    return
  elseif applications >= rule.maxApplications then
    organic_history_near_east_handoff_log(turn, actor_id, "protected",
                                          "application_cap", extra)
    return
  elseif turn < last_turn + rule.cooldown then
    organic_history_near_east_handoff_log(
        turn, actor_id, "protected", "cooldown",
        extra .. " cooldown_until=" .. (last_turn + rule.cooldown))
    return
  end

  local homecity = organic_history_burst_home_city(player)
  if homecity == nil or homecity.tile == nil then
    organic_history_near_east_handoff_log(turn, actor_id, "noop",
                                          "missing_home_city", extra)
    return
  end

  local gold = math.min(rule.gold or 0,
                        organic_history_near_east_handoff_max_gold)
  if gold > 0 then
    edit.change_gold(player, gold)
  end

  local created_offensive, skipped_offensive =
      organic_history_bootstrap_create_units(
          player, homecity, homecity.tile,
          math.min(rule.offensiveUnits or 0,
                   organic_history_near_east_handoff_max_units),
          {"AttackFastStartUnit", "AttackStrongStartUnit", "Hut",
           "FirstBuild"})
  local created_settlers, skipped_settlers =
      organic_history_bootstrap_create_units(
          player, homecity, homecity.tile,
          math.min(rule.settlers or 0,
                   organic_history_near_east_handoff_max_units),
          {"Cities", "Settlers", "CitiesStartUnit"}, 3, 5)
  organic_history_track_settler_conversion(turn, actor_id, player,
                                           "near_east_handoff",
                                           created_settlers,
                                           skipped_settlers)

  organic_history_near_east_handoff_applications[actor_id] =
      applications + 1
  organic_history_near_east_handoff_last_turn[actor_id] = turn
  organic_history_near_east_handoff_log(
      turn, actor_id, "applied", "corridor_support",
      string.gsub(extra, " applied=false", " applied=true")
      .. " gold=" .. gold
      .. " offensive_units=" .. created_offensive
      .. " skipped_offensive=" .. skipped_offensive
      .. " settlers=" .. created_settlers
      .. " skipped_settlers=" .. skipped_settlers
      .. " home_city=" .. string.format("%q", homecity.name))
end

function organic_history_check_near_east_handoffs(turn)
  if not (organic_history_mechanics_enabled
          and organic_history_near_east_handoff_enabled
          and organic_history_large_earth_active()) then
    return
  end

  for _, actor_id in ipairs({"sumer", "assyria", "persia", "abbasid"}) do
    organic_history_check_near_east_handoff_actor(turn, actor_id)
  end
end

function organic_history_conquest_target_log(turn, actor_id, action, reason,
                                             extra)
  log.normal('organic_history_conquest_target turn=%d actor=%q action=%q reason=%q %s',
             turn, actor_id, action, reason, extra or "")
end

function organic_history_conquest_conversion_log(turn, actor_id, action,
                                                 reason, extra)
  log.normal('organic_history_conquest_conversion turn=%d actor=%q action=%q reason=%q %s',
             turn, actor_id, action, reason, extra or "")
end

function organic_history_track_conquest_conversion(turn, actor_id, player,
                                                   target_region,
                                                   actor_region_cities,
                                                   rival_region_cities,
                                                   region_total,
                                                   target_score,
                                                   created_units,
                                                   skipped_units,
                                                   source,
                                                   objective_id,
                                                   hold_defenders,
                                                   hold_gold)
  if player == nil or target_region == nil or target_region == "none" then
    return
  end

  local id = organic_history_conquest_conversion_next_id
  organic_history_conquest_conversion_next_id = id + 1
  organic_history_conquest_conversion_tracking[id] = {
    actor_id = actor_id,
    player_id = organic_history_player_id(player),
    start_turn = turn,
    target_region = target_region,
    initial_actor_region_cities = actor_region_cities or 0,
    initial_rival_region_cities = rival_region_cities or 0,
    initial_region_total = region_total or 0,
    max_actor_region_cities = actor_region_cities or 0,
    min_rival_region_cities = rival_region_cities or 0,
    target_score = target_score or 0,
    created_units = created_units or 0,
    skipped_units = skipped_units or 0,
    source = source or "conquest_target",
    objective_id = objective_id or "none",
    hold_defenders = hold_defenders or 0,
    hold_gold = hold_gold or 0
  }

  organic_history_conquest_conversion_log(
      turn, actor_id, "tracking", "target_support_applied",
      "id=" .. id
      .. " player=" .. organic_history_player_id(player)
      .. " target_region=" .. string.format("%q", target_region)
      .. " initial_actor_region_cities=" .. (actor_region_cities or 0)
      .. " initial_rival_region_cities=" .. (rival_region_cities or 0)
      .. " initial_region_total=" .. (region_total or 0)
      .. " target_score=" .. (target_score or 0)
      .. " created_units=" .. (created_units or 0)
      .. " skipped_units=" .. (skipped_units or 0)
      .. " source=" .. string.format("%q", source or "conquest_target")
      .. " objective=" .. string.format("%q", objective_id or "none")
      .. " hold_defenders=" .. (hold_defenders or 0)
      .. " hold_gold=" .. (hold_gold or 0))
end

function organic_history_objective_hold_city(player, target_region)
  if player == nil then
    return nil
  end

  for city in player:cities_iterate() do
    if organic_history_region_for_city(city) == target_region then
      return city
    end
  end

  return nil
end

function organic_history_apply_objective_hold_support(turn, entry, player)
  if entry.source ~= "objective" or (entry.hold_defenders or 0) <= 0 then
    return
  end

  local city = organic_history_objective_hold_city(player, entry.target_region)
  if city == nil or city.tile == nil then
    organic_history_objective_log(
        turn, entry.actor_id, entry.objective_id, "noop",
        "missing_hold_city",
        "target_region=" .. string.format("%q", entry.target_region)
        .. " hold_defenders=" .. (entry.hold_defenders or 0))
    return
  end

  local gold = math.min(entry.hold_gold or 0,
                        organic_history_objective_max_gold)
  if gold > 0 then
    edit.change_gold(player, gold)
  end

  local created_defenders, skipped_defenders =
      organic_history_bootstrap_create_units(
          player, city, city.tile,
          math.min(entry.hold_defenders or 0,
                   organic_history_objective_max_units),
          {"DefendGoodStartUnit", "DefendGood", "DefendOkStartUnit",
           "DefendOk", "FirstBuild"})

  organic_history_objective_log(
      turn, entry.actor_id, entry.objective_id, "applied", "hold_support",
      "target_region=" .. string.format("%q", entry.target_region)
      .. " city=" .. string.format("%q", city.name)
      .. " gold=" .. gold
      .. " defender_units=" .. created_defenders
      .. " skipped_units=" .. skipped_defenders
      .. " x=" .. city.tile.x
      .. " y=" .. city.tile.y)
end

function organic_history_check_conquest_conversions(turn)
  local observation_turns = 24

  for id, entry in pairs(organic_history_conquest_conversion_tracking) do
    local player = organic_history_player_for_actor_id(entry.actor_id)
    if player == nil or not player.is_alive then
      organic_history_conquest_conversion_log(
          turn, entry.actor_id, "resolved", "actor_lost",
          "id=" .. id
          .. " start_turn=" .. entry.start_turn
          .. " age=" .. (turn - entry.start_turn)
          .. " target_region=" .. string.format("%q", entry.target_region)
          .. " initial_actor_region_cities="
          .. entry.initial_actor_region_cities
          .. " current_actor_region_cities=0"
          .. " max_actor_region_cities="
          .. entry.max_actor_region_cities
          .. " initial_rival_region_cities="
          .. entry.initial_rival_region_cities
          .. " current_rival_region_cities=0"
          .. " min_rival_region_cities="
          .. entry.min_rival_region_cities
          .. " created_units=" .. entry.created_units
          .. " skipped_units=" .. entry.skipped_units)
      organic_history_conquest_conversion_tracking[id] = nil
    else
      local actor_cities, rival_cities, total_cities =
          organic_history_region_city_balance(player, entry.target_region)
      if actor_cities > entry.max_actor_region_cities then
        entry.max_actor_region_cities = actor_cities
      end
      if rival_cities < entry.min_rival_region_cities then
        entry.min_rival_region_cities = rival_cities
      end

      if turn >= entry.start_turn + observation_turns then
        local city_gain = actor_cities - entry.initial_actor_region_cities
        local peak_gain = entry.max_actor_region_cities
            - entry.initial_actor_region_cities
        local rival_loss = entry.initial_rival_region_cities - rival_cities
        local reason = "no_conversion"
        if city_gain > 0 then
          reason = "durable_region_gain"
          organic_history_apply_objective_hold_support(turn, entry, player)
        elseif peak_gain > 0 then
          reason = "captured_then_lost"
        elseif rival_loss > 0 then
          reason = "rival_declined_no_hold"
        end

        organic_history_conquest_conversion_log(
            turn, entry.actor_id, "resolved", reason,
            "id=" .. id
            .. " start_turn=" .. entry.start_turn
            .. " age=" .. (turn - entry.start_turn)
            .. " target_region=" .. string.format("%q", entry.target_region)
            .. " initial_actor_region_cities="
            .. entry.initial_actor_region_cities
            .. " current_actor_region_cities=" .. actor_cities
            .. " max_actor_region_cities="
            .. entry.max_actor_region_cities
            .. " initial_rival_region_cities="
            .. entry.initial_rival_region_cities
            .. " current_rival_region_cities=" .. rival_cities
            .. " min_rival_region_cities="
            .. entry.min_rival_region_cities
            .. " current_region_total=" .. total_cities
            .. " city_gain=" .. city_gain
            .. " peak_city_gain=" .. peak_gain
            .. " rival_loss=" .. rival_loss
            .. " target_score=" .. entry.target_score
            .. " created_units=" .. entry.created_units
            .. " skipped_units=" .. entry.skipped_units)
        organic_history_conquest_conversion_tracking[id] = nil
      end
    end
  end
end

function organic_history_conquest_target_regions(actor_id)
  local regions = {
    assyria = {"mesopotamia", "levant", "anatolia", "iran"},
    persia = {"iran", "mesopotamia", "levant", "north_india"},
    rome = {"italy", "gaul", "iberia", "maghreb_punic_west", "levant"},
    steppe = {"steppe_mongolia", "north_china", "iran", "europe"}
  }

  return regions[actor_id]
end

function organic_history_region_city_balance(player, region_id)
  local actor_cities = 0
  local rival_cities = 0
  local total_cities = 0

  for other_player in players_iterate() do
    if other_player.is_alive then
      for city in other_player:cities_iterate() do
        if organic_history_region_for_city(city) == region_id then
          total_cities = total_cities + 1
          if player ~= nil and other_player == player then
            actor_cities = actor_cities + 1
          else
            rival_cities = rival_cities + 1
          end
        end
      end
    end
  end

  return actor_cities, rival_cities, total_cities
end

function organic_history_region_rival_player(player, region_id)
  local best_player = nil
  local best_cities = 0
  local counts = {}

  for other_player in players_iterate() do
    if other_player ~= player and other_player.is_alive then
      for city in other_player:cities_iterate() do
        if organic_history_region_for_city(city) == region_id then
          local player_id = organic_history_player_id(other_player)
          counts[player_id] = (counts[player_id] or 0) + 1
          if counts[player_id] > best_cities then
            best_cities = counts[player_id]
            best_player = other_player
          end
        end
      end
    end
  end

  return best_player, best_cities
end

function organic_history_target_overlap_log(turn, actor_id, source,
                                            objective_id, regions,
                                            selected_region)
  for index, region_id in ipairs(regions or {}) do
    local actor_cities, rival_cities, total_cities =
        organic_history_region_city_balance(
            organic_history_player_for_actor_id(actor_id), region_id)
    local top_rival, top_rival_cities =
        organic_history_region_rival_player(
            organic_history_player_for_actor_id(actor_id), region_id)
    local _, top_rival_actor =
        organic_history_actor_metadata_for(top_rival)
    local score = (rival_cities * 3) - (actor_cities * 2) + (10 - index)

    if source ~= "conquest_target" then
      score = (rival_cities * 4) - (actor_cities * 2) + (20 - index)
    end
    if rival_cities <= 0 then
      score = score - (source ~= "conquest_target" and 30 or 20)
    elseif total_cities <= 0 then
      score = score - (source ~= "conquest_target" and 5 or 4)
    end

    log.normal('organic_history_target_overlap turn=%d actor=%q source=%q objective=%q region=%q selected=%s actor_region_cities=%d rival_region_cities=%d region_total=%d target_score=%d top_rival_actor=%q top_rival_cities=%d',
               turn, actor_id, source, objective_id or "none", region_id,
               tostring(region_id == selected_region), actor_cities,
               rival_cities, total_cities, score,
               top_rival_actor or "none", top_rival_cities or 0)
  end
end

function organic_history_select_conquest_target(player, actor_id)
  local regions = organic_history_conquest_target_regions(actor_id)
  if regions == nil then
    return nil
  end

  local best = nil
  for index, region_id in ipairs(regions) do
    local actor_cities, rival_cities, total_cities =
        organic_history_region_city_balance(player, region_id)
    local score = (rival_cities * 3) - (actor_cities * 2) + (10 - index)
    if rival_cities <= 0 then
      score = score - 20
    elseif total_cities <= 0 then
      score = score - 4
    end

    if best == nil or score > best.score then
      best = {
        region = region_id,
        actor_cities = actor_cities,
        rival_cities = rival_cities,
        total_cities = total_cities,
        score = score
      }
    end
  end

  return best
end

function organic_history_conquest_target_rule(actor_id)
  local rules = {
    assyria = {maxApplications = 2, cooldown = 16, gold = 35, units = 2},
    persia = {maxApplications = 2, cooldown = 18, gold = 35, units = 2},
    rome = {maxApplications = 2, cooldown = 18, gold = 40, units = 2},
    steppe = {maxApplications = 3, cooldown = 14, gold = 35, units = 3}
  }

  return rules[actor_id]
end

function organic_history_check_conquest_target_actor(turn, actor_id)
  local rule = organic_history_conquest_target_rule(actor_id)
  if rule == nil then
    return
  end

  local player = organic_history_player_for_actor_id(actor_id)
  local cities = 0
  if player ~= nil then
    cities = player:num_cities()
  end
  local birth_turn = organic_history_actor_birth_turn(actor_id, turn)
  local age = math.max(0, turn - birth_turn)
  local _, lifecycle = organic_history_actor_lifecycle(actor_id)
  local target_min, target_max, window = nil, nil, "no_target"
  if lifecycle ~= nil then
    target_min, target_max, window =
        organic_history_lifecycle_target_range(lifecycle, age)
  end
  local target = organic_history_select_conquest_target(player, actor_id)
  local applications = organic_history_conquest_target_applications[actor_id] or 0
  local last_turn = organic_history_conquest_target_last_turn[actor_id] or -999999
  local region = "none"
  local rival_cities = 0
  local actor_cities = 0
  local region_total = 0
  local score = 0

  if target ~= nil then
    region = target.region
    rival_cities = target.rival_cities
    actor_cities = target.actor_cities
    region_total = target.total_cities
    score = target.score
  end
  organic_history_target_overlap_log(
      turn, actor_id, "conquest_target", "none",
      organic_history_conquest_target_regions(actor_id), region)

  local extra = "cities=" .. cities
      .. " age=" .. age
      .. " target_min=" .. (target_min or -1)
      .. " target_max=" .. (target_max or -1)
      .. " target_window=" .. string.format("%q", window)
      .. " target_region=" .. string.format("%q", region)
      .. " actor_region_cities=" .. actor_cities
      .. " rival_region_cities=" .. rival_cities
      .. " region_total=" .. region_total
      .. " target_score=" .. score
      .. " applications=" .. applications
      .. " max_applications=" .. rule.maxApplications
      .. " applied=false"

  if player == nil or not player.is_alive or cities <= 0 then
    organic_history_conquest_target_log(turn, actor_id, "skip",
                                        "missing_actor", extra)
    return
  elseif target == nil then
    organic_history_conquest_target_log(turn, actor_id, "noop",
                                        "missing_target_regions", extra)
    return
  elseif target_max ~= nil and cities >= target_max then
    organic_history_conquest_target_log(turn, actor_id, "protected",
                                        "on_target", extra)
    return
  elseif rival_cities <= 0 then
    organic_history_conquest_target_log(turn, actor_id, "noop",
                                        "no_rival_target", extra)
    return
  elseif applications >= rule.maxApplications then
    organic_history_conquest_target_log(turn, actor_id, "protected",
                                        "application_cap", extra)
    return
  elseif turn < last_turn + rule.cooldown then
    organic_history_conquest_target_log(
        turn, actor_id, "protected", "cooldown",
        extra .. " cooldown_until=" .. (last_turn + rule.cooldown))
    return
  end

  local homecity = organic_history_burst_home_city(player)
  if homecity == nil or homecity.tile == nil then
    organic_history_conquest_target_log(turn, actor_id, "noop",
                                        "missing_home_city", extra)
    return
  end

  local gold = math.min(rule.gold or 0,
                        organic_history_conquest_target_max_gold)
  if gold > 0 then
    edit.change_gold(player, gold)
  end

  local created, skipped = organic_history_bootstrap_create_units(
      player, homecity, homecity.tile,
      math.min(rule.units or 0, organic_history_conquest_target_max_units),
      {"AttackFastStartUnit", "AttackStrongStartUnit", "Hut", "FirstBuild"})

  organic_history_track_conquest_conversion(
      turn, actor_id, player, region, actor_cities, rival_cities,
      region_total, score, created, skipped)

  organic_history_conquest_target_applications[actor_id] = applications + 1
  organic_history_conquest_target_last_turn[actor_id] = turn
  organic_history_conquest_target_log(
      turn, actor_id, "applied", "target_support",
      string.gsub(extra, " applied=false", " applied=true")
      .. " gold=" .. gold
      .. " requested_units=" .. math.min(rule.units or 0,
                                          organic_history_conquest_target_max_units)
      .. " created_units=" .. created
      .. " skipped_units=" .. skipped
      .. " home_city=" .. string.format("%q", homecity.name))
end

function organic_history_check_conquest_targets(turn)
  if not (organic_history_mechanics_enabled
          and organic_history_conquest_target_enabled
          and organic_history_large_earth_active()) then
    return
  end

  for _, actor_id in ipairs({"assyria", "persia", "rome", "steppe"}) do
    organic_history_check_conquest_target_actor(turn, actor_id)
  end
end

function organic_history_objective_log(turn, actor_id, objective_id, action,
                                       reason, extra)
  log.normal('organic_history_objective turn=%d actor=%q objective=%q action=%q reason=%q %s',
             turn, actor_id, objective_id or "unknown", action, reason,
             extra or "")
end

function organic_history_objective_key(actor_id, objective)
  return tostring(actor_id) .. ":" .. tostring(objective.id or "unknown")
end

function organic_history_select_objective_target(player, objective)
  local best = nil

  for index, region_id in ipairs(objective.targetRegions or {}) do
    local actor_cities, rival_cities, total_cities =
        organic_history_region_city_balance(player, region_id)
    local score = (rival_cities * 4) - (actor_cities * 2) + (20 - index)
    if rival_cities <= 0 then
      score = score - 30
    end
    if total_cities <= 0 then
      score = score - 5
    end

    if best == nil or score > best.score then
      best = {
        region = region_id,
        actor_cities = actor_cities,
        rival_cities = rival_cities,
        total_cities = total_cities,
        score = score
      }
    end
  end

  return best
end

function organic_history_objective_staging_tile(player, objective, target)
  local homecity = organic_history_burst_home_city(player)
  local fallback = nil

  if homecity == nil or homecity.tile == nil then
    return nil, nil, "missing_home_city"
  end

  fallback = homecity.tile
  for city in player:cities_iterate() do
    if organic_history_region_for_city(city) == target.region then
      return city, city.tile, "target_region_city"
    end
    if organic_history_region_allowed(organic_history_region_for_city(city),
                                      objective.targetRegions) then
      fallback = city.tile
      homecity = city
    end
  end

  if objective.expeditionaryStaging then
    local expedition_tile = organic_history_objective_expeditionary_tile(
        player, target.region)
    if expedition_tile ~= nil then
      return homecity, expedition_tile, "target_region_expedition"
    end
  end

  for radius = 1, 6 do
    for tile in homecity.tile:circle_iterate(radius) do
      if organic_history_region_for_tile(tile) == target.region then
        return homecity, tile, "near_target_region"
      end
    end
  end

  return homecity, fallback, "home_region_staging"
end

function organic_history_objective_expeditionary_tile(player, target_region)
  local unit_type = organic_history_bootstrap_find_unit_type(
      player, {"AttackFastStartUnit", "AttackStrongStartUnit", "Hut",
               "FirstBuild"})
  if unit_type == nil then
    return nil
  end

  for other_player in players_iterate() do
    if other_player ~= player and other_player.is_alive then
      for city in other_player:cities_iterate() do
        if organic_history_region_for_city(city) == target_region then
          for radius = 1, 3 do
            for tile in city.tile:circle_iterate(radius) do
              if tile:city() == nil and unit_type:can_exist_at_tile(tile) then
                return tile
              end
            end
          end
        end
      end
    end
  end

  return nil
end

function organic_history_check_conquest_objective(turn, actor_id, objective)
  local player = organic_history_player_for_actor_id(actor_id)
  local objective_id = objective.id or "unknown"
  local cities = 0
  if player ~= nil then
    cities = player:num_cities()
  end
  local birth_turn = organic_history_actor_birth_turn(actor_id, turn)
  local age = math.max(0, turn - birth_turn)
  local key = organic_history_objective_key(actor_id, objective)
  local applications = organic_history_objective_applications[key] or 0
  local max_applications = objective.maxApplications or 1
  local cooldown = objective.cooldownTurns or 20
  local last_turn = organic_history_objective_last_turn[key] or -999999
  local start_age = objective.startTurnAfterBirth or 0
  local duration = objective.durationTurns or 9999
  local target = organic_history_select_objective_target(player, objective)
  local target_region = "none"
  local actor_region_cities = 0
  local rival_region_cities = 0
  local region_total = 0
  local target_score = 0

  if target ~= nil then
    target_region = target.region
    actor_region_cities = target.actor_cities
    rival_region_cities = target.rival_cities
    region_total = target.total_cities
    target_score = target.score
  end
  organic_history_target_overlap_log(
      turn, actor_id, "objective", objective_id,
      objective.targetRegions, target_region)

  local extra = "type=" .. string.format("%q", objective.type or "unknown")
      .. " age=" .. age
      .. " start_age=" .. start_age
      .. " duration=" .. duration
      .. " cities=" .. cities
      .. " min_cities=" .. (objective.minCities or -1)
      .. " target_cities=" .. (objective.targetCities or -1)
      .. " applications=" .. applications
      .. " max_applications=" .. max_applications
      .. " cooldown=" .. cooldown
      .. " target_region=" .. string.format("%q", target_region)
      .. " actor_region_cities=" .. actor_region_cities
      .. " rival_region_cities=" .. rival_region_cities
      .. " region_total=" .. region_total
      .. " target_score=" .. target_score
      .. " applied=false"

  if player == nil or not player.is_alive or cities <= 0 then
    organic_history_objective_log(turn, actor_id, objective_id, "skip",
                                  "missing_actor", extra)
    return
  elseif age < start_age then
    organic_history_objective_log(turn, actor_id, objective_id, "skip",
                                  "before_window", extra)
    return
  elseif age > start_age + duration then
    organic_history_objective_log(turn, actor_id, objective_id, "protected",
                                  "after_window", extra)
    return
  elseif objective.targetCities ~= nil and cities >= objective.targetCities then
    organic_history_objective_log(turn, actor_id, objective_id, "protected",
                                  "on_target", extra)
    return
  elseif cities < (objective.minCities or 1) then
    organic_history_objective_log(turn, actor_id, objective_id, "protected",
                                  "too_small", extra)
    return
  elseif target == nil then
    organic_history_objective_log(turn, actor_id, objective_id, "noop",
                                  "missing_target_regions", extra)
    return
  elseif rival_region_cities < (objective.minRivalCities or 1) then
    organic_history_objective_log(turn, actor_id, objective_id, "protected",
                                  "no_rival_target", extra)
    return
  elseif applications >= max_applications then
    organic_history_objective_log(turn, actor_id, objective_id, "protected",
                                  "application_cap", extra)
    return
  elseif turn < last_turn + cooldown then
    organic_history_objective_log(
        turn, actor_id, objective_id, "protected", "cooldown",
        extra .. " cooldown_until=" .. (last_turn + cooldown))
    return
  end

  local homecity, staging_tile, staging_reason =
      organic_history_objective_staging_tile(player, objective, target)
  if homecity == nil or staging_tile == nil then
    organic_history_objective_log(turn, actor_id, objective_id, "noop",
                                  staging_reason, extra)
    return
  end

  local war_target = nil
  local war_target_cities = 0
  local war_declared = false
  local war_state = "none"
  if objective.declareWar then
    war_target, war_target_cities =
        organic_history_region_rival_player(player, target_region)
    if war_target ~= nil then
      war_state = player:diplstate(war_target)
      if war_state ~= "War" and edit.enter_war ~= nil then
        war_declared = edit.enter_war(player, war_target)
        war_state = player:diplstate(war_target)
      end
    end
  end

  local gold = math.min(objective.gold or 0,
                        organic_history_objective_max_gold)
  if gold > 0 then
    edit.change_gold(player, gold)
  end

  local offensive_requested = math.min(
      objective.offensiveUnits or 0,
      organic_history_objective_max_units)
  local defender_requested = math.min(
      objective.defenders or 0,
      math.max(0, organic_history_objective_max_units - offensive_requested))
  local created_offensive, skipped_offensive =
      organic_history_bootstrap_create_units(
          player, homecity, staging_tile, offensive_requested,
          {"AttackFastStartUnit", "AttackStrongStartUnit", "Hut",
           "FirstBuild"})
  local created_defenders, skipped_defenders =
      organic_history_bootstrap_create_units(
          player, homecity, staging_tile, defender_requested,
          {"DefendGoodStartUnit", "DefendGood", "DefendOkStartUnit",
           "DefendOk", "FirstBuild"})
  local created = created_offensive + created_defenders
  local skipped = skipped_offensive + skipped_defenders

  organic_history_track_conquest_conversion(
      turn, actor_id, player, target_region, actor_region_cities,
      rival_region_cities, region_total, target_score, created, skipped,
      "objective", objective_id, objective.holdDefenders or 0,
      objective.holdGold or 0)
  organic_history_objective_applications[key] = applications + 1
  organic_history_objective_last_turn[key] = turn
  organic_history_objective_log(
      turn, actor_id, objective_id, "applied", "staging_support",
      string.gsub(extra, " applied=false", " applied=true")
      .. " gold=" .. gold
      .. " staging_reason=" .. string.format("%q", staging_reason)
      .. " staging_x=" .. staging_tile.x
      .. " staging_y=" .. staging_tile.y
      .. " war_target=" .. organic_history_player_id(war_target)
      .. " war_target_cities=" .. war_target_cities
      .. " war_declared=" .. tostring(war_declared)
      .. " war_state=" .. string.format("%q", war_state)
      .. " offensive_units=" .. created_offensive
      .. " defender_units=" .. created_defenders
      .. " skipped_units=" .. skipped
      .. " home_city=" .. string.format("%q", homecity.name))
end

function organic_history_player_has_region_city(player, regions)
  if player == nil then
    return false
  end

  for city in player:cities_iterate() do
    if organic_history_region_allowed(organic_history_region_for_city(city),
                                     regions) then
      return true
    end
  end

  return false
end

function organic_history_objective_settlement_site_in_regions(player, regions,
                                                             near_reason,
                                                             regional_reason,
                                                             attempted_sites)
  local candidates = {}
  local seen = {}
  attempted_sites = attempted_sites or {}

  if player ~= nil then
    for city in player:cities_iterate() do
      if organic_history_region_allowed(organic_history_region_for_city(city),
                                       regions) then
        for radius = 2, 8 do
          for tile in city.tile:circle_iterate(radius) do
            if not seen[tile.id] and not attempted_sites[tile.id]
               and tile:city() == nil
               and tile:num_units() <= 0
               and organic_history_region_allowed(
                   organic_history_region_for_tile(tile),
                   regions)
               and organic_history_can_create_city_for_player(player, tile) then
              return tile, near_reason
            end
            seen[tile.id] = true
          end
        end
      end
    end
  end

  for _, region_id in ipairs(regions or {}) do
    organic_history_append_region_emergence_candidates(candidates, seen,
                                                      region_id, player)
    for _, tile in ipairs(candidates) do
      if not attempted_sites[tile.id]
         and tile:city() == nil and tile:num_units() <= 0
         and organic_history_region_allowed(organic_history_region_for_tile(tile),
                                           regions)
         and organic_history_can_create_city_for_player(player, tile) then
        return tile, regional_reason
      end
    end
  end

  return nil, "missing_site"
end

function organic_history_objective_settlement_site(player, objective, key)
  local attempted_sites = organic_history_objective_attempted_sites[key] or {}
  local site, reason = organic_history_objective_settlement_site_in_regions(
      player, objective.targetRegions, "near_actor_city", "regional_candidate",
      attempted_sites)

  if site ~= nil then
    return site, reason
  end

  if organic_history_objective_fallback_settlement_enabled
     and objective.fallbackRegions ~= nil
     and organic_history_player_has_region_city(player, objective.targetRegions) then
    return organic_history_objective_settlement_site_in_regions(
        player, objective.fallbackRegions, "near_fallback_city",
        "fallback_regional_candidate", attempted_sites)
  end

  return nil, reason
end

function organic_history_check_settlement_objective(turn, actor_id, objective)
  local player = organic_history_player_for_actor_id(actor_id)
  local objective_id = objective.id or "unknown"
  local cities = 0
  if player ~= nil then
    cities = player:num_cities()
  end
  local birth_turn = organic_history_actor_birth_turn(actor_id, turn)
  local age = math.max(0, turn - birth_turn)
  local key = organic_history_objective_key(actor_id, objective)
  local applications = organic_history_objective_applications[key] or 0
  local max_applications = objective.maxApplications or 1
  local cooldown = objective.cooldownTurns or 20
  local last_turn = organic_history_objective_last_turn[key] or -999999
  local start_age = objective.startTurnAfterBirth or 0
  local duration = objective.durationTurns or 9999
  local extra = "type=" .. string.format("%q", objective.type or "unknown")
      .. " age=" .. age
      .. " start_age=" .. start_age
      .. " duration=" .. duration
      .. " cities=" .. cities
      .. " target_cities=" .. (objective.targetCities or -1)
      .. " applications=" .. applications
      .. " max_applications=" .. max_applications
      .. " cooldown=" .. cooldown
      .. " applied=false"

  if player == nil or not player.is_alive or cities <= 0 then
    organic_history_objective_log(turn, actor_id, objective_id, "skip",
                                  "missing_actor", extra)
    return
  elseif age < start_age then
    organic_history_objective_log(turn, actor_id, objective_id, "skip",
                                  "before_window", extra)
    return
  elseif age > start_age + duration then
    organic_history_objective_log(turn, actor_id, objective_id, "protected",
                                  "after_window", extra)
    return
  elseif objective.targetCities ~= nil and cities >= objective.targetCities then
    organic_history_objective_log(turn, actor_id, objective_id, "protected",
                                  "on_target", extra)
    return
  elseif applications >= max_applications then
    organic_history_objective_log(turn, actor_id, objective_id, "protected",
                                  "application_cap", extra)
    return
  elseif turn < last_turn + cooldown then
    organic_history_objective_log(
        turn, actor_id, objective_id, "protected", "cooldown",
        extra .. " cooldown_until=" .. (last_turn + cooldown))
    return
  end

  local site, site_reason =
      organic_history_objective_settlement_site(player, objective, key)
  local selected_region = "none"
  if site ~= nil then
    selected_region = organic_history_region_for_tile(site) or "none"
  end
  organic_history_target_overlap_log(
      turn, actor_id, "settlement_objective", objective_id,
      objective.targetRegions, selected_region)
  if site == nil then
    organic_history_objective_log(turn, actor_id, objective_id, "noop",
                                  site_reason, extra)
    return
  end

  local homecity = organic_history_burst_home_city(player)
  if homecity == nil then
    organic_history_objective_log(turn, actor_id, objective_id, "noop",
                                  "missing_home_city", extra)
    return
  end

  if objective.createCity then
    local city_name = objective.cityName or (objective_id .. " Settlement")
    if not organic_history_can_create_city_for_player(player, site) then
      organic_history_objective_log(turn, actor_id, objective_id, "noop",
                                    "illegal_city_site", extra
                                    .. " site_x=" .. site.x
                                    .. " site_y=" .. site.y)
      return
    end

    if not edit.city_create(player, site, city_name, nil) then
      organic_history_objective_log(turn, actor_id, objective_id, "noop",
                                    "city_create_failed", extra
                                    .. " site_x=" .. site.x
                                    .. " site_y=" .. site.y)
      return
    end

    local new_city = organic_history_find_city_at_tile(player, site)
    local created_defenders, skipped_defenders = 0, 0
    if new_city ~= nil then
      created_defenders, skipped_defenders =
          organic_history_bootstrap_create_units(
              player, new_city, site,
              math.min(objective.defenders or 0,
                       organic_history_objective_max_units),
              {"DefendGoodStartUnit", "DefendGood", "DefendOkStartUnit",
               "DefendOk", "FirstBuild"}, 0, 1)
    end

    organic_history_objective_applications[key] = applications + 1
    organic_history_objective_last_turn[key] = turn
    organic_history_objective_attempted_sites[key] =
        organic_history_objective_attempted_sites[key] or {}
    organic_history_objective_attempted_sites[key][site.id] = true
    organic_history_objective_log(
        turn, actor_id, objective_id, "applied", "settlement_city",
        string.gsub(extra, " applied=false", " applied=true")
        .. " city=" .. string.format("%q", city_name)
        .. " site_reason=" .. string.format("%q", site_reason)
        .. " site_x=" .. site.x
        .. " site_y=" .. site.y
        .. " site_region="
        .. string.format("%q", organic_history_region_for_tile(site))
        .. " defenders=" .. created_defenders
        .. " skipped_units=" .. skipped_defenders)
    return
  end

  local gold = math.min(objective.gold or 0,
                        organic_history_objective_max_gold)
  if gold > 0 then
    edit.change_gold(player, gold)
  end

  local settlers_requested = math.min(objective.settlers or 0,
                                      organic_history_objective_max_units)
  local defender_requested = math.min(
      objective.defenders or 0,
      math.max(0, organic_history_objective_max_units - settlers_requested))
  local created_settlers, skipped_settlers =
      organic_history_bootstrap_create_units(
          player, homecity, site, settlers_requested,
          {"Cities", "Settlers", "CitiesStartUnit"}, 0, 0)
  local created_defenders, skipped_defenders =
      organic_history_bootstrap_create_units(
          player, homecity, site, defender_requested,
          {"DefendGoodStartUnit", "DefendGood", "DefendOkStartUnit",
           "DefendOk", "FirstBuild"}, 0, 1)
  organic_history_track_settler_conversion(
      turn, actor_id, player, "objective_settlement", created_settlers,
      skipped_settlers)

  organic_history_objective_applications[key] = applications + 1
  organic_history_objective_last_turn[key] = turn
  organic_history_objective_attempted_sites[key] =
      organic_history_objective_attempted_sites[key] or {}
  organic_history_objective_attempted_sites[key][site.id] = true
  organic_history_objective_log(
      turn, actor_id, objective_id, "applied", "settlement_support",
      string.gsub(extra, " applied=false", " applied=true")
      .. " gold=" .. gold
      .. " site_reason=" .. string.format("%q", site_reason)
      .. " site_x=" .. site.x
      .. " site_y=" .. site.y
      .. " site_region="
      .. string.format("%q", organic_history_region_for_tile(site))
      .. " settlers=" .. created_settlers
      .. " defenders=" .. created_defenders
      .. " skipped_units=" .. (skipped_settlers + skipped_defenders))
end

function organic_history_check_objectives(turn)
  if not (organic_history_mechanics_enabled
          and organic_history_objective_enabled
          and organic_history_large_earth_active()) then
    return
  end

  for actor_id, objectives in pairs(organic_history_active_actor_objectives()) do
    for _, objective in ipairs(objectives) do
      if objective.type == "conquest" then
        organic_history_check_conquest_objective(turn, actor_id, objective)
      elseif objective.type == "settlement" then
        organic_history_check_settlement_objective(turn, actor_id, objective)
      else
        organic_history_objective_log(
            turn, actor_id, objective.id or "unknown", "skip",
            "unsupported_objective_type",
            "type=" .. string.format("%q", objective.type or "unknown"))
      end
    end
  end
end

function organic_history_core_consolidation_log(turn, actor_id, action, reason,
                                                extra)
  log.normal('organic_history_core_consolidation turn=%d actor=%q action=%q reason=%q %s',
             turn, actor_id, action, reason, extra or "")
end

function organic_history_core_consolidation_rule(actor_id)
  local rules = {
    abbasid = {targetCities = 4, maxApplications = 2,
               regions = {"mesopotamia", "levant", "iran"},
               specs = {{51, 43, "Kufa"}, {52, 42, "Samarra"},
                        {49, 44, "Basra"}, {50, 41, "Mosul"}}},
    assyria = {targetCities = 5, maxApplications = 2,
               regions = {"mesopotamia", "levant", "anatolia", "iran"},
               specs = {{51, 37, "Nineveh"}, {49, 38, "Arbela"},
                        {52, 38, "Kalhu"}, {48, 39, "Harran"}}},
    castile = {targetCities = 3, maxApplications = 2,
               regions = {"iberia"},
               specs = {{27, 33, "Cordoba"}, {25, 34, "Seville"},
                        {24, 31, "Leon"}, {26, 31, "Burgos"}}},
    ming = {targetCities = 5, maxApplications = 1,
            regions = {"north_china", "south_china"},
            specs = {{82, 34, "Nanjing"}, {79, 34, "Luoyang"},
                     {80, 36, "Hangzhou"}, {83, 32, "Jinan"}}},
    rome = {targetCities = 8, maxApplications = 2,
            regions = {"italy"},
            specs = {{36, 32, "Neapolis"}, {34, 31, "Veii"},
                     {35, 34, "Capua"}, {37, 33, "Tarentum"}}}
  }

  return rules[actor_id]
end

function organic_history_region_allowed(region_id, regions)
  for _, allowed in ipairs(regions or {}) do
    if region_id == allowed then
      return true
    end
  end

  return false
end

function organic_history_core_consolidation_candidates(player, rule)
  local candidates = {}
  local seen = {}

  for _, spec in ipairs(rule.specs or {}) do
    local tile = find.tile(spec[1], spec[2])
    local region_id = organic_history_region_for_tile(tile)
    if tile ~= nil and not seen[tile.id] and tile:city() == nil
       and tile:num_units() <= 0
       and organic_history_region_allowed(region_id, rule.regions)
       and organic_history_tile_can_host_emergence_city(tile) then
      table.insert(candidates, {tile = tile, name = spec[3],
                                region = region_id})
      seen[tile.id] = true
    end
  end

  if player ~= nil then
    for city in player:cities_iterate() do
      for radius = 1, 4 do
        for tile in city.tile:circle_iterate(radius) do
          local region_id = organic_history_region_for_tile(tile)
          if not seen[tile.id] and tile:city() == nil
             and tile:num_units() <= 0
             and organic_history_region_allowed(region_id, rule.regions)
             and organic_history_tile_can_host_emergence_city(tile) then
            table.insert(candidates, {
              tile = tile,
              name = "Regional Centre " .. tostring(#candidates + 1),
              region = region_id
            })
            seen[tile.id] = true
            if #candidates >= 8 then
              return candidates
            end
          end
        end
      end
    end
  end

  return candidates
end

function organic_history_check_core_consolidation_actor(turn, actor_id)
  local rule = organic_history_core_consolidation_rule(actor_id)
  if rule == nil then
    return
  end

  local player = organic_history_player_for_actor_id(actor_id)
  local cities = 0
  if player ~= nil then
    cities = player:num_cities()
  end
  local applications = organic_history_core_consolidation_applications[actor_id]
      or 0
  local last_turn = organic_history_core_consolidation_last_turn[actor_id]
      or -999999
  local max_applications = math.min(
      rule.maxApplications or 1,
      organic_history_core_consolidation_max_cities or 1)
  local cooldown = organic_history_core_consolidation_cooldown or 20
  local extra = "cities=" .. cities
      .. " target_cities=" .. (rule.targetCities or -1)
      .. " applications=" .. applications
      .. " max_applications=" .. max_applications
      .. " cooldown=" .. cooldown
      .. " applied=false"

  if player == nil or not player.is_alive or cities <= 0 then
    organic_history_core_consolidation_log(turn, actor_id, "skip",
                                           "missing_actor", extra)
    return
  elseif cities >= (rule.targetCities or 1) then
    organic_history_core_consolidation_log(turn, actor_id, "protected",
                                           "on_target", extra)
    return
  elseif applications >= max_applications then
    organic_history_core_consolidation_log(turn, actor_id, "protected",
                                           "application_cap", extra)
    return
  elseif turn < last_turn + cooldown then
    organic_history_core_consolidation_log(
        turn, actor_id, "protected", "cooldown",
        extra .. " cooldown_until=" .. (last_turn + cooldown))
    return
  end

  local candidates = organic_history_core_consolidation_candidates(player, rule)
  if #candidates <= 0 then
    organic_history_core_consolidation_log(turn, actor_id, "noop",
                                           "missing_site", extra)
    return
  end

  local candidate = nil
  for _, entry in ipairs(candidates) do
    local created = edit.city_create(player, entry.tile, entry.name, nil)
    if not created and player.city_create ~= nil then
      created = player:city_create(entry.tile, entry.name)
    end
    if created then
      candidate = entry
      break
    end
  end

  if candidate == nil then
    local first = candidates[1]
    organic_history_core_consolidation_log(
        turn, actor_id, "noop", "city_create_failed",
        extra .. " candidate_count=" .. #candidates
        .. " candidate_city=" .. string.format("%q", first.name)
        .. " candidate_region=" .. string.format("%q", first.region)
        .. " x=" .. first.tile.x .. " y=" .. first.tile.y)
    return
  end

  organic_history_core_consolidation_applications[actor_id] =
      applications + 1
  organic_history_core_consolidation_last_turn[actor_id] = turn
  organic_history_core_consolidation_log(
      turn, actor_id, "created", "regional_core_support",
      string.gsub(extra, " applied=false", " applied=true")
      .. " candidate_city=" .. string.format("%q", candidate.name)
      .. " candidate_region=" .. string.format("%q", candidate.region)
      .. " x=" .. candidate.tile.x
      .. " y=" .. candidate.tile.y
      .. " created=1")
end

function organic_history_check_core_consolidation(turn)
  if not (organic_history_mechanics_enabled
          and organic_history_core_consolidation_enabled
          and organic_history_large_earth_active()) then
    return
  end

  for _, actor_id in ipairs({"abbasid", "assyria", "castile", "ming",
                             "rome"}) do
    organic_history_check_core_consolidation_actor(turn, actor_id)
  end
end

function organic_history_try_emergence(actor_id, actor, turn)
  if organic_history_emergence_spawned[actor_id] then
    return "spawned_already"
  end
  if organic_history_actor_exists(actor) then
    return "exists"
  end
  if organic_history_emergence_blocked[actor_id] ~= nil then
    return "blocked"
  end

  if turn < (actor.earliest_turn or 0) then
    return "too_early"
  end
  if organic_history_dynastic_transfer_enabled
     and organic_history_actor_uses_dynastic_transfer(actor_id, actor) then
    local predecessor, predecessor_id =
        organic_history_dynastic_predecessor(actor, actor_id)

    if predecessor ~= nil then
      local assessment = organic_history_dynastic_transfer_assessment(
          actor_id, actor, predecessor, predecessor_id)

      if assessment.eligible and assessment.candidate_city ~= nil then
        return "dynastic_transfer_pending"
      elseif assessment.predecessor_holds_core
             and assessment.predecessor_cities
                 >= organic_history_dynastic_transfer_min_predecessor_cities
             and not assessment.eligible then
        return "dynastic_continuity"
      end
    end
  end
  if (organic_history_emergence_delayed_until[actor_id] or 0) > turn then
    return "delayed"
  end

  local attempt_key = actor_id .. ":" .. turn
  if organic_history_emergence_attempts[attempt_key] then
    return "already_attempted"
  end
  organic_history_emergence_attempts[attempt_key] = true

  local probability = actor.probability or organic_history_emergence_probability or 45
  if random(1, 100) > probability then
    return "probability"
  end

  local context = organic_history_emergence_region_context(actor_id, actor)
  local mode, weak_holder = organic_history_emergence_mode(actor_id, actor,
                                                           context)
  if organic_history_emergence_conditional_enabled then
    log.normal('organic_history_emergence_condition turn=%d actor=%q mode=%q core_region=%q total_core_cities=%d leader_actor=%q leader_share=%.3f weak_holder=%s',
               turn, actor_id, mode, context.region_id, context.total,
               context.leader_actor, context.leader_share,
               tostring(weak_holder))
    organic_history_iberian_successor_diagnostic(turn, actor_id, context)
  end

  local candidate_player = organic_history_find_actor_player(actor)
  local candidates, placement =
      organic_history_emergence_candidate_tiles(actor, candidate_player)
  organic_history_iberian_site_diagnostic(turn, actor_id, actor, context,
                                          candidates, placement)
  if placement == "missing_tile" then
    organic_history_emergence_blocked[actor_id] = "missing_tile"
    return "missing_tile"
  end
  if #candidates <= 0 then
    if organic_history_emergence_conditional_enabled then
      organic_history_emergence_delayed_until[actor_id] =
          turn + organic_history_emergence_delay_cooldown
      return "delayed_no_site"
    end
    return placement
  end

  local player = candidate_player
  if player == nil then
    if organic_history_large_earth_active() then
      organic_history_emergence_blocked[actor_id] = "missing_dormant_player"
      return "missing_dormant_player"
    end

    local nation = find.nation_type(actor.nation)
    if nation == nil then
      organic_history_emergence_blocked[actor_id] = "missing_nation"
      return "missing_nation"
    end

    player = edit.create_player(actor.leader, nation, "classic")
  end
  if player == nil then
    organic_history_emergence_blocked[actor_id] = "create_player_failed"
    return "create_player_failed"
  end

  local spawned_tile = nil
  local target_tile = find.tile(actor.x, actor.y)
  local actual_placement = placement
  for _, candidate in ipairs(candidates) do
    if edit.city_create(player, candidate, actor.city, nil) then
      spawned_tile = candidate
      if target_tile ~= nil and candidate.id == target_tile.id then
        actual_placement = "target_tile"
      else
        actual_placement = "relocated_tile"
      end
      break
    end
  end

  if spawned_tile == nil then
    if organic_history_emergence_conditional_enabled then
      organic_history_emergence_delayed_until[actor_id] =
          turn + organic_history_emergence_delay_cooldown
      return "delayed_city_site"
    end
    return "city_create_failed"
  end

  organic_history_give_emergence_setup(player, actor)
  organic_history_apply_tech_floor(actor_id, player, actor, turn, "emergence")
  organic_history_apply_bootstrap(actor_id, player, actor, spawned_tile, turn)
  organic_history_emergence_spawned[actor_id] = true
  organic_history_actor_birth_turns[actor_id] = turn
  log.normal('organic_history_emergence turn=%d actor=%q action="spawned" mode=%q placement=%q player=%d leader=%q nation=%q city=%q x=%d y=%d target_x=%d target_y=%d core_region=%q',
             turn, actor_id, mode, actual_placement,
             organic_history_player_id(player), actor.leader, actor.nation,
             actor.city, spawned_tile.x,
             spawned_tile.y, actor.x, actor.y, actor.core_region or "unknown")
  organic_history_iberian_activation_order_log(turn, actor_id, "spawned",
                                               actual_placement)
  return "spawned"
end

function organic_history_check_emergence(turn)
  if not (organic_history_mechanics_enabled
          and organic_history_emergence_enabled
          and organic_history_large_earth_active()) then
    return
  end

  for actor_id, actor in pairs(organic_history_active_emergence_actors()) do
    local action = organic_history_try_emergence(actor_id, actor, turn)

    if action ~= "too_early" and action ~= "exists"
       and action ~= "spawned_already"
       and action ~= "delayed"
       and action ~= "already_attempted" and action ~= "spawned"
       and action ~= "blocked" then
      log.normal('organic_history_emergence turn=%d actor=%q action=%q earliest_turn=%d probability=%d',
                 turn, actor_id, action, actor.earliest_turn or 0,
                 actor.probability or organic_history_emergence_probability or 45)
    end
  end
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

function organic_history_region_in_claim_list(region_id, region_list)
  if region_id == nil or region_list == nil then
    return false
  end

  for _, claimed_region in ipairs(region_list) do
    if claimed_region == region_id then
      return true
    end
  end

  return false
end

function organic_history_region_claim_type(claims, region_id)
  if region_id == "unknown" then
    return "unknown"
  elseif claims == nil then
    return "peripheral"
  elseif organic_history_region_in_claim_list(region_id, claims.core) then
    return "core"
  elseif organic_history_region_in_claim_list(region_id, claims.historical) then
    return "historical"
  elseif organic_history_region_in_claim_list(region_id, claims.contested) then
    return "contested"
  elseif organic_history_region_in_claim_list(region_id, claims.colonial) then
    return "colonial"
  elseif organic_history_region_in_claim_list(region_id, claims.cultural) then
    return "cultural"
  elseif organic_history_region_in_claim_list(region_id, claims.respawn) then
    return "respawn"
  end

  return "peripheral"
end

function organic_history_region_group(region_id)
  if region_id == "americas" or region_id == "mesoamerica"
     or region_id == "andes" then
    return "new_world"
  elseif region_id == "east_asia" or region_id == "japan_korea"
         or region_id == "china" or region_id == "north_china"
         or region_id == "south_china" then
    return "east_asia"
  elseif region_id == "india" or region_id == "north_india"
         or region_id == "deccan_south_india" then
    return "india"
  elseif region_id == "europe" or region_id == "iberia"
         or region_id == "gaul" or region_id == "italy"
         or region_id == "balkans_aegean" then
    return "europe"
  elseif region_id == "near_east" or region_id == "anatolia"
         or region_id == "levant" or region_id == "mesopotamia"
         or region_id == "iran" then
    return "near_east"
  elseif region_id == "africa" or region_id == "nile"
         or region_id == "maghreb_punic_west" then
    return "africa"
  elseif region_id == "steppe" or region_id == "steppe_mongolia" then
    return "steppe"
  end

  return "unknown"
end

function organic_history_ocean_route(origin_group, target_group)
  if origin_group == target_group then
    return nil
  elseif origin_group == "new_world" then
    if target_group == "east_asia" or target_group == "steppe"
       or target_group == "india" then
      return "pacific"
    elseif target_group ~= "unknown" then
      return "atlantic"
    end
  elseif target_group == "new_world" then
    if origin_group == "east_asia" or origin_group == "steppe"
       or origin_group == "india" then
      return "pacific"
    elseif origin_group ~= "unknown" then
      return "atlantic"
    end
  end

  return nil
end

function organic_history_contact_label(player)
  local metadata, actor_id = organic_history_actor_metadata_for(player)

  return metadata, actor_id or "unknown"
end

function organic_history_log_arrival(turn, player, actor_id, metadata, city,
                                     region_id, region_group, city_count)
  local player_id = organic_history_player_id(player)
  local key = tostring(player_id) .. ":" .. region_id

  if organic_history_arrivals_seen[key] then
    return
  end
  organic_history_arrivals_seen[key] = true

  local claims = organic_history_active_actor_region_claims()[actor_id]
  local claim_type = organic_history_region_claim_type(claims, region_id)
  local core_region = "unknown"
  local origin_group = "unknown"
  if metadata ~= nil and metadata.core_region ~= nil then
    core_region = metadata.core_region
    origin_group = organic_history_region_group(core_region)
  end

  log.normal('organic_history_arrival turn=%d player=%d actor=%q region=%q region_group=%q city=%q city_count=%d claim_type=%q core_region=%q origin_group=%q x=%d y=%d',
             turn, player_id, actor_id, region_id, region_group, city.name,
             city_count, claim_type, core_region, origin_group, city.tile.x,
             city.tile.y)

  local route = organic_history_ocean_route(origin_group, region_group)
  if route ~= nil then
    local crossing_key = tostring(player_id) .. ":" .. route .. ":"
        .. origin_group .. ":" .. region_group
    if not organic_history_crossings_seen[crossing_key] then
      organic_history_crossings_seen[crossing_key] = true
      log.normal('organic_history_ocean_crossing turn=%d player=%d actor=%q route=%q origin_group=%q target_region=%q target_group=%q city=%q x=%d y=%d',
                 turn, player_id, actor_id, route, origin_group, region_id,
                 region_group, city.name, city.tile.x, city.tile.y)
    end
  end
end

function organic_history_log_contact(turn, region_id, first, second)
  local first_id = first.player_id
  local second_id = second.player_id
  if first_id > second_id then
    first, second = second, first
    first_id = first.player_id
    second_id = second.player_id
  end

  local key = tostring(first_id) .. ":" .. tostring(second_id)
      .. ":" .. region_id
  if organic_history_contacts_seen[key] then
    return
  end
  organic_history_contacts_seen[key] = true

  log.normal('organic_history_contact turn=%d actor_a=%q player_a=%d actor_b=%q player_b=%d region=%q kind="shared_region" actor_a_cities=%d actor_b_cities=%d',
             turn, first.actor_id, first_id, second.actor_id, second_id,
             region_id, first.cities, second.cities)
end

function organic_history_log_contact_diagnostics(turn)
  if not organic_history_contact_diagnostics_enabled
     or not organic_history_scenario_metadata_active() then
    return
  end

  local region_players = {}

  for player in players_iterate() do
    if player.is_alive then
      local metadata, actor_id = organic_history_contact_label(player)
      local player_regions = {}

      for city in player:cities_iterate() do
        local region_id = organic_history_region_for_city(city)
        local region_group = organic_history_region_group(region_id)
        local city_count = player_regions[region_id] or 0
        player_regions[region_id] = city_count + 1
        organic_history_log_arrival(turn, player, actor_id, metadata, city,
                                    region_id, region_group,
                                    player_regions[region_id])
      end

      for region_id, city_count in pairs(player_regions) do
        region_players[region_id] = region_players[region_id] or {}
        table.insert(region_players[region_id], {
          player_id = organic_history_player_id(player),
          actor_id = actor_id,
          cities = city_count
        })
      end
    end
  end

  for region_id, entries in pairs(region_players) do
    if #entries > 1 then
      for i = 1, #entries - 1 do
        for j = i + 1, #entries do
          organic_history_log_contact(turn, region_id, entries[i], entries[j])
        end
      end
    end
  end
end

function organic_history_log_claim_pressure(turn)
  if not organic_history_claim_pressure_enabled
     or not organic_history_scenario_metadata_active() then
    return
  end

  for player in players_iterate() do
    if player.is_alive then
      local metadata, actor_id = organic_history_actor_metadata_for(player)
      local claims = organic_history_active_actor_region_claims()[actor_id]
      if metadata ~= nil and claims ~= nil then
        local total = 0
        local core = 0
        local historical = 0
        local contested = 0
        local colonial = 0
        local cultural = 0
        local respawn = 0
        local peripheral = 0

        for city in player:cities_iterate() do
          local region_id = organic_history_region_for_city(city)
          local claim_type = organic_history_region_claim_type(claims, region_id)
          total = total + 1
          if claim_type == "core" then
            core = core + 1
          elseif claim_type == "historical" then
            historical = historical + 1
          elseif claim_type == "contested" then
            contested = contested + 1
          elseif claim_type == "colonial" then
            colonial = colonial + 1
          elseif claim_type == "cultural" then
            cultural = cultural + 1
          elseif claim_type == "respawn" then
            respawn = respawn + 1
          else
            peripheral = peripheral + 1
          end
        end

        if total > 0 then
          local claimed = core + historical + contested + colonial + cultural + respawn
          local core_share = core / total
          local claimed_share = claimed / total
          local overextension = peripheral / total
          local core_region = metadata.core_region or "unknown"
          local region = organic_history_region_status[core_region] or {}
          local leader = region.leader or -1
          local leader_share = region.leader_share or 0
          local core_held = leader == organic_history_player_id(player)
          local rival_pressure = core_held and 0 or (1 - leader_share)

          log.normal('organic_history_claim_pressure turn=%d player=%d actor=%q core_region=%q total_cities=%d core_cities=%d historical_cities=%d contested_cities=%d colonial_cities=%d cultural_cities=%d respawn_cities=%d peripheral_cities=%d core_city_share=%.3f claimed_city_share=%.3f overextension=%.3f core_region_leader=%d core_region_leader_share=%.3f core_region_held=%s rival_pressure=%.3f',
                     turn, organic_history_player_id(player), actor_id,
                     core_region, total, core, historical, contested, colonial,
                     cultural, respawn, peripheral, core_share, claimed_share,
                     overextension, leader, leader_share, tostring(core_held),
                     rival_pressure)
        end
      end
    end
  end
end

function organic_history_actor_birth_turn(actor_id, turn)
  if organic_history_actor_birth_turns[actor_id] ~= nil then
    return organic_history_actor_birth_turns[actor_id]
  end

  local actor = organic_history_active_emergence_actors()[actor_id]
  if actor ~= nil and actor.earliest_turn ~= nil then
    return actor.earliest_turn
  end

  return 0
end

function organic_history_lifecycle_target_range(lifecycle, age)
  if lifecycle == nil or lifecycle.targetCityCurve == nil then
    return nil, nil, "missing_curve"
  end

  local curve = lifecycle.targetCityCurve
  local window = nil
  if age >= 60 and curve.turnsAfterBirth60 ~= nil then
    window = "turnsAfterBirth60"
  elseif age >= 30 and curve.turnsAfterBirth30 ~= nil then
    window = "turnsAfterBirth30"
  elseif age >= 10 and curve.turnsAfterBirth10 ~= nil then
    window = "turnsAfterBirth10"
  end

  if window == nil then
    return nil, nil, "pre_target_window"
  end

  local target = curve[window]
  if target == nil or #target < 2 then
    return nil, nil, "invalid_curve"
  end

  return target[1], target[2], window
end

function organic_history_player_claim_counts(player, claims)
  local counts = {
    total = 0,
    core = 0,
    historical = 0,
    contested = 0,
    colonial = 0,
    cultural = 0,
    respawn = 0,
    peripheral = 0
  }

  for city in player:cities_iterate() do
    local region_id = organic_history_region_for_city(city)
    local claim_type = organic_history_region_claim_type(claims, region_id)

    counts.total = counts.total + 1
    if counts[claim_type] ~= nil then
      counts[claim_type] = counts[claim_type] + 1
    else
      counts.peripheral = counts.peripheral + 1
    end
  end

  counts.claimed = counts.core + counts.historical + counts.contested
      + counts.colonial + counts.cultural + counts.respawn
  return counts
end

function organic_history_expansion_pressure_log(turn, actor_id, action, reason,
                                                extra)
  log.normal('organic_history_expansion_pressure turn=%d actor=%q action=%q reason=%q %s',
             turn, actor_id, action, reason, extra or "")
end

function organic_history_check_expansion_pressure_player(turn, player, actor_id,
                                                        metadata)
  local lifecycle_type, lifecycle = organic_history_actor_lifecycle(actor_id)
  local claims = organic_history_active_actor_region_claims()[actor_id]

  if lifecycle == nil or claims == nil then
    return
  end

  local birth_turn = organic_history_actor_birth_turn(actor_id, turn)
  local age = math.max(0, turn - birth_turn)
  local target_min, target_max, window =
      organic_history_lifecycle_target_range(lifecycle, age)
  local city_count = player:num_cities()
  local player_id = organic_history_player_id(player)
  local state_capacity = organic_history_state_capacity[player_id] or {}
  local crisis = state_capacity.crisis or 0
  local counts = organic_history_player_claim_counts(player, claims)
  local claim_gap = 0
  local below_target = false
  local under_owned_claims = false
  local economy_ok = player:gold()
      >= organic_history_expansion_pressure_min_gold
      or organic_history_bootstrap_enabled
  local stable_enough = crisis <= organic_history_expansion_pressure_crisis_limit

  if target_min ~= nil then
    below_target = city_count < target_min
    claim_gap = math.max(0, target_min - (counts.core + counts.historical))
    under_owned_claims = claim_gap > 0 or counts.core == 0
  end

  local extra = "lifecycle_type=" .. string.format("%q", lifecycle_type)
      .. " age=" .. age
      .. " birth_turn=" .. birth_turn
      .. " window=" .. string.format("%q", window)
      .. " cities=" .. city_count
      .. " target_min=" .. (target_min or -1)
      .. " target_max=" .. (target_max or -1)
      .. " core_cities=" .. counts.core
      .. " historical_cities=" .. counts.historical
      .. " claimed_cities=" .. counts.claimed
      .. " peripheral_cities=" .. counts.peripheral
      .. " claim_gap=" .. claim_gap
      .. " gold=" .. player:gold()
      .. " crisis=" .. string.format("%.3f", crisis)
      .. " below_target=" .. tostring(below_target)
      .. " under_owned_claims=" .. tostring(under_owned_claims)
      .. " economy_ok=" .. tostring(economy_ok)
      .. " stable_enough=" .. tostring(stable_enough)
      .. " core_region=" .. string.format("%q", metadata.core_region or "unknown")
      .. " applied=false"

  if target_min == nil then
    organic_history_expansion_pressure_log(turn, actor_id, "skip", window,
                                           extra)
  elseif below_target and under_owned_claims and economy_ok and stable_enough then
    organic_history_expansion_pressure_log(turn, actor_id, "candidate",
                                           "below_target_claim_gap", extra)
  elseif not stable_enough then
    organic_history_expansion_pressure_log(turn, actor_id, "protected",
                                           "collapse_crisis", extra)
  elseif not economy_ok then
    organic_history_expansion_pressure_log(turn, actor_id, "protected",
                                           "economic_escape_route", extra)
  elseif not below_target then
    organic_history_expansion_pressure_log(turn, actor_id, "protected",
                                           "on_target_curve", extra)
  else
    organic_history_expansion_pressure_log(turn, actor_id, "protected",
                                           "no_claim_gap", extra)
  end
end

function organic_history_check_expansion_pressures(turn)
  if not (organic_history_mechanics_enabled
          and organic_history_expansion_pressure_probe_enabled
          and organic_history_scenario_metadata_active()) then
    return
  end

  for player in players_iterate() do
    if player.is_alive and player:num_cities() > 0 then
      local metadata, actor_id = organic_history_actor_metadata_for(player)

      if metadata ~= nil and actor_id ~= nil then
        organic_history_check_expansion_pressure_player(turn, player, actor_id,
                                                       metadata)
      end
    end
  end
end

function organic_history_collapse_risk_for(player, actor_id, claims)
  local player_id = organic_history_player_id(player)
  local state = organic_history_state_capacity[player_id] or {}
  local mandate = organic_history_mandates[player_id] or {}
  local total = 0
  local core = 0
  local claimed = 0
  local peripheral = 0
  local occupied_core = 0
  local city_details = {}

  for city in player:cities_iterate() do
    local region_id = organic_history_region_for_city(city)
    local claim_type = organic_history_region_claim_type(claims, region_id)
    total = total + 1
    if claim_type == "core" then
      core = core + 1
    end
    if claim_type ~= "peripheral" then
      claimed = claimed + 1
    else
      peripheral = peripheral + 1
    end
    if claim_type == "core" then
      occupied_core = occupied_core + 1
    end
    table.insert(city_details, {
      city_id = organic_history_city_key(city),
      name = city.name,
      region = region_id,
      claim_type = claim_type
    })
  end

  if total <= 0 then
    return nil
  end

  local crisis = state.crisis or 0
  local mandate_score = mandate.mandate or state.mandate or 0
  local overextension = state.overextension or 0
  local peripheral_share = peripheral / total
  local core_share = core / total
  local scaling_ceiling = nil
  local scaling_stress = 0
  if organic_history_scaling_stress_enabled then
    scaling_ceiling = organic_history_scaling_stress_ceilings[actor_id]
    if scaling_ceiling ~= nil and scaling_ceiling > 0
       and total > scaling_ceiling then
      scaling_stress = organic_history_clamp(
          organic_history_scaling_stress_weight * (total / scaling_ceiling - 1),
          0, organic_history_scaling_stress_max)
    end
  end
  local collapse_risk = organic_history_clamp(crisis * 0.38
                                             + overextension * 0.24
                                             + peripheral_share * 0.22
                                             + (1 - mandate_score) * 0.16
                                             + scaling_stress,
                                             0, 1)
  local release_candidates = {}
  for _, detail in ipairs(city_details) do
    if detail.claim_type == "peripheral"
       or (collapse_risk >= 0.65 and detail.claim_type ~= "core"
           and detail.claim_type ~= "unknown") then
      table.insert(release_candidates, detail)
    end
  end

  return {
    total = total,
    core = core,
    claimed = claimed,
    peripheral = peripheral,
    occupied_core = occupied_core,
    peripheral_share = peripheral_share,
    core_share = core_share,
    crisis = crisis,
    mandate = mandate_score,
    overextension = overextension,
    collapse_risk = collapse_risk,
    scaling_stress = scaling_stress,
    scaling_ceiling = scaling_ceiling,
    release_candidates = release_candidates
  }
end

function organic_history_partial_contraction_log(turn, actor_id, action, reason,
                                                extra)
  log.normal('organic_history_partial_contraction turn=%d actor=%q action=%q reason=%q %s',
             turn, actor_id, action, reason, extra or "")
end

function organic_history_partial_contraction_rule(actor_id)
  local _, lifecycle = organic_history_actor_lifecycle(actor_id)

  if lifecycle ~= nil and lifecycle.contractionRules ~= nil then
    return lifecycle.contractionRules
  end

  return {sustainedRiskTurns = 12, minCities = 10, firstEffect = "autonomy_increase"}
end

function organic_history_partial_contraction_candidate_quality(player, risk)
  local live = 0
  local peripheral = 0
  local protected_center = 0
  local regional_successor = 0
  local safe = 0

  for _, detail in ipairs(risk.release_candidates) do
    local detail_city = organic_history_release_city_for_detail(player, detail)
    local recipient = organic_history_alive_regional_successor(player,
                                                               detail.region)

    if detail_city ~= nil then
      live = live + 1
      if detail.claim_type == "peripheral" then
        peripheral = peripheral + 1
      end
      if detail_city:is_primary_capital() or detail_city:is_capital()
         or detail_city:is_gov_center() then
        protected_center = protected_center + 1
      end
      if recipient ~= nil then
        regional_successor = regional_successor + 1
      end
      if detail.claim_type == "peripheral" and recipient ~= nil
         and not detail_city:is_primary_capital()
         and not detail_city:is_capital()
         and not detail_city:is_gov_center() then
        safe = safe + 1
      end
    end
  end

  return {
    live = live,
    peripheral = peripheral,
    protected_center = protected_center,
    regional_successor = regional_successor,
    safe = safe
  }
end

function organic_history_partial_contraction_recipient_diagnostic(turn,
                                                                  actor_id,
                                                                  player,
                                                                  risk,
                                                                  quality)
  if actor_id ~= "nubia" then
    return
  end

  local missing_recipient = 0
  local candidate_regions = {}
  local recipient_actors = {}
  local recipient_claims = {
    core = 0,
    historical = 0,
    contested = 0,
    colonial = 0,
    cultural = 0,
    respawn = 0,
    peripheral = 0,
    unknown = 0
  }

  for _, detail in ipairs(risk.release_candidates or {}) do
    candidate_regions[detail.region] =
        (candidate_regions[detail.region] or 0) + 1

    local recipient, recipient_actor_id =
        organic_history_alive_regional_successor(player, detail.region)

    if recipient == nil then
      missing_recipient = missing_recipient + 1
    else
      local recipient_actor = recipient_actor_id or "unknown"
      recipient_actors[recipient_actor] =
          (recipient_actors[recipient_actor] or 0) + 1
      local claim_type = organic_history_region_claim_type(
          organic_history_active_actor_region_claims()[recipient_actor],
          detail.region)
      recipient_claims[claim_type] =
          (recipient_claims[claim_type] or 0) + 1
    end
  end

  log.normal('organic_history_contraction_recipient turn=%d actor=%q release_candidates=%d live_candidates=%d peripheral_candidates=%d protected_center_candidates=%d regional_successor_candidates=%d safe_candidates=%d missing_recipient_candidates=%d recipient_core=%d recipient_historical=%d recipient_contested=%d recipient_colonial=%d recipient_cultural=%d recipient_respawn=%d recipient_peripheral=%d recipient_unknown=%d candidate_regions=%q recipient_actors=%q',
             turn, actor_id, #risk.release_candidates, quality.live,
             quality.peripheral, quality.protected_center,
             quality.regional_successor, quality.safe, missing_recipient,
             recipient_claims.core or 0, recipient_claims.historical or 0,
             recipient_claims.contested or 0, recipient_claims.colonial or 0,
             recipient_claims.cultural or 0, recipient_claims.respawn or 0,
             recipient_claims.peripheral or 0, recipient_claims.unknown or 0,
             organic_history_count_map_string(candidate_regions),
             organic_history_count_map_string(recipient_actors))
end

function organic_history_check_partial_contraction(turn, player, actor_id, risk)
  if not (organic_history_mechanics_enabled
          and (organic_history_partial_contraction_probe_enabled
               or organic_history_partial_contraction_enabled)) then
    return
  end

  local rule = organic_history_partial_contraction_rule(actor_id)
  local threshold = rule.riskThreshold
      or organic_history_partial_contraction_risk_threshold
  local debt_required = rule.debtRequired
      or organic_history_partial_contraction_debt_required
  local debt_bonus = rule.debtThresholdBonus
      or organic_history_partial_contraction_debt_threshold_bonus
  local debt_overextension = rule.debtOverextensionThreshold
      or organic_history_partial_contraction_debt_overextension_threshold
  local debt_peripheral = rule.debtPeripheralThreshold
      or organic_history_partial_contraction_debt_peripheral_threshold
  local max_release_cities = rule.maxReleaseCities
      or organic_history_partial_contraction_max_release_cities
  local cluster_threshold = rule.clusterRiskThreshold
      or organic_history_partial_contraction_cluster_risk_threshold
  local cluster_peripheral_share = rule.clusterPeripheralShare
      or organic_history_partial_contraction_cluster_peripheral_share
  local player_id = organic_history_player_id(player)
  local key = tostring(player_id) .. ":" .. tostring(actor_id)
  local release_count = #risk.release_candidates
  local city = risk.release_candidates[1]
  local debt = organic_history_partial_contraction_debt[key] or 0

  if organic_history_partial_contraction_debt_enabled
     and risk.overextension >= debt_overextension
     and risk.peripheral_share >= debt_peripheral
     and risk.total >= (rule.minCities or 10) then
    debt = math.min(debt_required * 2, debt + 1)
  else
    debt = math.max(0, debt - 1)
  end
  organic_history_partial_contraction_debt[key] = debt

  local effective_threshold = threshold
  if organic_history_partial_contraction_debt_enabled
     and debt >= debt_required then
    effective_threshold = math.max(0.0, threshold - debt_bonus)
  end

  local eligible = risk.collapse_risk >= effective_threshold
      and release_count > 0
      and risk.total >= (rule.minCities or 10)

  if eligible then
    organic_history_partial_contraction_streaks[key] =
        (organic_history_partial_contraction_streaks[key] or 0) + 1
  else
    organic_history_partial_contraction_streaks[key] = 0
  end

  local streak = organic_history_partial_contraction_streaks[key] or 0
  local sustained = rule.sustainedRiskTurns or 12
  local quality = organic_history_partial_contraction_candidate_quality(player,
                                                                       risk)
  organic_history_partial_contraction_recipient_diagnostic(turn, actor_id,
                                                           player, risk,
                                                           quality)
  local extra = "player=" .. player_id
      .. " total_cities=" .. risk.total
      .. " min_cities=" .. (rule.minCities or 10)
      .. " collapse_risk=" .. string.format("%.3f", risk.collapse_risk)
      .. " threshold=" .. string.format("%.3f", threshold)
      .. " effective_threshold=" .. string.format("%.3f", effective_threshold)
      .. " crisis=" .. string.format("%.3f", risk.crisis)
      .. " mandate=" .. string.format("%.3f", risk.mandate)
      .. " overextension=" .. string.format("%.3f", risk.overextension)
      .. " peripheral_share=" .. string.format("%.3f", risk.peripheral_share)
      .. " overextension_debt=" .. debt
      .. " debt_required=" .. debt_required
      .. " debt_overextension_threshold="
      .. string.format("%.3f", debt_overextension)
      .. " debt_peripheral_threshold="
      .. string.format("%.3f", debt_peripheral)
      .. " release_candidates=" .. release_count
      .. " live_release_candidates=" .. quality.live
      .. " peripheral_release_candidates=" .. quality.peripheral
      .. " regional_successor_candidates=" .. quality.regional_successor
      .. " protected_center_candidates=" .. quality.protected_center
      .. " safe_release_candidates=" .. quality.safe
      .. " max_release_cities="
      .. max_release_cities
      .. " cluster_threshold="
      .. string.format("%.3f", cluster_threshold)
      .. " cluster_peripheral_share="
      .. string.format("%.3f", cluster_peripheral_share)
      .. " streak=" .. streak
      .. " sustained_required=" .. sustained
      .. " first_effect=" .. string.format("%q", rule.firstEffect
                                           or "autonomy_increase")
      .. " applied=false"

  if city ~= nil then
    extra = extra
        .. " candidate_city=" .. string.format("%q", city.name)
        .. " candidate_region=" .. string.format("%q", city.region)
        .. " candidate_claim=" .. string.format("%q", city.claim_type)
  end

  if not eligible then
    organic_history_partial_contraction_log(turn, actor_id, "protected",
                                            "below_condition_gate", extra)
  elseif streak < sustained then
    organic_history_partial_contraction_log(turn, actor_id, "monitor",
                                            "awaiting_sustained_risk", extra)
  elseif organic_history_partial_contraction_enabled then
    organic_history_try_partial_contraction_release(turn, player, actor_id,
                                                    risk, rule, city, extra,
                                                    max_release_cities,
                                                    cluster_threshold,
                                                    cluster_peripheral_share)
  else
    organic_history_partial_contraction_log(turn, actor_id, "candidate",
                                            "sustained_contraction_pressure",
                                            extra)
  end
end

function organic_history_homeland_defense_in_window(actor_id, turn)
  local birth_turn =
      organic_history_actor_birth_turns[actor_id]
      or (organic_history_active_emergence_actors()[actor_id] or {}).earliest_turn
  if birth_turn == nil then
    return false, nil
  end
  local end_turn = birth_turn
      + organic_history_homeland_defense_era_window_turns
  if turn < birth_turn or turn > end_turn then
    return false, birth_turn
  end
  return true, birth_turn
end

function organic_history_homeland_defense_required_for(city, claim_class)
  if city == nil then
    return 0
  end
  local capital = false
  if type(city.is_primary_capital) == "function" then
    capital = capital or city:is_primary_capital()
  end
  if type(city.is_capital) == "function" then
    capital = capital or city:is_capital()
  end
  if type(city.is_gov_center) == "function" then
    capital = capital or city:is_gov_center()
  end
  if claim_class ~= "core" then
    return 0
  end
  if capital then
    return organic_history_homeland_defense_min_defenders_capital
  end
  return organic_history_homeland_defense_min_defenders
end

function organic_history_homeland_defense_defender_count(tile)
  if tile == nil then
    return 0
  end
  local count = 0
  for unit in tile:units_iterate() do
    count = count + 1
  end
  return count
end

function organic_history_homeland_defense_create_garrison(player, tile)
  local unit_type, role = organic_history_bootstrap_find_unit_type(player,
      {"DefendGoodStartUnit", "DefendGood", "DefendOkStartUnit",
       "DefendOk", "FirstBuild"})
  if unit_type == nil then
    return false, "no_unit_type"
  end
  local ok = pcall(function()
    edit.create_unit(player, tile, unit_type, 0, nil, 0)
  end)
  if not ok then
    return false, "edit_failed"
  end
  return true, unit_type:rule_name() or role or "unknown"
end

function organic_history_check_homeland_defense(turn)
  if not organic_history_homeland_defense_enabled then
    return
  end

  for actor_id, _ in pairs(organic_history_active_actor_metadata()) do
    if organic_history_homeland_defense_spawns_this_turn
       < organic_history_homeland_defense_max_per_turn then
      local in_window, birth_turn =
          organic_history_homeland_defense_in_window(actor_id, turn)
      local total = organic_history_homeland_defense_total[actor_id] or 0
      local last_turn =
          organic_history_homeland_defense_last_turn[actor_id] or -999999
      local player = nil
      local claims = nil
      if in_window
         and total < organic_history_homeland_defense_max_total_per_actor
         and turn >= last_turn + organic_history_homeland_defense_cooldown then
        player = organic_history_player_for_actor_id(actor_id)
        if player ~= nil and player.is_alive and player:num_cities() > 0 then
          claims = organic_history_active_actor_region_claims()[actor_id]
        end
      end
      if claims ~= nil then
        local target_city = nil
        local target_required = 0
        local target_current = 0
        for city in player:cities_iterate() do
          local region_id = organic_history_region_for_tile(city.tile)
          local claim_class =
              organic_history_claim_class_for(claims, region_id)
          if claim_class == "core" then
            local required = organic_history_homeland_defense_required_for(
                city, claim_class)
            local current =
                organic_history_homeland_defense_defender_count(city.tile)
            if current < required and (target_city == nil
                                       or (required - current)
                                          > (target_required - target_current)) then
              target_city = city
              target_required = required
              target_current = current
            end
          end
        end

        if target_city ~= nil then
          local ok, detail =
              organic_history_homeland_defense_create_garrison(
                  player, target_city.tile)
          if ok then
            organic_history_homeland_defense_last_turn[actor_id] = turn
            organic_history_homeland_defense_total[actor_id] = total + 1
            organic_history_homeland_defense_spawns_this_turn =
                organic_history_homeland_defense_spawns_this_turn + 1
            log.normal('organic_history_homeland_defense turn=%d actor=%q applied=true city=%q required=%d current=%d unit_type=%q birth_turn=%d era_window=%d total=%d max_total=%d',
                       turn, actor_id, target_city.name, target_required,
                       target_current, detail, birth_turn or 0,
                       organic_history_homeland_defense_era_window_turns,
                       total + 1,
                       organic_history_homeland_defense_max_total_per_actor)
          else
            log.normal('organic_history_homeland_defense turn=%d actor=%q applied=false skip_reason=%q city=%q',
                       turn, actor_id, detail, target_city.name)
          end
        end
      end
    end
  end
end

function organic_history_try_fallback_successor_spawn(parent_actor_id,
                                                     region_id, turn)
  if not organic_history_fallback_successor_spawn_enabled then
    return false, "disabled"
  end
  if organic_history_fallback_successor_spawns_this_turn
     >= organic_history_fallback_successor_max_per_turn then
    return false, "per_turn_cap"
  end

  local _, dormant_actor_id =
      organic_history_dormant_successor_for_region(parent_actor_id, region_id)
  if dormant_actor_id == nil then
    return false, "no_dormant_candidate"
  end

  local last_turn =
      organic_history_fallback_successor_last_turn[dormant_actor_id]
      or -999999
  if turn < last_turn + organic_history_fallback_successor_cooldown then
    return false, "cooldown"
  end

  local actor = organic_history_active_emergence_actors()[dormant_actor_id]
  if actor == nil then
    return false, "missing_actor_metadata"
  end

  local saved_earliest = actor.earliest_turn
  local saved_probability = actor.probability
  actor.earliest_turn = 0
  actor.probability = 100

  local outcome = organic_history_try_emergence(dormant_actor_id, actor, turn)

  actor.earliest_turn = saved_earliest
  actor.probability = saved_probability

  local spawned = (outcome == "spawned" or outcome == "exists")
  if spawned then
    organic_history_fallback_successor_spawns_this_turn =
        organic_history_fallback_successor_spawns_this_turn + 1
    organic_history_fallback_successor_last_turn[dormant_actor_id] = turn
  end

  log.normal('organic_history_fallback_successor turn=%d parent_actor=%q region=%q dormant_actor=%q outcome=%q spawned=%s spawns_this_turn=%d cooldown=%d',
             turn, parent_actor_id, region_id, dormant_actor_id,
             outcome or "unknown", tostring(spawned),
             organic_history_fallback_successor_spawns_this_turn,
             organic_history_fallback_successor_cooldown)
  return spawned, outcome
end

function organic_history_try_partial_contraction_release(turn, player, actor_id,
                                                        risk, rule, candidate,
                                                        extra, max_release_cities,
                                                        cluster_threshold,
                                                        cluster_peripheral_share)
  local player_id = organic_history_player_id(player)
  local active_extra = string.gsub(extra or "", " applied=false", " applied=true")
  local last_turn = organic_history_partial_contraction_last_turn[player_id]
      or -999999
  local cooldown = organic_history_partial_contraction_cooldown or 30
  local _, lifecycle = organic_history_actor_lifecycle(actor_id)
  local birth_protection = 0

  if lifecycle ~= nil and lifecycle.birthProtectionTurns ~= nil then
    birth_protection = lifecycle.birthProtectionTurns
  end

  local age = turn - organic_history_actor_birth_turn(actor_id, turn)
  if organic_history_partial_contraction_success_this_turn
     or organic_history_secession_success_this_turn then
    organic_history_partial_contraction_log(turn, actor_id, "protected",
                                            "turn_success_limit", active_extra)
    return false
  elseif turn < last_turn + cooldown then
    organic_history_partial_contraction_log(
        turn, actor_id, "protected", "cooldown",
        active_extra .. " cooldown_until=" .. (last_turn + cooldown))
    return false
  elseif age < birth_protection then
    organic_history_partial_contraction_log(
        turn, actor_id, "protected", "birth_protection",
        active_extra .. " age=" .. age
        .. " birth_protection_turns=" .. birth_protection)
    return false
  elseif risk.total <= (rule.minCities or 10) then
    organic_history_partial_contraction_log(turn, actor_id, "protected",
                                            "city_floor", active_extra)
    return false
  end

  local candidates = {}
  for _, detail in ipairs(risk.release_candidates) do
    local detail_city = organic_history_release_city_for_detail(player, detail)
    local recipient = organic_history_alive_regional_successor(
        player, detail.region)
    if detail_city ~= nil and detail.claim_type == "peripheral"
       and recipient ~= nil
       and not detail_city:is_primary_capital()
       and not detail_city:is_capital()
       and not detail_city:is_gov_center() then
      table.insert(candidates, {
        detail = detail,
        city = detail_city,
        recipient = recipient
      })
    end
  end

  if #candidates <= 0 then
    if organic_history_fallback_successor_spawn_enabled then
      local regions_seen = {}
      for _, detail in ipairs(risk.release_candidates) do
        local region_id = detail.region
        if region_id ~= nil and not regions_seen[region_id]
           and detail.claim_type == "peripheral" then
          regions_seen[region_id] = true
          organic_history_try_fallback_successor_spawn(actor_id, region_id,
                                                       turn)
        end
      end
    end
    organic_history_partial_contraction_log(turn, actor_id, "protected",
                                            "missing_live_regional_successor",
                                            active_extra)
    return false
  end

  local max_release = max_release_cities
      or organic_history_partial_contraction_max_release_cities or 1
  local cluster_allowed = risk.collapse_risk
      >= (cluster_threshold
          or organic_history_partial_contraction_cluster_risk_threshold)
      and risk.peripheral_share
          >= (cluster_peripheral_share
              or organic_history_partial_contraction_cluster_peripheral_share)
  if not cluster_allowed then
    max_release = 1
  end

  local min_remaining = math.max(
      organic_history_partial_contraction_min_remaining_cities or 1,
      rule.minCities or 1)
  local transfer_limit = math.min(max_release,
                                  math.max(0, risk.total - min_remaining),
                                  #candidates)
  if transfer_limit <= 0 then
    organic_history_partial_contraction_log(turn, actor_id, "protected",
                                            "city_floor", active_extra)
    return false
  end

  local transferred = 0
  local transferred_names = {}
  local successor = nil
  local successor_actor_id = nil
  local successor_name = nil
  local successor_nation_name = nil
  local first_candidate = candidates[1].detail
  local first_city = candidates[1].city
  local cluster_region = candidates[1].detail.region
  local cluster_recipient_id = organic_history_player_id(candidates[1].recipient)

  for _, entry in ipairs(candidates) do
    if transferred >= transfer_limit then
      break
    end
    if not cluster_allowed
       or (entry.detail.region == cluster_region
           and organic_history_player_id(entry.recipient)
               == cluster_recipient_id) then
      local candidate_successor, candidate_successor_actor_id,
          candidate_successor_name, candidate_successor_nation_name =
          organic_history_partial_contraction_successor(
              player, actor_id, entry.detail, entry.city, turn)
      if candidate_successor ~= nil
         and edit.transfer_city(entry.city, candidate_successor) then
        transferred = transferred + 1
        table.insert(transferred_names, entry.city.name)
        if successor == nil then
          successor = candidate_successor
          successor_actor_id = candidate_successor_actor_id
          successor_name = candidate_successor_name
          successor_nation_name = candidate_successor_nation_name
          first_candidate = entry.detail
          first_city = entry.city
        end
      end
    end
  end

  if transferred <= 0 then
    organic_history_partial_contraction_log(
        turn, actor_id, "noop", "transfer_failed",
        active_extra .. " transfer_limit=" .. transfer_limit)
    return false
  end

  organic_history_partial_contraction_last_turn[player_id] = turn
  organic_history_partial_contraction_success_this_turn = true
  organic_history_secession_success_this_turn = true
  organic_history_civil_war_success_this_turn = true
  organic_history_partial_contraction_log(
      turn, actor_id, "released",
      transferred > 1 and "bounded_cluster_release" or "single_city_release",
      active_extra .. " successor=" .. organic_history_player_id(successor)
      .. " successor_actor=" .. string.format("%q", successor_actor_id or "none")
      .. " successor_name=" .. string.format("%q", successor_name)
      .. " successor_nation=" .. string.format("%q", successor_nation_name)
      .. " city=" .. string.format("%q", first_city.name)
      .. " city_region=" .. string.format("%q", first_candidate.region)
      .. " city_claim=" .. string.format("%q", first_candidate.claim_type)
      .. " cluster_allowed=" .. tostring(cluster_allowed)
      .. " cluster_region=" .. string.format("%q", cluster_region)
      .. " transfer_limit=" .. transfer_limit
      .. " transferred=" .. transferred
      .. " transferred_cities="
      .. string.format("%q", table.concat(transferred_names, "|")))
  return true
end

function organic_history_partial_contraction_successor(player, actor_id,
                                                       candidate, city, turn)
  local region_leader, region_actor_id =
      organic_history_alive_regional_successor(player, candidate.region)

  if region_leader ~= nil then
    return region_leader, region_actor_id, organic_history_player_name(region_leader),
           organic_history_rule_name(region_leader.nation)
  end

  if organic_history_large_earth_active() then
    return nil, nil, nil, nil
  end

  local successor_name = organic_history_successor_name(player, turn, city)
  local successor_nation, successor_nation_name =
      organic_history_successor_nation(player)
  local successor = edit.create_player(successor_name, successor_nation,
                                       "classic")

  return successor, nil, successor_name, successor_nation_name
end

function organic_history_dormant_successor_for_region(parent_actor_id,
                                                      region_id)
  local best_player = nil
  local best_actor_id = nil
  local best_score = 999
  local scores = {core = 1, historical = 2, contested = 3, colonial = 4,
                  cultural = 5, respawn = 6}

  for candidate_actor_id, actor in pairs(organic_history_active_emergence_actors()) do
    if candidate_actor_id ~= parent_actor_id then
      local candidate_player = organic_history_find_actor_player(actor)
      local claims = organic_history_active_actor_region_claims()[candidate_actor_id]
      local claim_type = organic_history_region_claim_type(claims, region_id)
      local score = scores[claim_type]

      if candidate_player ~= nil and candidate_player:num_cities() == 0
         and score ~= nil and score < best_score then
        best_player = candidate_player
        best_actor_id = candidate_actor_id
        best_score = score
      end
    end
  end

  return best_player, best_actor_id
end

function organic_history_release_city_for_detail(player, detail)
  if player == nil or detail == nil then
    return nil
  end

  for city in player:cities_iterate() do
    if detail.city_id ~= nil
       and organic_history_city_key(city) == tostring(detail.city_id) then
      return city
    elseif city.name == detail.name
           and organic_history_region_for_city(city) == detail.region then
      return city
    end
  end

  return nil
end

function organic_history_log_collapse_diagnostics(turn)
  if not organic_history_collapse_diagnostics_enabled
     or not organic_history_scenario_metadata_active() then
    return
  end

  for player in players_iterate() do
    if player.is_alive then
      local metadata, actor_id = organic_history_actor_metadata_for(player)
      local claims = organic_history_active_actor_region_claims()[actor_id]
      if metadata ~= nil and claims ~= nil then
        local risk = organic_history_collapse_risk_for(player, actor_id, claims)
        if risk ~= nil then
          log.normal('organic_history_collapse turn=%d player=%d actor=%q status="diagnostic" cities=%d core_cities=%d claimed_cities=%d peripheral_cities=%d core_share=%.3f peripheral_share=%.3f mandate=%.3f crisis=%.3f overextension=%.3f scaling_stress=%.3f collapse_risk=%.3f release_candidates=%d',
                     turn, organic_history_player_id(player), actor_id,
                     risk.total, risk.core, risk.claimed, risk.peripheral,
                     risk.core_share, risk.peripheral_share, risk.mandate,
                     risk.crisis, risk.overextension, risk.scaling_stress,
                     risk.collapse_risk,
                     #risk.release_candidates)
          organic_history_check_partial_contraction(turn, player, actor_id,
                                                    risk)
          for _, candidate in ipairs(risk.release_candidates) do
            log.normal('organic_history_collapse_candidate turn=%d player=%d actor=%q city=%q region=%q claim_type=%q collapse_risk=%.3f',
                       turn, organic_history_player_id(player), actor_id,
                       candidate.name, candidate.region, candidate.claim_type,
                       risk.collapse_risk)
          end
        end
      end
    end
  end
end

function organic_history_log_flavor_diagnostics(turn)
  if not organic_history_flavor_diagnostics_enabled
     or not organic_history_scenario_metadata_active() then
    return
  end

  for player in players_iterate() do
    if player.is_alive then
      local metadata, actor_id = organic_history_actor_metadata_for(player)
      local flavor = organic_history_active_actor_flavor_diagnostics()[actor_id]
      if metadata ~= nil and flavor ~= nil then
        local claims = organic_history_active_actor_region_claims()[actor_id]
        local collapse = organic_history_collapse_risk_for(player, actor_id,
                                                           claims or {})
        local policy_hints = flavor.policy_hints or {}
        local uhv_diagnostics = flavor.uhv_diagnostics or {}
        local core_share = collapse and collapse.core_share or 0
        local collapse_risk = collapse and collapse.collapse_risk or 0

        for _, diagnostic in ipairs(uhv_diagnostics) do
          log.normal('organic_history_flavor turn=%d player=%d actor=%q kind="uhv" diagnostic=%q core_share=%.3f collapse_risk=%.3f',
                     turn, organic_history_player_id(player), actor_id,
                     diagnostic, core_share, collapse_risk)
        end
        for _, hint in ipairs(policy_hints) do
          log.normal('organic_history_flavor turn=%d player=%d actor=%q kind="policy" diagnostic=%q core_share=%.3f collapse_risk=%.3f',
                     turn, organic_history_player_id(player), actor_id,
                     hint, core_share, collapse_risk)
        end
      end
    end
  end
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

  for _, region_id in ipairs(organic_history_active_region_order()) do
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

  for _, region_id in ipairs(organic_history_active_region_order()) do
    local region = regions[region_id]
    local region_def = organic_history_active_regions()[region_id]
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
  local metadata, actor_id = organic_history_actor_metadata_for(player)
  local options = {
    rome = {"Western Roman", "Italian", "Byzantine", "Roman"},
    persia = {"Elamite", "Ottoman", "Persian"},
    egypt = {"Mamluk", "Egyptian Arab", "Egyptian"},
    sumer = {"Babylonian", "Assyrian", "Sumerian"},
    china = {"Manchu", "Korean", "Chinese"},
    india = {"Mughal", "Chola", "Indian"},
    greece = {"Hellenic", "Greek"},
    franks = {"Frankish", "French"},
    abbasid = {"Arab", "Mamluk"},
    chola = {"Chola", "Mughal", "Indian"},
    song = {"Korean", "Manchu", "Chinese"},
    steppe = {"Mongol", "Tatar"},
    castile = {"Castilian", "Spanish"},
    portugal = {"Portuguese"},
    venice = {"Venetian", "Italian"},
    ottoman = {"Ottoman", "Turkish", "Persian"},
    ming = {"Manchu", "Korean", "Chinese"},
    aztec = {"Mayan", "Aztec"},
    inca = {"Inca", "Mayan"}
  }

  if find ~= nil and find.nation_type ~= nil then
    local candidates = options[actor_id] or {}

    if metadata ~= nil and metadata.successor_nation ~= nil then
      table.insert(candidates, metadata.successor_nation)
    end
    table.insert(candidates, organic_history_rule_name(player.nation))
    table.insert(candidates, "Confederate")
    table.insert(candidates, "Barbarian")
    table.insert(candidates, "Pirate")

    for _, nation_name in ipairs(candidates) do
      local nation = find.nation_type(nation_name)

      if nation ~= nil and not organic_history_nation_in_use(nation_name) then
        return nation, organic_history_rule_name(nation)
      end
    end
  end

  return player.nation, organic_history_rule_name(player.nation)
end

function organic_history_nation_in_use(nation_name)
  for other in players_iterate() do
    if other.nation ~= nil
       and organic_history_rule_name(other.nation) == nation_name then
      return true
    end
  end

  return false
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
  elseif organic_history_large_earth_active() and organic_history_emergence_enabled then
    organic_history_secession_log("secession_candidate", turn, player, stress,
                                  'eligible=false reason="global_emergence_deferred"')
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

function organic_history_player_for_actor_id(actor_id)
  if actor_id == nil then
    return nil
  end

  for player in players_iterate() do
    local _, player_actor_id = organic_history_actor_metadata_for(player)

    if player_actor_id == actor_id then
      return player
    end
  end

  return nil
end

function organic_history_player_by_id(player_id)
  if player_id == nil or player_id < 0 then
    return nil
  end

  for player in players_iterate() do
    if organic_history_player_id(player) == player_id then
      return player
    end
  end

  return nil
end

function organic_history_dynastic_transfer_log(turn, actor_id, action, reason,
                                              extra)
  log.normal('organic_history_dynastic_transfer turn=%d actor=%q action=%q reason=%q %s',
             turn, actor_id, action, reason, extra or "")
end

function organic_history_lineage_handoff_log(turn, actor_id, action, reason,
                                             extra)
  if actor_id ~= "song" and actor_id ~= "ming" then
    return
  end

  log.normal('organic_history_lineage_handoff turn=%d lineage="china" actor=%q action=%q reason=%q %s',
             turn, actor_id, action, reason, extra or "")
end

function organic_history_dynastic_predecessor(actor, actor_id)
  if actor == nil or actor.predecessors == nil then
    return nil, nil
  end

  local best_predecessor = nil
  local best_predecessor_id = nil
  local best_score = -1

  for _, predecessor_id in ipairs(actor.predecessors) do
    local predecessor = organic_history_player_for_actor_id(predecessor_id)

    if predecessor ~= nil and predecessor.is_alive
       and predecessor:num_cities() > 0 then
      if actor_id == nil then
        return predecessor, predecessor_id
      end

      local assessment = organic_history_dynastic_transfer_assessment(
          actor_id, actor, predecessor, predecessor_id)
      local score = predecessor:num_cities()
      if assessment.predecessor_holds_core then
        score = score + 30
      end
      if assessment.candidate_city ~= nil then
        score = score + 60
      end
      if assessment.eligible then
        score = score + 90
      end
      score = score + assessment.region_leader_share * 10

      if score > best_score then
        best_score = score
        best_predecessor = predecessor
        best_predecessor_id = predecessor_id
      end
    end
  end

  return best_predecessor, best_predecessor_id
end

function organic_history_dynastic_transfer_assessment(actor_id, actor,
                                                     predecessor,
                                                     predecessor_id)
  local player_id = organic_history_player_id(predecessor)
  local mandate = organic_history_mandates[player_id] or {}
  local state_capacity = organic_history_state_capacity[player_id] or {}
  local target_region = actor.core_region or "unknown"
  local region = organic_history_region_status[target_region] or {}
  local holder = organic_history_player_by_id(region.leader or -1)
  local _, holder_actor_id = organic_history_actor_metadata_for(holder)
  local predecessor_cities = predecessor:num_cities()
  local predecessor_mandate = mandate.mandate or 0
  local crisis = state_capacity.crisis or 0
  local overextension = state_capacity.overextension or 0
  local low_mandate = predecessor_mandate
      <= organic_history_dynastic_transfer_low_mandate_threshold
  local crisis_pressure = crisis
      >= organic_history_dynastic_transfer_crisis_threshold
  local overextension_pressure = overextension
      >= organic_history_dynastic_transfer_overextension_threshold
  local predecessor_holds_core = region.leader == player_id
  local eligible = (low_mandate or crisis_pressure or overextension_pressure)
      and predecessor_cities >= organic_history_dynastic_transfer_min_predecessor_cities
  local candidate_cities = organic_history_dynastic_transfer_candidate_cities(
      predecessor, target_region, actor)
  local max_cities = organic_history_dynastic_transfer_max_cities or 1
  if actor ~= nil and actor.dynasticTransferMaxCities ~= nil then
    max_cities = actor.dynasticTransferMaxCities
  end
  local min_remaining =
      organic_history_dynastic_transfer_min_remaining_cities or 1
  local transfer_cap = math.min(max_cities,
                                math.max(0, predecessor_cities
                                          - min_remaining))

  return {
    eligible = eligible,
    predecessor_id = predecessor_id,
    predecessor_player = player_id,
    predecessor_cities = predecessor_cities,
    predecessor_mandate = predecessor_mandate,
    crisis = crisis,
    overextension = overextension,
    low_mandate = low_mandate,
    crisis_pressure = crisis_pressure,
    overextension_pressure = overextension_pressure,
    target_region = target_region,
    region_total = region.total_cities or 0,
    region_leader = region.leader or -1,
    region_leader_share = region.leader_share or 0,
    holder_actor_id = holder_actor_id or "none",
    predecessor_holds_core = predecessor_holds_core,
    candidate_cities = candidate_cities,
    candidate_count = #candidate_cities,
    candidate_city = candidate_cities[1],
    transfer_cap = transfer_cap,
    min_remaining_cities = min_remaining,
    transfer_mode = predecessor_holds_core and "core_inheritance"
                    or "claimant_spawn"
  }
end

function organic_history_dynastic_transfer_candidate_cities(predecessor,
                                                           target_region,
                                                           actor)
  local candidates = {}
  local seen = {}

  if predecessor == nil then
    return candidates
  end

  organic_history_append_dynastic_transfer_candidates(candidates, seen,
                                                     predecessor,
                                                     target_region)
  for _, fallback_region in ipairs(actor and actor.fallback_regions or {}) do
    organic_history_append_dynastic_transfer_candidates(candidates, seen,
                                                       predecessor,
                                                       fallback_region)
  end

  return candidates
end

function organic_history_append_dynastic_transfer_candidates(candidates, seen,
                                                            predecessor,
                                                            region_id)
  if predecessor == nil or region_id == nil then
    return
  end

  for city in predecessor:cities_iterate() do
    local city_key = organic_history_city_key(city)

    if not seen[city_key]
       and organic_history_region_for_city(city) == region_id
       and organic_history_city_safe_for_dynastic_transfer(city) then
     table.insert(candidates, city)
     seen[city_key] = true
    end
  end
end

function organic_history_dynastic_transfer_candidate_city(predecessor,
                                                          target_region)
  local candidates = organic_history_dynastic_transfer_candidate_cities(
      predecessor, target_region, nil)

  return candidates[1]
end

function organic_history_iberian_transfer_remove_starter(actor_id)
  return organic_history_iberian_transfer_remove_starter_enabled
         and (actor_id == "castile" or actor_id == "portugal")
end

function organic_history_actor_claim_type(actor_id, region_id)
  local claims = organic_history_active_actor_region_claims()[actor_id]

  return organic_history_region_claim_type(claims, region_id)
end

function organic_history_iberian_transfer_target_cities(actor_id)
  local objectives = organic_history_active_actor_objectives()[actor_id] or {}

  for _, objective in ipairs(objectives) do
    if objective.type == "settlement" and objective.targetCities ~= nil then
      return objective.targetCities
    end
  end

  return 1
end

function organic_history_other_iberian_successor_active(actor_id)
  local other_id = nil
  if actor_id == "castile" then
    other_id = "portugal"
  elseif actor_id == "portugal" then
    other_id = "castile"
  end

  local other = organic_history_player_for_actor_id(other_id)

  return other ~= nil and other.is_alive and other:num_cities() > 0
end

function organic_history_city_safe_for_dynastic_transfer(city)
  return city ~= nil
         and not city:is_primary_capital()
         and not city:is_capital()
         and not city:is_gov_center()
end

function organic_history_iberian_claimant_transfer_city(actor_id, successor)
  if not organic_history_iberian_transfer_remove_starter(actor_id) then
    return nil
  end

  for player in players_iterate() do
    if player ~= nil and player.is_alive and player:num_cities() > 1
       and (successor == nil or player.id ~= successor.id) then
      local _, holder_actor_id = organic_history_actor_metadata_for(player)

      if holder_actor_id ~= actor_id and holder_actor_id ~= "castile"
         and holder_actor_id ~= "portugal" then
        for city in player:cities_iterate() do
          if organic_history_region_for_city(city) == "iberia"
             and organic_history_city_safe_for_dynastic_transfer(city) then
            return city
          end
        end
      end
    end
  end

  return nil
end

function organic_history_activate_successor_actor(actor_id, actor, turn)
  local player = organic_history_find_actor_player(actor)
  if player == nil then
    if organic_history_large_earth_active() then
      return nil, "missing_dormant_player"
    end

    local nation = find.nation_type(actor.nation)
    if nation == nil then
      return nil, "missing_nation"
    end
    player = edit.create_player(actor.leader, nation, "classic")
  end

  if player == nil then
    return nil, "create_player_failed"
  elseif player:num_cities() > 0 then
    return player, "already_active"
  end

  local candidates, placement =
      organic_history_emergence_candidate_tiles(actor, player)
  if #candidates <= 0 then
    return nil, placement
  end

  local target_tile = find.tile(actor.x, actor.y)
  local defer_setup = organic_history_iberian_transfer_remove_starter(actor_id)
  for _, candidate in ipairs(candidates) do
    if edit.city_create(player, candidate, actor.city, nil) then
      local actual_placement = "relocated_tile"
      local starter_city = organic_history_find_city_at_tile(player, candidate)
      if target_tile ~= nil and candidate.id == target_tile.id then
        actual_placement = "target_tile"
      end
      if not defer_setup then
        organic_history_give_emergence_setup(player, actor)
        organic_history_apply_tech_floor(actor_id, player, actor, turn,
                                         "dynastic_transfer_immediate")
        organic_history_apply_bootstrap(actor_id, player, actor, candidate, turn)
      end
      organic_history_emergence_spawned[actor_id] = true
      organic_history_actor_birth_turns[actor_id] = turn
      log.normal('organic_history_emergence turn=%d actor=%q action="inherited_spawn" mode="dynastic_transfer" placement=%q player=%d leader=%q nation=%q city=%q x=%d y=%d target_x=%d target_y=%d core_region=%q',
                 turn, actor_id, actual_placement,
                 organic_history_player_id(player), actor.leader,
                 actor.nation, actor.city, candidate.x, candidate.y,
                 actor.x, actor.y, actor.core_region or "unknown")
      organic_history_iberian_activation_order_log(
          turn, actor_id, "inherited_spawn", actual_placement)
      return player, defer_setup and "activated_deferred" or "activated",
             starter_city, actual_placement
    end
  end

  return nil, "city_create_failed"
end

function organic_history_apply_dynastic_transfer(turn, actor_id, actor,
                                                 predecessor, assessment,
                                                 extra)
  local active_extra = string.gsub(extra or "", " applied=false",
                                   " applied=true")
  local city = assessment.candidate_city
  local transfer_candidates = assessment.candidate_cities or {}
  if organic_history_iberian_transfer_remove_starter(actor_id) then
    local core_candidates = {}

    for _, candidate in ipairs(transfer_candidates) do
      if organic_history_region_for_city(candidate) == actor.core_region then
        table.insert(core_candidates, candidate)
      end
    end
    transfer_candidates = core_candidates
    city = transfer_candidates[1]
    if city == nil then
      local claimant_city =
          organic_history_iberian_claimant_transfer_city(actor_id, nil)
      if claimant_city ~= nil then
        transfer_candidates = {claimant_city}
        city = claimant_city
      end
    end
  end

  if city == nil then
    organic_history_dynastic_transfer_log(turn, actor_id, "noop",
                                          "missing_transfer_city",
                                          active_extra)
    return false
  end

  local successor, activation_reason, starter_city, starter_placement =
      organic_history_activate_successor_actor(actor_id, actor, turn)
  if successor == nil then
    organic_history_emergence_delayed_until[actor_id] =
        turn + organic_history_emergence_delay_cooldown
    organic_history_dynastic_transfer_log(
        turn, actor_id, "noop", "successor_activation_failed",
        active_extra .. " activation_reason="
        .. string.format("%q", activation_reason))
    return false
  end

  local transferred = 0
  local transferred_names = {}
  local transferred_regions = {}
  local bootstrap_tile = nil
  local transfer_limit = math.min(assessment.transfer_cap or 1,
                                  #transfer_candidates)

  for _, transfer_city in ipairs(transfer_candidates) do
    if transferred >= transfer_limit then
      break
    end

    local ok = edit.transfer_city(transfer_city, successor)
    if ok then
      transferred = transferred + 1
      table.insert(transferred_names, transfer_city.name)
      table.insert(transferred_regions,
                   organic_history_region_for_city(transfer_city) or "unknown")
      if bootstrap_tile == nil and transfer_city.tile ~= nil then
        bootstrap_tile = transfer_city.tile
      end
    elseif transferred == 0 then
      organic_history_dynastic_transfer_log(
          turn, actor_id, "noop", "transfer_failed",
          active_extra .. " activation_reason="
          .. string.format("%q", activation_reason)
          .. " city=" .. string.format("%q", transfer_city.name)
          .. " successor=" .. organic_history_player_id(successor))
      return false
    end
  end

  if transferred <= 0 then
    organic_history_dynastic_transfer_log(turn, actor_id, "noop",
                                          "transfer_cap_zero", active_extra)
    return false
  end

  local starter_region = "none"
  if starter_city ~= nil then
    starter_region = organic_history_region_for_city(starter_city) or "none"
  end
  local starter_claim = organic_history_actor_claim_type(actor_id,
                                                        starter_region)
  local target_cities = organic_history_iberian_transfer_target_cities(actor_id)
  local claimed_starter_needed =
      organic_history_iberian_transfer_remove_starter(actor_id)
      and organic_history_other_iberian_successor_active(actor_id)
      and starter_claim ~= "peripheral"
      and starter_claim ~= "unknown"
      and (successor:num_cities() - 1) < target_cities
  local starter_removed = false
  if starter_city ~= nil and starter_region ~= (actor.core_region or "unknown")
     and successor:num_cities() > 1
     and not claimed_starter_needed then
    edit.remove_city(starter_city)
    starter_removed = true
  elseif bootstrap_tile == nil and starter_city ~= nil then
    bootstrap_tile = starter_city.tile
  end

  if activation_reason == "activated_deferred" then
    organic_history_give_emergence_setup(successor, actor)
    organic_history_apply_tech_floor(actor_id, successor, actor, turn,
                                     "dynastic_transfer_deferred")
    organic_history_apply_bootstrap(actor_id, successor, actor, bootstrap_tile,
                                    turn)
  end

  organic_history_dynastic_transfer_log(
      turn, actor_id, "inherited", "bounded_cluster_inheritance",
      active_extra .. " activation_reason="
      .. string.format("%q", activation_reason)
      .. " starter_placement="
      .. string.format("%q", starter_placement or "none")
      .. " starter_region="
      .. string.format("%q", starter_region)
      .. " starter_claim="
      .. string.format("%q", starter_claim)
      .. " starter_removed=" .. tostring(starter_removed)
      .. " city=" .. string.format("%q", city.name)
      .. " city_region="
      .. string.format("%q", organic_history_region_for_city(city)
                       or assessment.target_region)
      .. " successor=" .. organic_history_player_id(successor)
      .. " transferred=" .. transferred
      .. " transferred_cities="
      .. string.format("%q", table.concat(transferred_names, "|"))
      .. " transferred_regions="
      .. string.format("%q", table.concat(transferred_regions, "|")))
  return true
end

function organic_history_check_dynastic_transfer_actor(turn, actor_id, actor)
  if not organic_history_actor_uses_dynastic_transfer(actor_id, actor) then
    return
  end

  if turn < (actor.earliest_turn or 0) then
    organic_history_dynastic_transfer_log(turn, actor_id, "skip", "too_early",
                                          "earliest_turn="
                                          .. (actor.earliest_turn or 0))
    organic_history_lineage_handoff_log(turn, actor_id, "skip", "too_early",
                                        "earliest_turn="
                                        .. (actor.earliest_turn or 0))
    return
  end
  if (organic_history_emergence_delayed_until[actor_id] or 0) > turn then
    organic_history_dynastic_transfer_log(turn, actor_id, "skip", "delayed",
                                          "delayed_until="
                                          .. organic_history_emergence_delayed_until[actor_id])
    organic_history_lineage_handoff_log(
        turn, actor_id, "skip", "delayed",
        "delayed_until=" .. organic_history_emergence_delayed_until[actor_id])
    return
  end
  if organic_history_actor_exists(actor) then
    organic_history_dynastic_transfer_log(turn, actor_id, "skip",
                                          "successor_exists",
                                          'city='
                                          .. string.format("%q", actor.city))
    organic_history_lineage_handoff_log(turn, actor_id, "skip",
                                        "successor_exists",
                                        'city='
                                        .. string.format("%q", actor.city))
    return
  end

  local predecessor, predecessor_id =
      organic_history_dynastic_predecessor(actor, actor_id)
  if predecessor == nil then
    organic_history_dynastic_transfer_log(turn, actor_id, "skip",
                                          "missing_predecessor", "")
    organic_history_lineage_handoff_log(turn, actor_id, "skip",
                                        "missing_predecessor", "")
    return
  end

  local assessment = organic_history_dynastic_transfer_assessment(
      actor_id, actor, predecessor, predecessor_id)
  local extra = 'predecessor_actor='
      .. string.format("%q", assessment.predecessor_id or "unknown")
      .. " predecessor_player=" .. assessment.predecessor_player
      .. " predecessor_cities=" .. assessment.predecessor_cities
      .. " mandate=" .. string.format("%.3f", assessment.predecessor_mandate)
      .. " crisis=" .. string.format("%.3f", assessment.crisis)
      .. " overextension="
      .. string.format("%.3f", assessment.overextension)
      .. " low_mandate=" .. tostring(assessment.low_mandate)
      .. " crisis_pressure=" .. tostring(assessment.crisis_pressure)
      .. " overextension_pressure="
      .. tostring(assessment.overextension_pressure)
      .. " target_region=" .. string.format("%q", assessment.target_region)
      .. " region_total=" .. assessment.region_total
      .. " region_leader=" .. assessment.region_leader
      .. " region_leader_actor=" .. string.format("%q", assessment.holder_actor_id)
      .. " region_leader_share="
      .. string.format("%.3f", assessment.region_leader_share)
      .. " predecessor_holds_core="
      .. tostring(assessment.predecessor_holds_core)
      .. " transfer_mode=" .. string.format("%q", assessment.transfer_mode)
      .. " transfer_city="
      .. string.format("%q", assessment.candidate_city
                       and assessment.candidate_city.name or "none")
      .. " transfer_city_count=" .. assessment.candidate_count
      .. " transfer_cap=" .. assessment.transfer_cap
      .. " min_remaining_cities=" .. assessment.min_remaining_cities
      .. " transfer_city_available="
      .. (assessment.candidate_city ~= nil and 1 or 0)
      .. " applied=false"

  organic_history_lineage_handoff_log(turn, actor_id,
                                      assessment.eligible and "eligible"
                                      or "protected",
                                      assessment.eligible
                                      and "transfer_pressure"
                                      or "escape_route",
                                      extra)

  if not assessment.eligible then
    organic_history_dynastic_transfer_log(turn, actor_id, "protected",
                                          "escape_route", extra)
    return
  end

  if organic_history_dynastic_transfer_enabled then
    organic_history_apply_dynastic_transfer(turn, actor_id, actor, predecessor,
                                            assessment, extra)
  else
    organic_history_dynastic_transfer_log(turn, actor_id, "candidate",
                                          "condition_gated_pressure", extra)
  end
end

function organic_history_check_dynastic_transfers(turn)
  if not (organic_history_mechanics_enabled
          and (organic_history_dynastic_transfer_probe_enabled
               or organic_history_dynastic_transfer_enabled)
          and organic_history_large_earth_active()) then
    return
  end

  for actor_id, actor in pairs(organic_history_active_emergence_actors()) do
    organic_history_check_dynastic_transfer_actor(turn, actor_id, actor)
  end
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
  organic_history_check_containment(city)
end

function organic_history_check_containment(city)
  if not organic_history_containment_enabled then
    return
  end
  if city == nil or city.owner == nil then
    return
  end
  local _, actor_id = organic_history_actor_metadata_for(city.owner)
  if actor_id == nil then
    return
  end
  local rule = organic_history_containment_actors[actor_id]
  if rule == nil or rule.regions == nil then
    return
  end
  local region_id = organic_history_region_for_city(city)
  if region_id == nil or not rule.regions[region_id] then
    return
  end

  local foreign_held = 0
  for held in city.owner:cities_iterate() do
    if held.id ~= city.id then
      local held_region = organic_history_region_for_city(held)
      if held_region ~= nil and rule.regions[held_region] then
        foreign_held = foreign_held + 1
      end
    end
  end

  local max_foreign = rule.maxForeignCities or 3
  if foreign_held >= max_foreign then
    -- Defer removal to the next turn_begin: edit.remove_city() is unsafe inside
    -- the city_built signal callback (re-entrant, crashes the server), but safe
    -- in turn-based processing.
    table.insert(organic_history_containment_removal_queue, {
      city = city,
      owner_id = organic_history_player_id(city.owner),
      actor_id = actor_id,
      region = region_id,
      name = city.name,
    })
    log.normal('organic_history_containment turn=%d actor=%q action="queued_removal" city=%q region=%q foreign_held=%d max_foreign=%d',
               game.current_turn(), actor_id, city.name, region_id,
               foreign_held, max_foreign)
  else
    log.normal('organic_history_containment turn=%d actor=%q action="allowed" city=%q region=%q foreign_held=%d max_foreign=%d',
               game.current_turn(), actor_id, city.name, region_id,
               foreign_held, max_foreign)
  end
end

function organic_history_process_containment_queue(turn)
  if #organic_history_containment_removal_queue == 0 then
    return
  end
  local queue = organic_history_containment_removal_queue
  organic_history_containment_removal_queue = {}
  for _, entry in ipairs(queue) do
    local city = entry.city
    if city ~= nil and city.owner ~= nil
       and organic_history_player_id(city.owner) == entry.owner_id then
      log.normal('organic_history_containment turn=%d actor=%q action="removed" city=%q region=%q',
                 turn, entry.actor_id, entry.name or "?", entry.region or "?")
      edit.remove_city(city)
    else
      log.normal('organic_history_containment turn=%d actor=%q action="skipped_removal" city=%q region=%q reason="lost_or_changed"',
                 turn, entry.actor_id, entry.name or "?", entry.region or "?")
    end
  end
end

function organic_history_claim_class_for(claims, region_id)
  if claims == nil or region_id == nil or region_id == "unknown" then
    return nil
  end
  if claims.core ~= nil then
    for _, claim_region in ipairs(claims.core) do
      if claim_region == region_id then
        return "core"
      end
    end
  end
  if claims.noHistoricalConversion then
    return nil
  end
  local lookup_order = {"historical", "cultural", "colonial", "contested"}
  for _, claim_type in ipairs(lookup_order) do
    local list = claims[claim_type]
    if list ~= nil then
      for _, claim_region in ipairs(list) do
        if claim_region == region_id then
          return claim_type
        end
      end
    end
  end
  return nil
end

function organic_history_claim_conversion_gold_for(claim_class)
  if claim_class == "core" then
    return organic_history_claim_conversion_core_gold
  elseif claim_class == "historical" then
    return organic_history_claim_conversion_historical_gold
  elseif claim_class == "cultural" or claim_class == "colonial" then
    return math.floor(organic_history_claim_conversion_historical_gold / 2)
  end
  return 0
end

function organic_history_apply_claim_conversion(city, winner, loser, reason,
                                                winner_actor_id, claim_class,
                                                region_id, turn)
  if not organic_history_claim_conversion_enabled then
    return false
  end
  if city == nil or winner == nil or claim_class == nil then
    return false
  end
  if city.size ~= nil
     and city.size < organic_history_claim_conversion_min_city_size then
    log.normal('organic_history_claim_conversion turn=%d actor=%q reason=%q applied=false skip_reason="city_too_small" city=%q region=%q claim_class=%q city_size=%d',
               turn, winner_actor_id, reason or "unknown", city.name,
               region_id, claim_class, city.size)
    return false
  end

  local applied_count =
      organic_history_claim_conversion_actor_counts[winner_actor_id] or 0
  if applied_count >= organic_history_claim_conversion_max_per_actor then
    log.normal('organic_history_claim_conversion turn=%d actor=%q reason=%q applied=false skip_reason="actor_max_reached" city=%q region=%q claim_class=%q applied_count=%d max_per_actor=%d',
               turn, winner_actor_id, reason or "unknown", city.name,
               region_id, claim_class, applied_count,
               organic_history_claim_conversion_max_per_actor)
    return false
  end

  local gold = organic_history_claim_conversion_gold_for(claim_class)
  if gold > 0 then
    edit.change_gold(winner, gold)
  end

  local history_added = 0
  if organic_history_claim_conversion_history_amount > 0
     and type(city.add_history) == "function" then
    local history_bonus = organic_history_claim_conversion_history_amount
    if claim_class ~= "core" then
      history_bonus = math.floor(history_bonus / 2)
    end
    pcall(function()
      city:add_history(history_bonus)
    end)
    history_added = history_bonus
  end

  local building_created = false
  local building_name = organic_history_claim_conversion_free_building
  if building_name ~= nil and building_name ~= ""
     and type(city.create_building) == "function" then
    local impr = find.building_type(building_name)
    if impr ~= nil then
      local ok = pcall(function()
        city:create_building(impr)
      end)
      building_created = ok
    end
  end

  organic_history_claim_conversion_actor_counts[winner_actor_id] =
      applied_count + 1
  organic_history_claim_conversion_locked[city.id] = {
    unlock_turn = turn + organic_history_claim_conversion_lock_turns,
    actor_id = winner_actor_id,
    region_id = region_id,
    claim_class = claim_class,
  }

  log.normal('organic_history_claim_conversion turn=%d actor=%q reason=%q applied=true claim_class=%q region=%q city=%q city_size=%d gold=%d history_added=%d building=%q building_created=%s loser=%d winner=%d unlock_turn=%d actor_applied_count=%d',
             turn, winner_actor_id, reason or "unknown", claim_class,
             region_id, city.name, city.size or 0, gold, history_added,
             building_name or "none", tostring(building_created),
             organic_history_player_id(loser),
             organic_history_player_id(winner),
             turn + organic_history_claim_conversion_lock_turns,
             applied_count + 1)
  return true
end

function organic_history_city_transferred(city, loser, winner, reason)
  local turn = game.current_turn()
  log.normal('organic_history_event type=city_transferred turn=%d city=%q loser=%d winner=%d reason=%q',
             turn, city.name, organic_history_player_id(loser),
             organic_history_player_id(winner), reason)

  if not organic_history_claim_conversion_enabled then
    return
  end

  local _, winner_actor_id = organic_history_actor_metadata_for(winner)
  if winner_actor_id == nil then
    log.normal('organic_history_claim_conversion turn=%d actor="unknown" reason=%q applied=false skip_reason="no_winner_actor" city=%q winner=%d',
               turn, reason or "unknown", city.name,
               organic_history_player_id(winner))
    return
  end

  local claims =
      organic_history_active_actor_region_claims()[winner_actor_id]
  if claims == nil then
    log.normal('organic_history_claim_conversion turn=%d actor=%q reason=%q applied=false skip_reason="no_winner_claims" city=%q',
               turn, winner_actor_id, reason or "unknown", city.name)
    return
  end

  local region_id, _ = organic_history_region_for_tile(city.tile)
  local claim_class = organic_history_claim_class_for(claims, region_id)
  if claim_class == nil then
    log.normal('organic_history_claim_conversion turn=%d actor=%q reason=%q applied=false skip_reason="no_claim_match" city=%q region=%q',
               turn, winner_actor_id, reason or "unknown", city.name, region_id)
    return
  end

  organic_history_apply_claim_conversion(city, winner, loser, reason,
                                         winner_actor_id, claim_class,
                                         region_id, turn)
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
