if minetest.settings:get_bool("test_chain") then
    local prefix = minetest.get_modpath(minetest.get_current_modname())
    dofile(prefix .. "/chain.lua")
end
