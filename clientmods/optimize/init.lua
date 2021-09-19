-- CC0/Unlicense Emilia 2020

-- Optimizes stuff.


woptimize={}

function woptimize.countents()
    local obj = minetest.localplayer.get_nearby_objects(10000)
    ws.dcm("Entity count: "..#obj)
end


-- texture is a prefix
local function remove_ents(texture)
    if not minetest.localplayer then return end
    local obj = minetest.localplayer.get_nearby_objects(10000)

    for i, v in ipairs(obj) do
        -- CAOs with water/lava textures are droplets
        --minetest.log("ERROR",v:get_item_textures())
        --ws.dcm(v:get_item_textures())
	local txt=v:get_item_textures()
        if type(txt) == "string" and txt:find(texture) then
            v:set_visible(false)
            v:remove(true)
        end
    end
end



local function remove_hud(name)
	local player = minetest.localplayer
	local def
	local i = -1
	if not player then return end
	repeat
		i = i + 1
		def = player:hud_get(i)
	until not def or def.text:find(name)
	if def then
	    minetest.localplayer:hud_remove(i)
	end
end


core.register_on_spawn_particle(function(particle)
    if minetest.settings:get_bool("noparticles") then return true end
end)

local epoch = os.clock()

minetest.register_globalstep(function()
    if not minetest.localplayer then return end
    if os.clock() > epoch + 1 then
        if minetest.settings:get_bool("optimize_water_drops") then
            remove_ents("default_water_source")
        end
        if minetest.settings:get_bool("optimize_burning") then
	    remove_hud('mcl_burning_hud_flame_animated.png')
        end
        epoch = os.clock()
    end
end)


minetest.register_cheat("NoParticles", "Render", "noparticles")
minetest.register_cheat("NoDroplets", "Render", "optimize_water_drops")
minetest.register_cheat("NoBurning", "Render", "optimize_burning")
