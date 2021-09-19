/*
Minetest
Copyright (C) 2010-2013 celeron55, Perttu Ahola <celeron55@gmail.com>

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

#pragma once

#include <map>
#include "irrlichttypes_extrabloated.h"
#include "clientobject.h"
#include "object_properties.h"
#include "itemgroup.h"
#include "constants.h"
#include <cassert>

class Camera;
class Client;
struct Nametag;
struct MinimapMarker;

/*
	SmoothTranslator
*/

template<typename T>
struct SmoothTranslator
{
	T val_old;
	T val_current;
	T val_target;
	f32 anim_time = 0;
	f32 anim_time_counter = 0;
	bool aim_is_end = true;

	SmoothTranslator() = default;

	void init(T current);

	void update(T new_target, bool is_end_position = false,
		float update_interval = -1);

	void translate(f32 dtime);
};

struct SmoothTranslatorWrapped : SmoothTranslator<f32>
{
	void translate(f32 dtime);
};

struct SmoothTranslatorWrappedv3f : SmoothTranslator<v3f>
{
	void translate(f32 dtime);
};

class GenericCAO : public ClientActiveObject
{
private:
	// Only set at initialization
	std::string m_name = "";
	bool m_is_player = false;
	bool m_is_local_player = false;
	// Property-ish things
	ObjectProperties m_prop;
	//
	scene::ISceneManager *m_smgr = nullptr;
	Client *m_client = nullptr;
	aabb3f m_selection_box = aabb3f(-BS/3.,-BS/3.,-BS/3., BS/3.,BS/3.,BS/3.);
	scene::IMeshSceneNode *m_meshnode = nullptr;
	scene::IAnimatedMeshSceneNode *m_animated_meshnode = nullptr;
	WieldMeshSceneNode *m_wield_meshnode = nullptr;
	scene::IBillboardSceneNode *m_spritenode = nullptr;
	scene::IDummyTransformationSceneNode *m_matrixnode = nullptr;
	Nametag *m_nametag = nullptr;
	MinimapMarker *m_marker = nullptr;
	v3f m_position = v3f(0.0f, 10.0f * BS, 0);
	v3f m_velocity;
	v3f m_acceleration;
	v3f m_rotation;
	u16 m_hp = 1;
	SmoothTranslator<v3f> pos_translator;
	SmoothTranslatorWrappedv3f rot_translator;
	// Spritesheet/animation stuff
	v2f m_tx_size = v2f(1,1);
	v2s16 m_tx_basepos;
	bool m_initial_tx_basepos_set = false;
	bool m_tx_select_horiz_by_yawpitch = false;
	v2s32 m_animation_range;
	float m_animation_speed = 15.0f;
	float m_animation_blend = 0.0f;
	bool m_animation_loop = true;
	// stores position and rotation for each bone name
	std::unordered_map<std::string, core::vector2d<v3f>> m_bone_position;

	int m_attachment_parent_id = 0;
	std::unordered_set<int> m_attachment_child_ids;
	std::string m_attachment_bone = "";
	v3f m_attachment_position;
	v3f m_attachment_rotation;
	bool m_attached_to_local = false;
	bool m_force_visible = false;

	int m_anim_frame = 0;
	int m_anim_num_frames = 1;
	float m_anim_framelength = 0.2f;
	float m_anim_timer = 0.0f;
	ItemGroupList m_armor_groups;
	float m_reset_textures_timer = -1.0f;
	// stores texture modifier before punch update
	std::string m_previous_texture_modifier = "";
	// last applied texture modifier
	std::string m_current_texture_modifier = "";
	bool m_visuals_expired = false;
	float m_step_distance_counter = 0.0f;
	u8 m_last_light = 255;
	bool m_is_visible = false;
	s8 m_glow = 0;
	// Material
	video::E_MATERIAL_TYPE m_material_type;
	// Settings
	bool m_enable_shaders = false;

	bool visualExpiryRequired(const ObjectProperties &newprops) const;

public:
	GenericCAO(Client *client, ClientEnvironment *env);

	~GenericCAO();

	static ClientActiveObject* create(Client *client, ClientEnvironment *env)
	{
		return new GenericCAO(client, env);
	}

	inline ActiveObjectType getType() const
	{
		return ACTIVEOBJECT_TYPE_GENERIC;
	}
	inline const ItemGroupList &getGroups() const
	{
		return m_armor_groups;
	}
	void initialize(const std::string &data);

	void processInitData(const std::string &data);

	bool getCollisionBox(aabb3f *toset) const;

	bool collideWithObjects() const;

	virtual bool getSelectionBox(aabb3f *toset) const;

	const v3f getPosition() const;

	void setPosition(const v3f &pos)
	{
		pos_translator.val_current = pos;
	}

	inline const v3f &getRotation() const { return m_rotation; }

	inline const v3f getAcceleration() const
	{
		return m_acceleration;
	}

	inline const v3f getVelocity() const
	{
		return m_velocity;
	}

	inline const u16 getHp() const
	{
		return m_hp;
	}

	const bool isImmortal();

	scene::ISceneNode *getSceneNode() const;

	scene::IAnimatedMeshSceneNode *getAnimatedMeshSceneNode() const;

	// m_matrixnode controls the position and rotation of the child node
	// for all scene nodes, as a workaround for an Irrlicht problem with
	// rotations. The child node's position can't be used because it's
	// rotated, and must remain as 0.
	// Note that m_matrixnode.setPosition() shouldn't be called. Use
	// m_matrixnode->getRelativeTransformationMatrix().setTranslation()
	// instead (aka getPosRotMatrix().setTranslation()).
	inline core::matrix4 &getPosRotMatrix()
	{
		assert(m_matrixnode);
		return m_matrixnode->getRelativeTransformationMatrix();
	}

	inline const core::matrix4 *getAbsolutePosRotMatrix() const
	{
		if (!m_matrixnode)
			return nullptr;
		return &m_matrixnode->getAbsoluteTransformation();
	}

	inline f32 getStepHeight() const
	{
		return m_prop.stepheight;
	}

	inline std::string getName() const
	{
		return m_name;
	}

	inline bool isPlayer() const
	{
		return m_is_player;
	}

	inline bool isLocalPlayer() const
	{
		return m_is_local_player;
	}

	inline bool isVisible() const
	{
		return m_is_visible;
	}

	inline void setVisible(bool toset)
	{
		m_is_visible = toset;
	}

	void setChildrenVisible(bool toset);
	void setAttachment(int parent_id, const std::string &bone, v3f position,
			v3f rotation, bool force_visible);
	void getAttachment(int *parent_id, std::string *bone, v3f *position,
			v3f *rotation, bool *force_visible) const;
	void clearChildAttachments();
	void clearParentAttachment();
	void addAttachmentChild(int child_id);
	void removeAttachmentChild(int child_id);
	ClientActiveObject *getParent() const;
	int getParentId() const { return m_attachment_parent_id; }
	const std::unordered_set<int> &getAttachmentChildIds() const
	{ return m_attachment_child_ids; }
	void updateAttachments();

	void removeFromScene(bool permanent);

	void addToScene(ITextureSource *tsrc);

	inline void expireVisuals()
	{
		m_visuals_expired = true;
	}

	void updateLight(u32 day_night_ratio);

	void setNodeLight(u8 light);

	/* Get light position(s).
	 * returns number of positions written into pos[], which must have space
	 * for at least 3 vectors. */
	u16 getLightPosition(v3s16 *pos);

	void updateNametag();

	void updateMarker();

	void updateNodePos();

	void step(float dtime, ClientEnvironment *env);

	void updateTexturePos();

	// ffs this HAS TO BE a string copy! See #5739 if you think otherwise
	// Reason: updateTextures(m_previous_texture_modifier);
	void updateTextures(std::string mod);

	void updateAnimation();

	void updateAnimationSpeed();

	void updateBonePosition();

	void processMessage(const std::string &data);

	bool directReportPunch(v3f dir, const ItemStack *punchitem=NULL,
			float time_from_last_punch=1000000);

	std::string debugInfoText();

	std::string infoText()
	{
		return m_prop.infotext;
	}

	float m_waiting_for_reattach;

	ObjectProperties *getProperties()
	{
		return &m_prop;
	}

	void updateMeshCulling();
};