local function register_keypress_cheat(cheat, keyname, condition)
	local was_active = false
	minetest.register_globalstep(function()
		local is_active = minetest.settings:get_bool(cheat) and (not condition or condition())
		if is_active then
			minetest.set_keypress(keyname, true)
		elseif was_active then
			minetest.set_keypress(keyname, false)
		end
		was_active = is_active
	end)
end

register_keypress_cheat("autosneak", "sneak", function()
	return minetest.localplayer:is_touching_ground()
end)
register_keypress_cheat("autosprint", "special1")

local legit_override

local function get_override_factor(name)
	if minetest.settings:get_bool("override_" .. name) then
		return tonumber(minetest.settings:get("override_" .. name .. "_factor")) or 1
	else
		return 1.0
	end
end

minetest.register_globalstep(function()
	if not legit_override then return end
	local override = table.copy(legit_override)
	override.speed = override.speed * get_override_factor("speed")
	override.jump = override.jump * get_override_factor("jump")
	override.gravity = override.gravity * get_override_factor("gravity")
	minetest.localplayer:set_physics_override(override)
end)

minetest.register_on_recieve_physics_override(function(override)
	legit_override = override
    return true
end)

minetest.register_cheat("AutoSneak", "Movement", "autosneak")
minetest.register_cheat("AutoSprint", "Movement", "autosprint")
