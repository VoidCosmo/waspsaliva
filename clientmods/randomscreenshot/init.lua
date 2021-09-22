---
-- random screenshots


randomscreenshot = {}

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
    randomscreenshot_interval = 10,
    randomscreenshot_rnd = 10
})

local nextsc=0

minetest.register_globalstep(function()
    if not minetest.settings:get_bool("randomsc") then return end
    if os.time() < nextsc then return end
    math.randomseed(os.clock())
    nextsc=os.time() + ( minetest.settings:get('randomscreenshot_interval') * 60 ) + math.random(minetest.settings:get('randomscreenshot_rnd') * 60)
    minetest.after("15.0",function()
        minetest.hide_huds()
        --minetest.display_chat_message("\n\n\n\n\n\n\n\n\n")
        minetest.after("0.05",minetest.take_screenshot)
        minetest.after("0.1",function()
            minetest.show_huds()
        end)
    end)
end)

if (_G["minetest"]["register_cheat"] ~= nil) then
    minetest.register_cheat("Random Screenshot", "World", "randomsc")
else
    minetest.settings:set_bool('randomsc',true)
end
