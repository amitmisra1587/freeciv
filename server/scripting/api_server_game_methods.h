/***********************************************************************
 Freeciv - Copyright (C) 1996-2015 - Freeciv Development Team
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
***********************************************************************/

#ifndef FC__API_SERVER_GAME_METHODS_H
#define FC__API_SERVER_GAME_METHODS_H

/* common/scriptcore */
#include "luascript_types.h"

/* server/scripting */
#include "api_server_edit.h"

/* Server-only methods added to the modules defined in
 * the common tolua_game.pkg. */

int api_methods_player_trait(lua_State *L, Player *pplayer,
                             const char *tname);
int api_methods_player_trait_base(lua_State *L, Player *pplayer,
                                  const char *tname);
int api_methods_player_trait_current_mod(lua_State *L, Player *pplayer,
                                         const char *tname);
void api_methods_player_lose(lua_State *L, Player *pplayer, Player *looter);

int api_methods_nation_trait_min(lua_State *L, Nation_Type *pnation,
                                 const char *tname);
int api_methods_nation_trait_max(lua_State *L, Nation_Type *pnation,
                                 const char *tname);
int api_methods_nation_trait_default(lua_State *L, Nation_Type *pnation,
                                     const char *tname);
int api_methods_player_tech_bulbs(lua_State *L, Player *pplayer,
                                  Tech_Type *tech);
int api_methods_player_free_bulbs(lua_State *L, Player *pplayer);
int api_methods_tag_score(lua_State *L, Player *pplayer, const char *tag);

int api_methods_love(lua_State *L, Player *pplayer, Player *towards);
bool api_methods_player_is_ai(lua_State *L, Player *pplayer);
bool api_methods_player_is_away(lua_State *L, Player *pplayer);
void api_methods_add_love(lua_State *L, Player *pplayer, Player *towards, int amount);
void api_methods_cancel_pact(lua_State *L, Player *pplayer, Player *towards);
const char *api_methods_ai_strategy_posture(lua_State *L, Player *pplayer);
bool api_methods_ai_strategy_active(lua_State *L, Player *pplayer);
const char *api_methods_ai_strategy_source(lua_State *L, Player *pplayer);
const char *api_methods_ai_strategy_objective(lua_State *L, Player *pplayer);
Player *api_methods_ai_strategy_target(lua_State *L, Player *pplayer);
City *api_methods_ai_strategy_city(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_intensity(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_war_bonus(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_conquest_pct(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_expires(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_campaign(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_integration_until(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_started(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_war_started(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_units_lost(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_units_killed(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_start_units(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_start_cities(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_city_delta(lua_State *L, Player *pplayer);
int api_methods_ai_strategy_peak_intensity(lua_State *L, Player *pplayer);

#endif /* FC__API_SERVER_GAME_METHODS_H */
