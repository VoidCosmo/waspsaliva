/*
Minetest
Copyright (C) 2010-2013 celeron55, Perttu Ahola <celeron55@gmail.com>
Copyright (C) 2017 numzero, Lobachevskiy Vitaliy <numzer0@yandex.ru>

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

#include <iostream>
#include "core.h"
#include "client/camera.h"
#include "client/client.h"
#include "client/clientmap.h"
#include "client/hud.h"
#include "client/minimap.h"
#include "client/content_cao.h"
#include "settings.h"
#include "mapblock.h"
#include "mapsector.h"

RenderingCore::RenderingCore(IrrlichtDevice *_device, Client *_client, Hud *_hud)
	: device(_device), driver(device->getVideoDriver()), smgr(device->getSceneManager()),
	guienv(device->getGUIEnvironment()), client(_client), camera(client->getCamera()),
	mapper(client->getMinimap()), hud(_hud)
{
	screensize = driver->getScreenSize();
	virtual_size = screensize;
}

RenderingCore::~RenderingCore()
{
	clearTextures();
}

void RenderingCore::initialize()
{
	// have to be called late as the VMT is not ready in the constructor:
	initTextures();
}

void RenderingCore::updateScreenSize()
{
	virtual_size = screensize;
	clearTextures();
	initTextures();
}

void RenderingCore::draw(video::SColor _skycolor, bool _show_hud, bool _show_minimap,
		bool _draw_wield_tool, bool _draw_crosshair)
{
	v2u32 ss = driver->getScreenSize();
	if (screensize != ss) {
		screensize = ss;
		updateScreenSize();
	}
	skycolor = _skycolor;
	show_hud = _show_hud;
	show_minimap = _show_minimap;
	draw_wield_tool = _draw_wield_tool;
	draw_crosshair = _draw_crosshair;
	draw_entity_esp = g_settings->getBool("enable_entity_esp");
	draw_entity_tracers = g_settings->getBool("enable_entity_tracers");
	draw_player_esp = g_settings->getBool("enable_player_esp");
	draw_player_tracers = g_settings->getBool("enable_player_tracers");
	draw_node_esp = g_settings->getBool("enable_node_esp");
	draw_node_tracers = g_settings->getBool("enable_node_tracers");
	v3f entity_color = g_settings->getV3F("entity_esp_color");
	v3f player_color = g_settings->getV3F("player_esp_color");
	entity_esp_color = video::SColor(255, entity_color.X, entity_color.Y, entity_color.Z);
	player_esp_color = video::SColor(255, player_color.X, player_color.Y, player_color.Z);

	beforeDraw();
	drawAll();
}

void RenderingCore::drawTracersAndESP()
{
	ClientEnvironment &env = client->getEnv();
	Camera *camera = client->getCamera();

	v3f camera_offset = intToFloat(camera->getOffset(), BS);

	v3f eye_pos = (camera->getPosition() + camera->getDirection() - camera_offset);

 	video::SMaterial material, oldmaterial;
 	oldmaterial = driver->getMaterial2D();
	material.setFlag(video::EMF_LIGHTING, false);
	material.setFlag(video::EMF_BILINEAR_FILTER, false);
	material.setFlag(video::EMF_ZBUFFER, false);
	material.setFlag(video::EMF_ZWRITE_ENABLE, false);
	driver->setMaterial(material);

 	if (draw_entity_esp || draw_entity_tracers || draw_player_esp || draw_player_tracers) {
		auto allObjects = env.getAllActiveObjects();
		for (auto &it : allObjects) {
			ClientActiveObject *cao = it.second;
			if (cao->isLocalPlayer() || cao->getParent())
				continue;
			GenericCAO *obj = dynamic_cast<GenericCAO *>(cao);
			if (! obj)
				continue;
			bool is_player = obj->isPlayer();
			bool draw_esp = is_player ? draw_player_esp : draw_entity_esp;
			bool draw_tracers = is_player ? draw_player_tracers : draw_entity_tracers;
			video::SColor color = is_player ? player_esp_color : entity_esp_color;
			if (! (draw_esp || draw_tracers))
				continue;
			aabb3f box;
			if (! obj->getSelectionBox(&box))
				continue;
			v3f pos = obj->getPosition() - camera_offset;
			box.MinEdge += pos;
			box.MaxEdge += pos;
			if (draw_esp)
				driver->draw3DBox(box, color);
			if (draw_tracers)
				driver->draw3DLine(eye_pos, box.getCenter(), color);
		}
	}
	if (draw_node_esp || draw_node_tracers) {
		Map &map = env.getMap();
		std::vector<v3s16> positions;
		map.listAllLoadedBlocks(positions);
		for (v3s16 blockp : positions) {
			MapBlock *block = map.getBlockNoCreate(blockp);
			if (! block->mesh)
				continue;
			for (v3s16 p : block->mesh->esp_nodes) {
				v3f pos = intToFloat(p, BS) - camera_offset;
				MapNode node = map.getNode(p);
				std::vector<aabb3f> boxes;
				node.getSelectionBoxes(client->getNodeDefManager(), &boxes, node.getNeighbors(p, &map));
				video::SColor color = client->getNodeDefManager()->get(node).minimap_color;
				for (aabb3f box : boxes) {
					box.MinEdge += pos;
					box.MaxEdge += pos;
					if (draw_node_esp)
						driver->draw3DBox(box, color);
					if (draw_node_tracers)
						driver->draw3DLine(eye_pos, box.getCenter(), color);
				}
			}
		}
	}

	driver->setMaterial(oldmaterial);
}

void RenderingCore::draw3D()
{
	smgr->drawAll();
	driver->setTransform(video::ETS_WORLD, core::IdentityMatrix);
	if (!show_hud)
		return;
	hud->drawSelectionMesh();
	if (draw_entity_esp || draw_entity_tracers || draw_player_esp || draw_player_tracers || draw_node_esp || draw_node_tracers)
		drawTracersAndESP();
	if (draw_wield_tool)
		camera->drawWieldedTool();
}

void RenderingCore::drawHUD()
{
	if (show_hud) {
		if (draw_crosshair)
			hud->drawCrosshair();

		hud->drawHotbar(client->getEnv().getLocalPlayer()->getWieldIndex());
		hud->drawLuaElements(camera->getOffset());
		camera->drawNametags();
		if (mapper && show_minimap)
			mapper->drawMinimap();
	}
	guienv->drawAll();
}

void RenderingCore::drawPostFx()
{
	client->getEnv().getClientMap().renderPostFx(camera->getCameraMode());
}
