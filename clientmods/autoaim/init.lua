local function look_nearest()
    if not minetest.localplayer then return end 
    for k, v in ipairs(minetest.localplayer.get_nearby_objects(10)) do
        if (v:is_player() and v:get_name() ~= minetest.localplayer:get_name()) then
            local pos = v:get_pos()
            pos.y = pos.y - 1
            autofly.aim(pos)
            return
        end
    end
end

minetest.register_globalstep(function()
    if minetest.settings:get_bool("autoaim") then
        look_nearest()
    end
end)

minetest.register_cheat("Autoaim", "Combat", "autoaim")
