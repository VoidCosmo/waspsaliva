// CC0/Unlicense system32 2020

#include "lua_api/l_clientobject.h"
#include "l_internal.h"
#include "common/c_converter.h"
#include "client/client.h"
#include "object_properties.h"
#include "util/pointedthing.h"

// should prob do some more NULL checking


ClientObjectRef *ClientObjectRef::checkobject(lua_State *L, int narg)
{
	luaL_checktype(L, narg, LUA_TUSERDATA);
	void *userdata = luaL_checkudata(L, narg, className);
	if (!userdata)
		luaL_typerror(L, narg, className);
	return *(ClientObjectRef**)userdata;
}

ClientActiveObject *ClientObjectRef::get_cao(ClientObjectRef *ref)
{
	ClientActiveObject *obj = ref->m_object;
	return obj;
}

GenericCAO *ClientObjectRef::get_generic_cao(ClientObjectRef *ref, lua_State *L)
{
	ClientActiveObject *obj = get_cao(ref);
	ClientEnvironment &env = getClient(L)->getEnv();
	GenericCAO *gcao = env.getGenericCAO(obj->getId());
	return gcao;
}
int ClientObjectRef::l_get_id(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	if(!gcao) return 0;
	lua_pushvalue(L, gcao->getId());
	return 1;
}

int ClientObjectRef::l_get_pos(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	ClientActiveObject *gcao = get_cao(ref);
	if(!gcao) return 0;
	push_v3f(L, gcao->getPosition() / BS);
	return 1;
}

int ClientObjectRef::l_get_velocity(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	if(!gcao) return 0;
	push_v3f(L, gcao->getVelocity() / BS);
	return 1;
}

int ClientObjectRef::l_get_acceleration(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	if(!gcao) return 0;
	push_v3f(L, gcao->getAcceleration() / BS);
	return 1;
}

int ClientObjectRef::l_get_rotation(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	push_v3f(L, gcao->getRotation());
	return 1;
}

int ClientObjectRef::l_is_player(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	lua_pushboolean(L, gcao->isPlayer());
	return 1;
}

int ClientObjectRef::l_is_local_player(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	lua_pushboolean(L, gcao->isLocalPlayer());
	return 1;
}

int ClientObjectRef::l_get_name(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	lua_pushstring(L, gcao->getName().c_str());
	return 1;
}

int ClientObjectRef::l_get_parent(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	create(L, gcao->getParent());
	return 1;
}

int ClientObjectRef::l_get_nametag(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	ObjectProperties *props = gcao->getProperties();
	lua_pushstring(L, props->nametag.c_str());
	return 1;
}

int ClientObjectRef::l_get_item_textures(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	ObjectProperties *props = gcao->getProperties();
	lua_newtable(L);

	for (std::string &texture : props->textures) {
		lua_pushstring(L, texture.c_str());
	}
	return 1;
}

int ClientObjectRef::l_set_visible(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	if(!gcao) return 0;
	gcao->setVisible(readParam<bool>(L, -1));
	return 0;
}

int ClientObjectRef::l_remove_from_scene(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
	if(!gcao) return 0;
	if(!gcao) return 0;
	gcao->removeFromScene(readParam<bool>(L, -1));
	return 0;
}

int ClientObjectRef::l_remove(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	ClientActiveObject *cao = get_cao(ref);
	if (! cao)
		return 0;
	getClient(L)->getEnv().removeActiveObject(cao->getId());

	return 0;
}

int ClientObjectRef::l_get_hp(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
    if(!gcao) return 0;
	lua_pushnumber(L, gcao->getHp());
	return 1;
}

int ClientObjectRef::l_get_max_hp(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	ObjectProperties *props = gcao->getProperties();
	lua_pushnumber(L, props->hp_max);
	return 1;
}

int ClientObjectRef::l_punch(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	if(!gcao) return 0;
	PointedThing pointed(gcao->getId(), v3f(0, 0, 0), v3s16(0, 0, 0), 0);
	getClient(L)->interact(INTERACT_START_DIGGING, pointed);
	return 0;
}

int ClientObjectRef::l_rightclick(lua_State *L)
{
	ClientObjectRef *ref = checkobject(L, 1);
	GenericCAO *gcao = get_generic_cao(ref, L);
 if(!gcao) return 0;
	PointedThing pointed(gcao->getId(), v3f(0, 0, 0), v3s16(0, 0, 0), 0);
	getClient(L)->interact(INTERACT_PLACE, pointed);
	return 0;
}

ClientObjectRef::ClientObjectRef(ClientActiveObject *object) : m_object(object)
{
}

void ClientObjectRef::create(lua_State *L, ClientActiveObject *object)
{
	if (object) {
		ClientObjectRef *o = new ClientObjectRef(object);
		*(void **)(lua_newuserdata(L, sizeof(void *))) = o;
		luaL_getmetatable(L, className);
		lua_setmetatable(L, -2);
	}
}

void ClientObjectRef::create(lua_State *L, s16 id)
{
	create(L, ((ClientEnvironment *)getEnv(L))->getActiveObject(id));
}

int ClientObjectRef::gc_object(lua_State *L)
{
	ClientObjectRef *obj = *(ClientObjectRef **)(lua_touserdata(L, 1));
	delete obj;
	return 0;
}

// taken from LuaLocalPlayer
void ClientObjectRef::Register(lua_State *L)
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
	lua_pop(L, 1);                  // Drop methodtable
}

const char ClientObjectRef::className[] = "ClientObjectRef";
luaL_Reg ClientObjectRef::methods[] = {
	luamethod(ClientObjectRef, get_id),
	luamethod(ClientObjectRef, get_pos),
	luamethod(ClientObjectRef, get_velocity),
	luamethod(ClientObjectRef, get_acceleration),
	luamethod(ClientObjectRef, get_rotation),
	luamethod(ClientObjectRef, is_player),
	luamethod(ClientObjectRef, get_name),
	luamethod(ClientObjectRef, get_parent),
	luamethod(ClientObjectRef, get_nametag),
	luamethod(ClientObjectRef, get_item_textures),
	luamethod(ClientObjectRef, get_max_hp),
	luamethod(ClientObjectRef, set_visible),
	luamethod(ClientObjectRef, remove_from_scene),
	luamethod(ClientObjectRef, remove),
	luamethod(ClientObjectRef, is_local_player),
	luamethod(ClientObjectRef, get_hp),
	luamethod(ClientObjectRef, punch),
	luamethod(ClientObjectRef, rightclick),
	{0, 0}
};
