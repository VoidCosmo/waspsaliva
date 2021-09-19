/*
Minetest
Copyright (C) 2017 Dumbeldor, Vincent Glize <vincent.glize@live.fr>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#include "l_clientobject.h"
#include "l_localplayer.h"
#include "l_internal.h"
#include "lua_api/l_item.h"
#include "script/common/c_converter.h"
#include "client/localplayer.h"
#include "hud.h"
#include "common/c_content.h"
#include "client/client.h"
#include "client/content_cao.h"
#include "client/game.h"
#include "l_clientobject.h"
#include <vector>

LuaLocalPlayer::LuaLocalPlayer(LocalPlayer *m) : m_localplayer(m)
{
}

void LuaLocalPlayer::create(lua_State *L, LocalPlayer *m)
{
	lua_getglobal(L, "core");
	luaL_checktype(L, -1, LUA_TTABLE);
	int objectstable = lua_gettop(L);
	lua_getfield(L, -1, "localplayer");

	// Duplication check
	if (lua_type(L, -1) == LUA_TUSERDATA) {
		lua_pop(L, 1);
		return;
	}

	LuaLocalPlayer *o = new LuaLocalPlayer(m);
	*(void **)(lua_newuserdata(L, sizeof(void *))) = o;
	luaL_getmetatable(L, className);
	lua_setmetatable(L, -2);

	lua_pushvalue(L, lua_gettop(L));
	lua_setfield(L, objectstable, "localplayer");
}

int LuaLocalPlayer::l_get_velocity(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	push_v3f(L, player->getSpeed() / BS);
	return 1;
}

int LuaLocalPlayer::l_set_velocity(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	v3f pos = checkFloatPos(L, 2);
	player->setSpeed(pos);

	return 0;
}

int LuaLocalPlayer::l_get_yaw(lua_State *L)
{
	lua_pushnumber(L, wrapDegrees_0_360(g_game->cam_view.camera_yaw));
	return 1;
}

int LuaLocalPlayer::l_get_pitch(lua_State *L)
{
	lua_pushnumber(L, -wrapDegrees_180(g_game->cam_view.camera_pitch) );
	return 1;
}

int LuaLocalPlayer::l_get_hp(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_pushinteger(L, player->hp);
	return 1;
}

int LuaLocalPlayer::l_get_name(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_pushstring(L, player->getName());
	return 1;
}

// get_wield_index(self)
int LuaLocalPlayer::l_get_wield_index(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_pushinteger(L, player->getWieldIndex() + 1);
	return 1;
}

// set_wield_index(self)
int LuaLocalPlayer::l_set_wield_index(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	u32 index = luaL_checkinteger(L, 2) - 1;

	player->setWieldIndex(index);
	g_game->processItemSelection(&g_game->runData.new_playeritem);
	ItemStack selected_item, hand_item;
	ItemStack &tool_item = player->getWieldedItem(&selected_item, &hand_item);
	g_game->camera->wield(tool_item);
	return 0;
}

// get_wielded_item(self)
int LuaLocalPlayer::l_get_wielded_item(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	ItemStack selected_item;
	player->getWieldedItem(&selected_item, nullptr);
	LuaItemStack::create(L, selected_item);
	return 1;
}

int LuaLocalPlayer::l_is_attached(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_pushboolean(L, player->getParent() != nullptr);
	return 1;
}

int LuaLocalPlayer::l_is_touching_ground(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_pushboolean(L, player->touching_ground);
	return 1;
}

int LuaLocalPlayer::l_is_in_liquid(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_pushboolean(L, player->in_liquid);
	return 1;
}

int LuaLocalPlayer::l_is_in_liquid_stable(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_pushboolean(L, player->in_liquid_stable);
	return 1;
}

int LuaLocalPlayer::l_get_liquid_viscosity(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_pushinteger(L, player->liquid_viscosity);
	return 1;
}

int LuaLocalPlayer::l_is_climbing(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_pushboolean(L, player->is_climbing);
	return 1;
}

int LuaLocalPlayer::l_swimming_vertical(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_pushboolean(L, player->swimming_vertical);
	return 1;
}

// get_physics_override(self)
int LuaLocalPlayer::l_get_physics_override(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	push_physics_override(L, player->physics_override_speed, player->physics_override_jump, player->physics_override_gravity, player->physics_override_sneak, player->physics_override_sneak_glitch, player->physics_override_new_move);

	return 1;
}

// set_physics_override(self, override)
int LuaLocalPlayer::l_set_physics_override(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	player->physics_override_speed = getfloatfield_default(
			L, 2, "speed", player->physics_override_speed);
	player->physics_override_jump = getfloatfield_default(
			L, 2, "jump", player->physics_override_jump);
	player->physics_override_gravity = getfloatfield_default(
			L, 2, "gravity", player->physics_override_gravity);
	player->physics_override_sneak = getboolfield_default(
			L, 2, "sneak", player->physics_override_sneak);
	player->physics_override_sneak_glitch = getboolfield_default(
			L, 2, "sneak_glitch", player->physics_override_sneak_glitch);
	player->physics_override_new_move = getboolfield_default(
			L, 2, "new_move", player->physics_override_new_move);

	return 0;
}

int LuaLocalPlayer::l_get_last_pos(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	push_v3f(L, player->last_position / BS);
	return 1;
}

int LuaLocalPlayer::l_get_last_velocity(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	push_v3f(L, player->last_speed);
	return 1;
}

int LuaLocalPlayer::l_get_last_look_vertical(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_pushnumber(L, -1.0 * player->last_pitch * core::DEGTORAD);
	return 1;
}

int LuaLocalPlayer::l_get_last_look_horizontal(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_pushnumber(L, (player->last_yaw + 90.) * core::DEGTORAD);
	return 1;
}

// get_control(self)
int LuaLocalPlayer::l_get_control(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);
	const PlayerControl &c = player->getPlayerControl();

	auto set = [L] (const char *name, bool value) {
		lua_pushboolean(L, value);
		lua_setfield(L, -2, name);
	};

	lua_createtable(L, 0, 12);
	set("up", c.up);
	set("down", c.down);
	set("left", c.left);
	set("right", c.right);
	set("jump", c.jump);
	set("aux1", c.aux1);
	set("sneak", c.sneak);
	set("zoom", c.zoom);
	set("dig", c.dig);
	set("place", c.place);

	return 1;
}

// get_breath(self)
int LuaLocalPlayer::l_get_breath(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_pushinteger(L, player->getBreath());
	return 1;
}

// get_pos(self)
int LuaLocalPlayer::l_get_pos(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	push_v3f(L, player->getPosition() / BS);
	return 1;
}

// set_pos(self, pos)
int LuaLocalPlayer::l_set_pos(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	v3f pos = checkFloatPos(L, 2);
	player->setPosition(pos);
	getClient(L)->sendPlayerPos(true);
	return 0;
}

int LuaLocalPlayer::l_set_yaw(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);
	f32 p = (float) luaL_checknumber(L, 2);
	//* 0.01745329252f;
	g_game->cam_view.camera_yaw = p;
	g_game->cam_view_target.camera_yaw = p;
	player->setYaw(p);
	return 0;
}

int LuaLocalPlayer::l_set_pitch(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);
	f32 p = (float) luaL_checknumber(L, 2);
	//* 0.01745329252f ;
	g_game->cam_view.camera_pitch = p;
	g_game->cam_view_target.camera_pitch = p;
	player->setPitch(p);
	return 0;
}

// get_movement_acceleration(self)
int LuaLocalPlayer::l_get_movement_acceleration(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_newtable(L);
	lua_pushnumber(L, player->movement_acceleration_default);
	lua_setfield(L, -2, "default");

	lua_pushnumber(L, player->movement_acceleration_air);
	lua_setfield(L, -2, "air");

	lua_pushnumber(L, player->movement_acceleration_fast);
	lua_setfield(L, -2, "fast");

	return 1;
}

// get_movement_speed(self)
int LuaLocalPlayer::l_get_movement_speed(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_newtable(L);
	lua_pushnumber(L, player->movement_speed_walk);
	lua_setfield(L, -2, "walk");

	lua_pushnumber(L, player->movement_speed_crouch);
	lua_setfield(L, -2, "crouch");

	lua_pushnumber(L, player->movement_speed_fast);
	lua_setfield(L, -2, "fast");

	lua_pushnumber(L, player->movement_speed_climb);
	lua_setfield(L, -2, "climb");

	lua_pushnumber(L, player->movement_speed_jump);
	lua_setfield(L, -2, "jump");

	return 1;
}

// get_movement(self)
int LuaLocalPlayer::l_get_movement(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	lua_newtable(L);

	lua_pushnumber(L, player->movement_liquid_fluidity);
	lua_setfield(L, -2, "liquid_fluidity");

	lua_pushnumber(L, player->movement_liquid_fluidity_smooth);
	lua_setfield(L, -2, "liquid_fluidity_smooth");

	lua_pushnumber(L, player->movement_liquid_sink);
	lua_setfield(L, -2, "liquid_sink");

	lua_pushnumber(L, player->movement_gravity);
	lua_setfield(L, -2, "gravity");

	return 1;
}

// get_armor_groups(self)
int LuaLocalPlayer::l_get_armor_groups(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);
	push_groups(L, player->getCAO()->getGroups());
	return 1;
}

// hud_add(self, form)
int LuaLocalPlayer::l_hud_add(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	HudElement *elem = new HudElement;
	read_hud_element(L, elem);

	u32 id = player->addHud(elem);
	if (id == U32_MAX) {
		delete elem;
		return 0;
	}
	lua_pushnumber(L, id);
	return 1;
}

// hud_remove(self, id)
int LuaLocalPlayer::l_hud_remove(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);
	u32 id = luaL_checkinteger(L, 2);
	HudElement *element = player->removeHud(id);
	if (!element)
		lua_pushboolean(L, false);
	else
		lua_pushboolean(L, true);
	delete element;
	return 1;
}

// hud_change(self, id, stat, data)
int LuaLocalPlayer::l_hud_change(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	u32 id = luaL_checkinteger(L, 2);

	HudElement *element = player->getHud(id);
	if (!element)
		return 0;

	void *unused;
	read_hud_change(L, element, &unused);

	lua_pushboolean(L, true);
	return 1;
}

// hud_get(self, id)
int LuaLocalPlayer::l_hud_get(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);

	u32 id = luaL_checkinteger(L, -1);

	HudElement *e = player->getHud(id);
	if (!e) {
		lua_pushnil(L);
		return 1;
	}

	push_hud_element(L, e);
	return 1;
}

// get_nearby_objects(self, radius)
int LuaLocalPlayer::l_get_nearby_objects(lua_State *L)
{
	// should this be a double?
	float radius = readParam<float>(L, 1) * BS;
	std::vector<DistanceSortedActiveObject> objs;

	ClientEnvironment &env = getClient(L)->getEnv();
	v3f pos = env.getLocalPlayer()->getPosition();
	env.getActiveObjects(pos, radius, objs);

	lua_newtable(L);

	int i = 0;
	lua_createtable(L, objs.size(), 0);
	for (const auto obj : objs) {
		ClientObjectRef::create(L, obj.obj);
		lua_rawseti(L, -2, ++i);
	}

	return 1;
}

int LuaLocalPlayer::l_get_object(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);
	ClientEnvironment &env = getClient(L)->getEnv();
	ClientActiveObject *obj = env.getGenericCAO(player->getCAO()->getId());

	ClientObjectRef::create(L, obj);

	return 1;
}

LuaLocalPlayer *LuaLocalPlayer::checkobject(lua_State *L, int narg)
{
	luaL_checktype(L, narg, LUA_TUSERDATA);

	void *ud = luaL_checkudata(L, narg, className);
	if (!ud)
		luaL_typerror(L, narg, className);

	return *(LuaLocalPlayer **)ud;
}

LocalPlayer *LuaLocalPlayer::getobject(LuaLocalPlayer *ref)
{
	return ref->m_localplayer;
}

LocalPlayer *LuaLocalPlayer::getobject(lua_State *L, int narg)
{
	LuaLocalPlayer *ref = checkobject(L, narg);
	assert(ref);
	LocalPlayer *player = getobject(ref);
	assert(player);
	return player;
}

int LuaLocalPlayer::l_set_override_speed(lua_State *L)
{
	LocalPlayer *player = getobject(L, 1);
	f32 s = (float) luaL_checknumber(L, 2);
	g_settings->setBool("movement_ignore_server_speed",true);
	g_settings->setFloat("movement_speed_walk",s);
	player->movement_speed_walk = g_settings->getFloat("movement_speed_walk") * BS;
	return 0;
}

int LuaLocalPlayer::l_set_speeds_from_local_settings(lua_State *L)
{
	g_settings->setBool("movement_ignore_server_speed",true);
	getClient(L)->set_speeds_from_local_settings();
	return 0;
}
int LuaLocalPlayer::l_set_speeds_from_server_settings(lua_State *L)
{
	g_settings->setBool("movement_ignore_server_speed",false);
	getClient(L)->set_speeds_from_server_settings();
	return 0;
}

int LuaLocalPlayer::gc_object(lua_State *L)
{
	LuaLocalPlayer *o = *(LuaLocalPlayer **)(lua_touserdata(L, 1));
	delete o;
	return 0;
}

void LuaLocalPlayer::Register(lua_State *L)
{
	lua_newtable(L);
	int methodtable = lua_gettop(L);
	luaL_newmetatable(L, className);
	int metatable = lua_gettop(L);

	lua_pushliteral(L, "__metatable");
	lua_pushvalue(L, methodtable);
	lua_settable(L, metatable); // hide metatable from lua getmetatable()

	lua_pushliteral(L, "__index");
	lua_pushvalue(L, methodtable);
	lua_settable(L, metatable);

	lua_pushliteral(L, "__gc");
	lua_pushcfunction(L, gc_object);
	lua_settable(L, metatable);

	lua_pop(L, 1); // Drop metatable

	luaL_openlib(L, 0, methods, 0); // fill methodtable
	lua_pop(L, 1);			// Drop methodtable
}

const char LuaLocalPlayer::className[] = "LocalPlayer";
const luaL_Reg LuaLocalPlayer::methods[] = {
		luamethod(LuaLocalPlayer, get_velocity),
		luamethod(LuaLocalPlayer, set_velocity),
		luamethod(LuaLocalPlayer, get_hp),
		luamethod(LuaLocalPlayer, get_name),
		luamethod(LuaLocalPlayer, get_wield_index),
		luamethod(LuaLocalPlayer, set_wield_index),
		luamethod(LuaLocalPlayer, get_wielded_item),
		luamethod(LuaLocalPlayer, is_attached),
		luamethod(LuaLocalPlayer, is_touching_ground),
		luamethod(LuaLocalPlayer, is_in_liquid),
		luamethod(LuaLocalPlayer, is_in_liquid_stable),
		luamethod(LuaLocalPlayer, get_liquid_viscosity),
		luamethod(LuaLocalPlayer, is_climbing),
		luamethod(LuaLocalPlayer, swimming_vertical),
		luamethod(LuaLocalPlayer, get_physics_override),
		luamethod(LuaLocalPlayer, set_physics_override),
		// TODO: figure our if these are useful in any way
		luamethod(LuaLocalPlayer, get_last_pos),
		luamethod(LuaLocalPlayer, get_last_velocity),
		luamethod(LuaLocalPlayer, get_last_look_horizontal),
		luamethod(LuaLocalPlayer, get_last_look_vertical),
		//
		luamethod(LuaLocalPlayer, get_control),
		luamethod(LuaLocalPlayer, get_breath),
		luamethod(LuaLocalPlayer, get_pos),
		luamethod(LuaLocalPlayer, set_pos),
		luamethod(LuaLocalPlayer, get_yaw),
		luamethod(LuaLocalPlayer, set_yaw),
		luamethod(LuaLocalPlayer, get_pitch),
		luamethod(LuaLocalPlayer, set_pitch),
		luamethod(LuaLocalPlayer, get_movement_acceleration),
		luamethod(LuaLocalPlayer, get_movement_speed),
		luamethod(LuaLocalPlayer, get_movement),
		luamethod(LuaLocalPlayer, get_armor_groups),
		luamethod(LuaLocalPlayer, hud_add),
		luamethod(LuaLocalPlayer, hud_remove),
		luamethod(LuaLocalPlayer, hud_change),
		luamethod(LuaLocalPlayer, hud_get),
		luamethod(LuaLocalPlayer, get_object),

		luamethod(LuaLocalPlayer, get_nearby_objects),
		luamethod(LuaLocalPlayer, get_object),
		luamethod(LuaLocalPlayer, set_override_speed),
		luamethod(LuaLocalPlayer, set_speeds_from_server_settings),
		luamethod(LuaLocalPlayer, set_speeds_from_local_settings),

		{0, 0}
};
