autoeat = {}
autoeat.lock = false

local autodupe = false --rawget(_G, "autodupe")
local hud_id = nil

local function get_float(name, default)
	return tonumber(minetest.settings:get("autoeat_" .. name) or "") or default
end

local etime = 0

function autoeat.eat()
	local food_index
	local food_count = 0
	for index, stack in pairs(minetest.get_inventory("current_player").main) do
		local stackname = stack:get_name()
		if stackname ~= "" then
			local def = minetest.get_item_def(stackname)
			if def and def.groups.food then
				food_count = food_count + 1
				if food_index then
					break
				end
				food_index = index
			end
		end
	end
	if food_index then
		if food_count == 1 and autodupe then
			--autodupe.needed(food_index)
			autoeat.lock = true
		else
			local player = minetest.localplayer
			local old_index = player:get_wield_index()
			player:set_wield_index(food_index)
			--minetest.interact("activate", {type = "nothing"})
			minetest.place_node(minetest.localplayer:get_pos())
			player:set_wield_index(old_index)
			autoeat.lock = false
		end
	end
end

function autoeat.get_hunger()
	if hud_id then
		return minetest.localplayer:hud_get(hud_id).number
	else
		return 20
	end
end

minetest.register_globalstep(function(dtime)
	if not minetest.localplayer then return end
	etime = etime + dtime
	if autoeat.lock or minetest.settings:get_bool("autoeat") and etime >= get_float("cooldown", 0.5) and autoeat.get_hunger() < get_float("hunger", 9) then
		etime = 0
		autoeat.eat()
	end
end)
local function get_hud()
	local player = minetest.localplayer
	local def
	local i = -1
	if not player then minetest.after(5,get_hud) return end
	repeat
		i = i + 1
		def = player:hud_get(i)
	until not def or def.text == "hbhunger_icon.png"
	if def then
		hud_id = i
	end
end
minetest.after(15,get_hud )

minetest.register_cheat("AutoEat", "Player", "autoeat")
