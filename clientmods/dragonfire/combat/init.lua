local placed_crystal
local switched_to_totem = 0
local used_sneak = true
local totem_move_action = InventoryAction("move")
totem_move_action:to("current_player", "main", 9)

local mobs_friends = {
'mobs_mc_bat.png',
'mobs_mc_cat_black.png',
'mobs_mc_cat_ocelot.png',
'mobs_mc_cat_red.png',
'mobs_mc_cat_siamese.png',
'mobs_mc_diamond_horse_armor.png',
'mobs_mc_donkey.png',
'mobs_mc_wolf_collar.png',
'mobs_mc_wolf.png',
'mobs_mc_wolf_tame.png',
'mobs_mc_villager_butcher.png',
'mobs_mc_villager_farmer.png',
'mobs_mc_villager_librarian.png',
'mobs_mc_villager.png',
'mobs_mc_villager_priest.png',
'mobs_mc_villager_smith.png',
'mobs_mc_iron_golem.png',
'mobs_mc_iron_horse_armor.png',
'mobs_mc_mooshroom.png',
'mobs_mc_mule.png',
'mobs_mc_pig.png',
'mobs_mc_pig_saddle.png',
'mobs_mc_polarbear.png',
'mobs_mc_rabbit_black.png',
'mobs_mc_rabbit_brown.png',
'mobs_mc_rabbit_caerbannog.png',
'mobs_mc_rabbit_gold.png',
'mobs_mc_rabbit_salt.png',
'mobs_mc_rabbit_toast.png',
'mobs_mc_rabbit_white.png',
'mobs_mc_rabbit_white_splotched.png',
'mobs_mc_sheep_fur.png',
'mobs_mc_sheep.png',
'mobs_mc_horse_armor_diamond.png',
'mobs_mc_horse_armor_gold.png',
'mobs_mc_horse_armor_iron.png',
'mobs_mc_horse_black.png',
'mobs_mc_horse_brown.png',
'mobs_mc_horse_chestnut.png',
'mobs_mc_horse_darkbrown.png',
'mobs_mc_horse_gray.png',
'mobs_mc_horse_creamy.png',
'mobs_mc_horse_markings_blackdots.png',
'mobs_mc_horse_markings_whitedots.png',
'mobs_mc_horse_markings_whitefield.png',
'mobs_mc_horse_markings_white.png',
'mobs_mc_horse_white.png',
'mobs_mc_snowman',
'mobs_mc_chicken.png',
'mobs_mc_enderman.png',
'mobs_mc_cow.png'
}

local mobs_bad = {
'mcl_totems_totem.png',
'mobs_mc_blaze.png',
'mobs_mc_cave_spider.png',
'mobs_mc_creeper.png',
'mobs_mc_dragon.png',
'mobs_mc_endergolem.png',
'mobs_mc_magmacube.png',
'mobs_mc_enderman_eyes.png',
'mobs_mc_endermite.png',
'mobs_mc_ghast.png',
'mobs_mc_gold_horse_armor.png',
'mobs_mc_guardian_elder.png',
'mobs_mc_guardian.png',
'mobs_mc_husk.png',
'mobs_mc_shulker_black.png',
'mobs_mc_shulker_blue.png',
'mobs_mc_shulker_brown.png',
'mobs_mc_shulker_cyan.png',
'mobs_mc_shulker_gray.png',
'mobs_mc_shulker_green.png',
'mobs_mc_shulker_light_blue.png',
'mobs_mc_shulker_lime.png',
'mobs_mc_shulker_magenta.png',
'mobs_mc_shulker_orange.png',
'mobs_mc_shulker_pink.png',
'mobs_mc_shulker_purple.png',
'mobs_mc_shulker_red.png',
'mobs_mc_shulker_silver.png',
'mobs_mc_shulker_white.png',
'mobs_mc_shulker_yellow.png',
'mobs_mc_silverfish.png',
'mobs_mc_skeleton.png',
'mobs_mc_slime.png',
'mobs_mc_spider_eyes.png',
'mobs_mc_spider.png',
'mobs_mc_squid.png',
'mobs_mc_stray.png',
'mobs_mc_stray_overlay.png',
'mobs_mc_vex.png',
'mobs_mc_vex_charging.png',
'mobs_mc_vindicator.png',
'mobs_mc_evoker.png',
'mobs_mc_illusionist.png',
'mobs_mc_witch.png',
'mobs_mc_wither.png',
'mobs_mc_wither_skeleton.png',
'mobs_mc_wolf_angry.png',
'mobs_mc_zombie_butcher.png',
'mobs_mc_zombie_farmer.png',
'mobs_mc_zombie_librarian.png',
'mobs_mc_zombie_priest.png',
'mobs_mc_zombie_smith.png',
'mobs_mc_zombie_villager.png',
'mobs_mc_zombie_pigman.png',
'mobs_mc_zombie.png',
'mobs_mc_horse_zombie.png'
}

--minetest.register_list_command("friend", "Configure Friend List (friends dont get attacked by Killaura or Forcefield)", "friendlist")
local nexthit=0
minetest.register_globalstep(function(dtime)
	local player = minetest.localplayer
	if not player then return end
	local control = player:get_control()
	local pointed = minetest.get_pointed_thing()
	local item = player:get_wielded_item():get_name()
	if minetest.settings:get_bool("killaura") or minetest.settings:get_bool("forcefield") and control.dig then
		if nexthit > os.clock() then return end
		nexthit=os.clock() + 0.01
		for _, obj in pairs(minetest.get_objects_inside_radius(player:get_pos(), 5)) do
			local do_attack = false
			local txt=obj:get_item_textures()
			if(obj:is_player() and fren.is_enemy(obj:get_name())) then do_attack=true end
			for k,v in pairs(mobs_bad) do if txt:find(v) then do_attack=true end end
			if do_attack then
				local owx=core.localplayer:get_wield_index()
				minetest.switch_to_item('mcl_tools:sword_diamond')
				obj:punch()
				core.localplayer:set_wield_index(owx)
			end
		end
	elseif minetest.settings:get_bool("crystal_pvp") then
		if placed_crystal then
			if minetest.switch_to_item("mobs_mc:totem") then
				switched_to_totem = 5
			end
			placed_crystal = false
		elseif switched_to_totem > 0 then
			if item ~= "mobs_mc:totem"  then
				switched_to_totem = 0
			elseif pointed and pointed.type == "object" then
				pointed.ref:punch()
				switched_to_totem = 0
			else
				switched_to_totem = switched_to_totem
			end
		elseif control.place and item == "mcl_end:crystal" then
			placed_crystal = true
		elseif control.sneak then
			if pointed and pointed.type == "node" and not used_sneak then
				local pos = minetest.get_pointed_thing_position(pointed)
				local node = minetest.get_node_or_nil(pos)
				if node and (node.name == "mcl_core:obsidian" or node.name == "mcl_core:bedrock") then
					minetest.switch_to_item("mcl_end:crystal")
					minetest.place_node(pos)
					placed_crystal = true
				end
			end
			used_sneak = true
		else
			used_sneak = false
		end
	end

	if minetest.settings:get_bool("autototem") then
		local totem_stack = minetest.get_inventory("current_player").main[9]
		if totem_stack and totem_stack:get_name() ~= "mobs_mc:totem" then
			local totem_index = minetest.find_item("mobs_mc:totem")
			if totem_index then
				totem_move_action:from("current_player", "main", totem_index)
				totem_move_action:apply()
				player:set_wield_index(9)
			end
		end
	end
end)


minetest.register_cheat("Killaura", "Combat", "killaura")
minetest.register_cheat("Forcefield", "Combat", "forcefield")
minetest.register_cheat("CrystalPvP", "Combat", "crystal_pvp")
minetest.register_cheat("AutoTotem", "Combat", "autototem")
