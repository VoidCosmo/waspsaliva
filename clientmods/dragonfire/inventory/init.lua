local drop_action = InventoryAction("drop")

local strip_move_act = InventoryAction("move")
strip_move_act:to("current_player", "craft", 1)
local strip_craft_act = InventoryAction("craft")
strip_craft_act:craft("current_player")
local strip_move_back_act = InventoryAction("move")
strip_move_back_act:from("current_player", "craftresult", 1)

minetest.register_globalstep(function(dtime)
	local player = minetest.localplayer
	if not player then return end
	local item = player:get_wielded_item()
	local itemdef = minetest.get_item_def(item:get_name())
	local wieldindex = player:get_wield_index()
	-- AutoRefill
	if minetest.settings:get_bool("autorefill") and itemdef then
		local space = item:get_free_space()
		local i = minetest.find_item(item:get_name(), wieldindex + 1)
		if i and space > 0 then
			local move_act = InventoryAction("move")
			move_act:to("current_player", "main", wieldindex)
			move_act:from("current_player", "main", i)
			move_act:set_count(space)
			move_act:apply()
		end
	end
	-- AutoPlanks (Strip in DF)
	if minetest.settings:get_bool("autoplanks") then
		if itemdef and itemdef.groups.tree and player:get_control().place then
			strip_move_act:from("current_player", "main", wieldindex)
			strip_move_back_act:to("current_player", "main", wieldindex)
			strip_move_act:apply()
			strip_craft_act:apply()
			strip_move_back_act:apply()
		end
	end
	-- AutoEject
	if minetest.settings:get_bool("autoeject") then
		local list = (minetest.settings:get("eject_items") or ""):split(",")
		local inventory = minetest.get_inventory("current_player")
		for index, stack in pairs(inventory.main) do
			if table.indexof(list, stack:get_name()) ~= -1 then
				drop_action:from("current_player", "main", index)
				drop_action:apply()
			end
		end
	end
end)

minetest.register_list_command("eject", "Configure AutoEject", "eject_items")

-- AutoTool

local function check_tool(stack, node_groups, old_best_time)
	local toolcaps = stack:get_tool_capabilities()
	if not toolcaps then return end
	local best_time = old_best_time
	for group, groupdef in pairs(toolcaps.groupcaps) do
		local level = node_groups[group]
		if level then
			local this_time = groupdef.times[level]
			if this_time and this_time < best_time then
				best_time = this_time
			end
		end
	end
	return best_time < old_best_time, best_time
end

local function find_best_tool(nodename, switch)
	local player = minetest.localplayer
	local inventory = minetest.get_inventory("current_player")
	local node_groups = minetest.get_node_def(nodename).groups
	local new_index = player:get_wield_index()
	local is_better, best_time = false, math.huge

	is_better, best_time = check_tool(player:get_wielded_item(), node_groups, best_time)
	if inventory.hand then
	    is_better, best_time = check_tool(inventory.hand[1], node_groups, best_time)
    end

	for index, stack in ipairs(inventory.main) do
		is_better, best_time = check_tool(stack, node_groups, best_time)
		if is_better then
			new_index = index
		end
	end

	return new_index
end

function minetest.select_best_tool(nodename)
	minetest.localplayer:set_wield_index(find_best_tool(nodename))
end

local new_index, old_index, pointed_pos

minetest.register_on_punchnode(function(pos, node)
	if minetest.settings:get_bool("autotool") then
		pointed_pos = pos
		old_index = old_index or minetest.localplayer:get_wield_index()
		new_index = find_best_tool(node.name)
	end
end)

minetest.register_globalstep(function()
	local player = minetest.localplayer
	if not new_index then return end
	if minetest.settings:get_bool("autotool") then
		local pt = minetest.get_pointed_thing()
		if pt and pt.type == "node" and vector.equals(minetest.get_pointed_thing_position(pt), pointed_pos) and player:get_control().dig then
			player:set_wield_index(new_index)
			return
		end
	end
	player:set_wield_index(old_index)
	new_index, old_index, pointed_pos = nil
end)

-- Enderchest

function get_itemslot_bg(x, y, w, h)
	local out = ""
	for i = 0, w - 1, 1 do
		for j = 0, h - 1, 1 do
			out = out .."image["..x+i..","..y+j..";1,1;mcl_formspec_itemslot.png]"
		end
	end
	return out
end

local enderchest_formspec = "size[9,8.75]"..
	"label[0,0;"..minetest.formspec_escape(minetest.colorize("#313131", "Ender Chest")).."]"..
	"list[current_player;enderchest;0,0.5;9,3;]"..
	get_itemslot_bg(0,0.5,9,3)..
	"label[0,4.0;"..minetest.formspec_escape(minetest.colorize("#313131", "Inventory")).."]"..
	"list[current_player;main;0,4.5;9,3;9]"..
	get_itemslot_bg(0,4.5,9,3)..
	"list[current_player;main;0,7.74;9,1;]"..
	get_itemslot_bg(0,7.74,9,1)..
	"listring[current_player;enderchest]"..
	"listring[current_player;main]"

function minetest.open_enderchest()
	minetest.show_formspec("inventory:enderchest", enderchest_formspec)
end

-- HandSlot

local hand_formspec = "size[9,8.75]"..
	"label[0,0;"..minetest.formspec_escape(minetest.colorize("#313131", "Hand")).."]"..
	"list[current_player;hand;0,0.5;1,1;]"..
	get_itemslot_bg(0,0.5,1,1)..
	"label[0,4.0;"..minetest.formspec_escape(minetest.colorize("#313131", "Inventory")).."]"..
	"list[current_player;main;0,4.5;9,3;9]"..
	get_itemslot_bg(0,4.5,9,3)..
	"list[current_player;main;0,7.74;9,1;]"..
	get_itemslot_bg(0,7.74,9,1)..
	"listring[current_player;hand]"..
	"listring[current_player;main]"
	
function minetest.open_handslot()
	minetest.show_formspec("inventory:hand", hand_formspec)
end

minetest.register_cheat("AutoEject", "Inventory", "autoeject")
minetest.register_cheat("AutoTool", "Inventory", "autotool")
minetest.register_cheat("Hand", "Inventory", minetest.open_handslot)
minetest.register_cheat("Enderchest", "Inventory", minetest.open_enderchest)
minetest.register_cheat("AutoPlanks", "Inventory", "autoplanks")
minetest.register_cheat("AutoRefill", "Inventory", "autorefill")

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

dofile(modpath .. "/next_item.lua")
dofile(modpath .. "/invhack.lua")

