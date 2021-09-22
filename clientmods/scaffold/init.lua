-- CC0/Unlicense Emilia & cora 2020

local category = "Scaffold"

scaffold = {}
scaffold.lockdir = false
scaffold.locky = false
scaffold.constrain1 = false
scaffold.constrain2 = false
local hwps={}

local multiscaff_width=5
local multiscaff_depth=1
local multiscaff_above=0
local multiscaff_mod=1

local storage=minetest.get_mod_storage()


local nodes_per_tick = 8

local function setnpt()
    nodes_per_tick = tonumber(minetest.settings:get("nodes_per_tick")) or 8
end

function scaffold.template(setting, func, offset, funcstop )
    offset = offset or {x = 0, y = -1, z = 0}
    funcstop = funcstop or function() end

    return function()
        if minetest.localplayer and minetest.settings:get_bool(setting) then
            if scaffold.constrain1 and not inside_constraints(tgt) then return end
            local tgt=vector.add(minetest.localplayer:get_pos(),offset)
            func(tgt)
        end
    end
end

function scaffold.register_template_scaffold(name, setting, func, offset, funcstop)
    ws.rg(name,'Scaffold',setting,scaffold.template(setting, func, offset),funcstop )
end

local function between(x, y, z) return y <= x and x <= z end -- x is between y and z (inclusive)

function scaffold.in_cube(tpos,wpos1,wpos2)
    local xmax=wpos2.x
    local xmin=wpos1.x

    local ymax=wpos2.y
    local ymin=wpos1.y

    local zmax=wpos2.z
    local zmin=wpos1.z
    if wpos1.x > wpos2.x then
        xmax=wpos1.x
        xmin=wpos2.x
    end
    if wpos1.y > wpos2.y then
        ymax=wpos1.y
        ymin=wpos2.y
    end
    if wpos1.z > wpos2.z then
        zmax=wpos1.z
        zmin=wpos2.z
    end
    if between(tpos.x,xmin,xmax) and between(tpos.y,ymin,ymax) and between(tpos.z,zmin,zmax) then
        return true
    end
    return false
end

local function set_hwp(name,pos)
    ws.display_wp(pos,name)
end

function scaffold.set_pos1(pos)
    if not pos then local pos=minetest.localplayer:get_pos() end
    scaffold.constrain1=vector.round(pos)
    local pstr=minetest.pos_to_string(scaffold.constrain1)
    set_hwp('scaffold_pos1 '..pstr,scaffold.constrain1)
    minetest.display_chat_message("scaffold pos1 set to "..pstr)
end
function scaffold.set_pos2(pos)
    if not pos then pos=minetest.localplayer:get_pos() end
    scaffold.constrain2=vector.round(pos)
    local pstr=minetest.pos_to_string(scaffold.constrain2)
    set_hwp('scaffold_pos2 '..pstr,scaffold.constrain2)
    minetest.display_chat_message("scaffold pos2 set to "..pstr)
end

function scaffold.reset()
    scaffold.constrain1=false
    scaffold.constrain2=false
    for k,v in pairs(hwps) do
        minetest.localplayer:hud_remove(v)
        table.remove(hwps,k)
    end
end

local function inside_constraints(pos)
    if (scaffold.constrain1 and scaffold.constrain2 and scaffold.in_cube(pos,scaffold.constrain1,scaffold.constrain2)) then return true
    elseif not scaffold.constrain1 then return true
    end
    return false
end

minetest.register_chatcommand("sc_pos1", { func = scaffold.set_pos1 })
minetest.register_chatcommand("sc_pos2", { func = scaffold.set_pos2 })
minetest.register_chatcommand("sc_reset", { func = scaffold.reset })




function scaffold.can_place_at(pos)
    local node = minetest.get_node_or_nil(pos)
    return (node and (node.name == "air" or node.name=="mcl_core:water_source" or node.name=="mcl_core:water_flowing" or node.name=="mcl_core:lava_source" or node.name=="mcl_core:lava_flowing" or minetest.get_node_def(node.name).buildable_to))
end

-- should check if wield is placeable
-- minetest.get_node(wielded:get_name()) ~= nil should probably work
-- otherwise it equips armor and eats food
function scaffold.can_place_wielded_at(pos)
    local wield_empty = minetest.localplayer:get_wielded_item():is_empty()
    return not wield_empty and scaffold.can_place_at(pos)
end


function scaffold.find_any_swap(items)
    local ts=8
    for i, v in ipairs(items) do
        local n = minetest.find_item(v)
        if n then
            ws.switch_to_item(v)
            return true
        end
    end
    return false
end

function scaffold.in_list(val, list)
    if type(list) ~= "table" then return false end
    for i, v in ipairs(list) do
        if v == val then
            return true
        end
    end
    return false
end

-- swaps to any of the items and places if need be
-- returns true if placed and in inventory or already there, false otherwise

local lastact=0
local lastplc=0
local lastdig=0
local actint=10
function scaffold.place_if_needed(items, pos, place)
    if not inside_constraints(pos) then return end
    if not pos then return end

    place = place or minetest.place_node

    local node = minetest.get_node_or_nil(pos)
    if not node then return end
    -- already there
    if node and scaffold.in_list(node.name, items) then
        return true
    else
        local swapped = scaffold.find_any_swap(items)

        -- need to place
        if swapped and scaffold.can_place_at(pos) then
            --minetest.after("0.05",place,pos)
            place(pos)
            return true
        -- can't place
        else
            return false
        end
    end
end

function scaffold.place_if_able(pos)
    if not pos then return end
    if not inside_constraints(pos) then return end
    if scaffold.can_place_wielded_at(pos) then
        minetest.place_node(pos)
    end
end

local function is_diggable(pos)
    if not pos then return false end
    local nd=minetest.get_node_or_nil(pos)
    if not nd then return false end
    local n = minetest.get_node_def(nd.name)
    if n and n.diggable then return true end
    return false
end

function scaffold.dig(pos)
    if not inside_constraints(pos) then return end
    if is_diggable(pos) then
        local nd=minetest.get_node_or_nil(pos)
        minetest.select_best_tool(nd.name)
        if emicor then emicor.supertool()
        end
        --minetest.select_best_tool(nd.name)
        minetest.dig_node(pos)

    end
    return false
end


local mpath = minetest.get_modpath(minetest.get_current_modname())
dofile(mpath .. "/sapscaffold.lua")
dofile(mpath .. "/slowscaffold.lua")
dofile(mpath .. "/autofarm.lua")
dofile(mpath .. "/railscaffold.lua")
dofile(mpath .. "/wallbot.lua")
dofile(mpath .. "/ow2bot.lua")
dofile(mpath .. "/atower.lua")
--dofile(mpath .. "/squarry.lua")
ws.rg('DigHead','Player','dighead',function() ws.dig(ws.dircoord(0,1,0)) end)



local function checknode(pos)
    local node = minetest.get_node_or_nil(pos)
    if node then return true end
    return false
end

minetest.register_chatcommand('scaffw', {
    func = function(param) multiscaff_width=tonumber(param) end
})
minetest.register_chatcommand('scaffd', {
    func = function(param) multiscaff_depth=tonumber(param) end
})
minetest.register_chatcommand('scaffa', {
    func = function(param) multiscaff_above=tonumber(param) end
})
minetest.register_chatcommand('scaffm', {
    func = function(param) multiscaff_mod=tonumber(param) end
})

local multiscaff_node=nil
ws.rg('MultiScaff','Scaffold','scaffold',function()
	if not multiscaff_node then return end
	local n=math.floor(multiscaff_width/2)
	for i=-n,n do
		for j=(multiscaff_depth * -1), -1 do
			local p=ws.dircoord(0,j,i)
			local nd=minetest.get_node_or_nil(p)
			ws.place(p,{multiscaff_node})
		end
	end
end,function() 
	multiscaff_node=minetest.localplayer:get_wielded_item():get_name()
	ws.dcm("Multiscaff started. Width: "..multiscaff_width..', depth:'..multiscaff_depth..' Selected node: '..multiscaff_node)
end,function() 
	ws.dcm("Multiscaff stopped")
end)

ws.rg('MScaffModulo','Scaffold','multiscaffm',function()
	if not multiscaff_node then return end
	ws.switch_to_item(multiscaff_node)
	local n=math.floor(multiscaff_width/2)
	for i=-n,n do
		for j=(multiscaff_depth * -1), -1 do
			local p=vector.round(ws.dircoord(0,j,i))
			if p.z % multiscaff_mod == 0 then
				if p.x % multiscaff_mod ~=0 then
					core.place_node(p)
				end
			else
				if p.x % multiscaff_mod == 0 then
					core.place_node(p)
				end
			end
		end
	end
end,function() 
	multiscaff_node=minetest.localplayer:get_wielded_item():get_name()
	ws.dcm("ModuloScaff started. Width: "..multiscaff_width..', depth:'..multiscaff_depth..' Selected node: '..multiscaff_node)
end,function() 
	ws.dcm("Moduloscaff stopped")
end)



scaffold.register_template_scaffold("WallScaffold", "scaffold_five_down", function(pos)
    scaffold.place_if_able(ws.dircoord(0, -1, 0))
    scaffold.place_if_able(ws.dircoord(0, -2, 0))
    scaffold.place_if_able(ws.dircoord(0, -3, 0))
    scaffold.place_if_able(ws.dircoord(0, -4, 0))
    scaffold.place_if_able(ws.dircoord(0, -5, 0))
end)


scaffold.register_template_scaffold("headTriScaff", "scaffold_three_wide_head", function(pos)
    scaffold.place_if_able(ws.dircoord(0, 3, 0))
    scaffold.place_if_able(ws.dircoord(0, 3, 1))
    scaffold.place_if_able(ws.dircoord(0, 3, -1))
end)

scaffold.register_template_scaffold("RandomScaff", "scaffold_rnd", function(below)
    local n = minetest.get_node_or_nil(below)
    local nl=nlist.get('randomscaffold')
    table.shuffle(nl)
    if n and not scaffold.in_list(n.name, nl) then
        scaffold.dig(below)
        scaffold.place_if_needed(nl, below)
    end
end)


ws.rg("HighwayZ","World","highwayz",function() 
    local positions = {
        {x = 0, y = 0, z = z},
        {x = 1, y = 0, z = z},
        {x = 2, y = 1, z = z},
        {x = -2, y = 1, z = z},
        {x = -2, y = 0, z = z},
        {x = -1, y = 0, z = z},
        {x = 2, y = 0, z = z}
    }
    for i, p in pairs(positions) do
        if i > nodes_per_tick then break end
        minetest.place_node(p)
    end

end, setnpt)

ws.rg("BlockWater","World","block_water",function()
    local lp=ws.dircoord(0,0,0)
    local positions = minetest.find_nodes_near(lp, 5, {"mcl_core:water_source", "mcl_core:water_flowing"}, true)
    for i, p in pairs(positions) do
        if i > nodes_per_tick then return end
        minetest.place_node(p)
    end
end,setnpt)

ws.rg("BlockLava","World","block_lava",function()
    local lp=ws.dircoord(0,0,0)
    local positions = minetest.find_nodes_near(lp, 5, {"mcl_core:lava_source", "mcl_core:lava_flowing"}, true)
    for i, p in pairs(positions) do
        if i > nodes_per_tick then return end
        minetest.place_node(p)
    end
end,setnpt)

ws.rg("BlockSources","World","block_sources",function()
    local lp=ws.dircoord(0,0,0)
    local positions = minetest.find_nodes_near(lp, 5, {"mcl_core:lava_source","mcl_nether:nether_lava_source","mcl_core:water_source"}, true)
    for i, p in pairs(positions) do
        if p.y<2 then
            if p.x>500 and p.z>500 then return end
        end

        if i > nodes_per_tick then return end
        minetest.place_node(p)
    end
end,setnpt)

ws.rg("PlaceOnTop","World","place_on_top",function()
    local lp=ws.dircoord(0,0,0)
    local positions = minetest.find_nodes_near_under_air_except(lp, 5, item:get_name(), true)
    for i, p in pairs(positions) do
        if i > nodes_per_tick then break end
        minetest.place_node(vector.add(p, {x = 0, y = 1, z = 0}))
    end
end,setnpt)

ws.rg("Nuke","World","nuke",function()
    local pos=ws.dircoord(0,0,0)
    local i = 0
    for x = pos.x - 4, pos.x + 4 do
        for y = pos.y - 4, pos.y + 4 do
            for z = pos.z - 4, pos.z + 4 do
                local p = vector.new(x, y, z)
                local node = minetest.get_node_or_nil(p)
                local def = node and minetest.get_node_def(node.name)
                if def and def.diggable then
                    if i > nodes_per_tick then return end
                    minetest.dig_node(p)
                    i = i + 1
                end
            end
        end
    end
end,setnpt)