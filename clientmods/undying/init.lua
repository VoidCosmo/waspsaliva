--
-- undying


local sh=false

local function findbones()
	return minetest.find_node_near(minetest.localplayer:get_pos(), 6, {"bones:bones"},true)
end

local function digbones()
	local bn=findbones()
	if not bn then return false end
	minetest.dig_node(bn)
	if findbones() then minetest.after("0.1",digbones) end
end

minetest.register_on_death(function()
	if not minetest.settings:get_bool("undying") then return end
	sh=false
	minetest.after("0.1",function() minetest.send_chat_message("/home")	end)
	minetest.after("0.2",function()
		digbones()
		for k, v in ipairs(minetest.localplayer.get_nearby_objects(10)) do
			if (v:is_player() and v:get_name() ~= minetest.localplayer:get_name()) then
				local pos = v:get_pos()
				pos.y = pos.y - 1
				autofly.aim(pos)
			end
		end
	end)
end)

minetest.register_on_damage_taken(function(hp)
	if not sh and minetest.settings:get_bool("undying") then
		local hhp=minetest.localplayer:get_hp()
		--if (hhp==0 ) then return end
		if (hhp < 2 ) then
			sh=true
			minetest.settings:set_bool("autorespawn",true)
			minetest.send_chat_message("/sethome") end
		end
end
)
minetest.register_on_receiving_chat_message(function(msg)
	if (msg:find('Teleported to home!') or msg:find('Home set!')) then return true end
end)

-- REG cheats on DF
if (_G["minetest"]["register_cheat"] ~= nil) then
	 minetest.register_cheat("Undying", "Combat", "undying")
else
	 minetest.settings:set_bool('undying',true)
end
