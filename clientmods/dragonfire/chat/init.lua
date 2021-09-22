minetest.register_on_receiving_chat_message(function(message)
	if message:sub(1, 1) == "#" and minetest.settings:get_bool("ignore_status_messages") ~= false then
		return true
	elseif message:find('\1b@mcl_death_messages\1b') and minetest.settings:get_bool("mark_deathmessages") ~= false then
		minetest.display_chat_message(minetest.colorize("#F25819", "[Deathmessage] ") .. message)
		return true
	end
end)

function minetest.send_colorized(message)
	local starts_with = message:sub(1, 1)
	
	if starts_with == "/" or starts_with == "." then return end

	local reverse = minetest.settings:get_bool("chat_reverse")
	
	if reverse then
		local msg = ""
		for i = 1, #message do
			msg = message:sub(i, i) .. msg
		end
		message = msg
	end
	
	local use_chat_color = minetest.settings:get_bool("use_chat_color")
	local color = minetest.settings:get("chat_color")

	if use_chat_color and color then
		local msg
		if color == "rainbow" then
			msg = minetest.rainbow(message)
		else
			msg = minetest.colorize(color, message)
		end
		message = msg
	end
	
	minetest.send_chat_message(message)
	return true
end

minetest.register_on_sending_chat_message(minetest.send_colorized)


minetest.register_cheat("IgnoreStatus", "Chat", "ignore_status_messages")
minetest.register_cheat("DeathMessages", "Chat", "mark_deathmessages")
minetest.register_cheat("ColoredChat", "Chat", "use_chat_color")
minetest.register_cheat("ReversedChat", "Chat", "chat_reverse")
