local wason=false;
minetest.register_globalstep(function()
    if minetest.localplayer and minetest.settings:get_bool("movement_ignore_server_speed") then
        minetest.localplayer:set_speeds_from_local_settings()
        wason=true
    elseif wason then
        wason=false
        minetest.localplayer:set_speeds_from_server_settings()
    end
end)

minetest.register_cheat("IgnSrvSpd", "Movement", "movement_ignore_server_speed")
