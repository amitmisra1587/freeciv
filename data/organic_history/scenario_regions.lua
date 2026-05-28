-- Historical region boxes for the organic-history earth_small_v0 fixtures.
-- The ruleset script keeps an inline copy so the secure Lua runtime does not
-- need filesystem access; this file is the data source for humans/tools.

organic_history_scenario_regions = {
  africa = {name = "Africa", x_min = 38, x_max = 55, y_min = 27, y_max = 49},
  americas = {name = "Americas", x_min = 0, x_max = 29, y_min = 8, y_max = 43},
  china = {name = "China", x_min = 63, x_max = 74, y_min = 16, y_max = 30},
  europe = {name = "Europe", x_min = 36, x_max = 50, y_min = 10, y_max = 25},
  india = {name = "India", x_min = 55, x_max = 64, y_min = 23, y_max = 34},
  near_east = {name = "Near East", x_min = 47, x_max = 58, y_min = 22, y_max = 33},
  steppe = {name = "Steppe", x_min = 48, x_max = 69, y_min = 6, y_max = 18}
}
