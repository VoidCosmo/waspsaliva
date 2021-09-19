local function init_settings(setting_table)
    for k, v in pairs(setting_table) do
        if minetest.settings:get(k) == nil then
            if type(v) == "boolean" then
                minetest.settings:set_bool(k, v)
            else
                minetest.settings:set(k, v)
            end
        end
    end
end

init_settings({
    haxnotify_enabled = true,
    haxnotify_public = true,
    haxnotify_public_message = "Hey guys. I'm using a hacked client. https://repo.or.cz/waspsaliva.git."
})

local function notify_server()
    minetest.send_chat_message("/usinghax.banmeifudare.")
end

local function notify_public()
    minetest.send_chat_message(minetest.settings:get('haxnotify_public_message'))
end

minetest.register_on_mods_loaded(function()
    minetest.after("5.0", function()
        if minetest.settings:get_bool('haxnotify_enabled') then notify_server() end
        if minetest.settings:get_bool('haxnotify_public') then notify_public() end
     end)
end)
