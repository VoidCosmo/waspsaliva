if INIT == "client" then

core.register_chatcommand("say", {
	description = "Send raw text",
	func = function(text)
		minetest.send_chat_message(text)
		return true
	end,
})

core.register_chatcommand("teleport", {
	params = "<X>,<Y>,<Z>",
	description = "Teleport to relative coordinates.",
	func = function(param)
		local success, pos = minetest.parse_relative_pos(param)
		if success then
			minetest.localplayer:set_pos(pos)
			return true, "Teleporting to " .. minetest.pos_to_string(pos)
		end
		return false, pos
	end,
})

core.register_chatcommand("wielded", {
	description = "Print itemstring of wieleded item",
	func = function()
		return true, minetest.localplayer:get_wielded_item():get_name()
	end
})

core.register_chatcommand("disconnect", {
	description = "Exit to main menu",
	func = function(param)
		minetest.disconnect()
	end,
})

core.register_chatcommand("players", {
	description = "List online players",
	func = function(param)
		return true, "Online players: " .. table.concat(minetest.get_player_names(), ", ")
	end
})

core.register_chatcommand("kill", {
	description = "Kill yourself",
	func = function()
		minetest.send_damage(minetest.localplayer:get_hp())
	end,
})

core.register_chatcommand("hop", {
	description = "Hop",
	func = function()
		minetest.set_keypress("jump", true)
	end,
})

core.register_chatcommand("set", {
	params = "([-n] <name> <value>) | <name>",
	description = "Set or read client configuration setting",
	func = function(param)
		local arg, setname, setvalue = string.match(param, "(-[n]) ([^ ]+) (.+)")
		if arg and arg == "-n" and setname and setvalue then
			minetest.settings:set(setname, setvalue)
			return true, setname .. " = " .. setvalue
		end

		setname, setvalue = string.match(param, "([^ ]+) (.+)")
		if setname and setvalue then
			if not minetest.settings:get(setname) then
				return false, "Failed. Use '.set -n <name> <value>' to create a new setting."
			end
			minetest.settings:set(setname, setvalue)
			return true, setname .. " = " .. setvalue
		end

		setname = string.match(param, "([^ ]+)")
		if setname then
			setvalue = minetest.settings:get(setname)
			if not setvalue then
				setvalue = "<not set>"
			end
			return true, setname .. " = " .. setvalue
		end

		return false, "Invalid parameters (see .help set)."
	end,
})

end
