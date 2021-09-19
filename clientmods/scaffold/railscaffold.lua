-- CC0/Unlicense Emilia/cora 2020

-- south:5,1.5
--west:-x,1.5,-5
--east:-x,1.5,5
-- north 5,1.5(3096:2.5,25025:1.5),z
local direction = ""
local ground = {
    "mesecons_torch:redstoneblock"
}

local rails = {
    "mcl_minecarts:golden_rail",
    "mcl_minecarts:rail"
}

local tunnelmaterial = {
    'mcl_core:glass_light_blue',
    'mcl_core:glass',
    'mcl_core:cobble',
    'mcl_core:stone',
    'mcl_nether:netherrack',
    'mcl_core:dirt',
    'mcl_core:andesite',
    'mcl_core:diorite',
    'mcl_core:granite',
    "mesecons_torch:redstoneblock"
}

local lightblock = "mcl_ocean:sea_lantern"
--local lightblock = "mcl_nether:glowstone"

local function is_rail(pos)
    pos=vector.round(pos)
    if pos.y ~= 1 then return false end
    if pos.z > 5 then
        if pos.x == -5 then return "north" end
    elseif pos.z < -5 then
        if pos.x == 5 then return "south" end
    end
    if pos.x > 5 then
        if pos.z == 5 then return "east" end
    elseif pos.x < -5 then
        if pos.z == -5 then return "west" end
    end
    return false
end

local function get_railnode(pos)
    if is_rail(pos) then
        return "mcl_minecarts:golden_rail"
    end
    if is_rail(vector.add(pos,{x=0,y=-1,x=0})) then
        return "mesecons_torch:redstoneblock"
    end
    return false
end

local function is_lantern(pos)
   local dir=ws.getdir()
   pos=vector.round(pos)
   if dir == "north" or dir == "south" then
        if pos.z % 8 == 0 then
            return true
        end
   else
        if pos.x % 8 == 0 then
            return true
        end
   end
   return false
end




local function checknode(pos)
    local lp = ws.dircoord(0,0,0)
    local node = minetest.get_node_or_nil(pos)
    if pos.y == lp.y then
        if node and not node.name:find("_rail") then return true end
    elseif node and node.name ~="mesecons_torch:redstoneblock" then return true
    end
    return false
end

local function dignodes(poss)
    for k,v in pairs(poss) do
        if checknode(v) then ws.dig(v) end
    end
end

local function findliquids(pos,range)
    range = range or 1
    if not pos then return end
    local liquids={'mcl_core:lava_source','mcl_core:water_source','mcl_core:lava_flowing','mcl_core:water_flowing','mcl_nether:nether_lava_source','mcl_nether:nether_lava_flowing'}
    local bn=minetest.find_nodes_near(pos, range, liquids, true)
    if #bn < 0 then return bn end
    return false
end

local function blockliquids(pos)
    if not pos then return end
    local lp=ws.dircoord(0,0,0)
    local liquids={'mcl_core:lava_source','mcl_core:water_source','mcl_core:lava_flowing','mcl_core:water_flowing','mcl_nether:nether_lava_source','mcl_nether:nether_lava_flowing'}
    local bn=minetest.find_nodes_near(pos, 1, liquids, true)
    local rt=false
    if not bn then return rt end
    for kk,vv in pairs(bn) do
        if vv.y > lp.y - 1 or vv.y < -40 then
            rt=true
            scaffold.place_if_needed(tunnelmaterial,vv)
            for i=-4,5,1 do
                local tpos=vector.new(pos.x,lp.y,pos.z)
                scaffold.place_if_needed(tunnelmaterial,ws.dircoord(i,2,0,tpos))
                scaffold.place_if_needed(tunnelmaterial,ws.dircoord(i,0,1,tpos))
                scaffold.place_if_needed(tunnelmaterial,ws.dircoord(i,1,1,tpos))
                scaffold.place_if_needed(tunnelmaterial,ws.dircoord(i,0,-1,tpos))
                scaffold.place_if_needed(tunnelmaterial,ws.dircoord(i,1,-1,tpos))
            end
        end
    end
    return rt
end

local function digob(sc)
    local obpos={
        ws.dircoord(0,1,2,sc),
        ws.dircoord(0,1,-2,sc),
        ws.dircoord(0,1,1,sc),
        ws.dircoord(0,1,-1,sc),
        ws.dircoord(0,0,1,sc),
        ws.dircoord(0,0,-1,sc)
    }
    ws.dignodes(obpos,function(pos)
        local nd=minetest.get_node_or_nil(pos)
        if nd and (nd.name == "mcl_core:obsidian" or  nd.name == "mcl_minecarts:golden_rail_on" or nd.name == "mcl_minecarts:golden_rail" )then return true end
        return false
    end)
end

local function invcheck(item)
    if mintetest.switch_to_item(item) then return true end
    refill.refill_at(ws.dircoord(1,1,0),'railkit')
end

local function invcheck(item)
    if mintetest.switch_to_item(item) then return true end
    refill.refill_at(ws.dircoord(1,1,0),'railkit')
end
local function rnd(n)
    return math.ceil(n)
end

local function fmt(c)
    return tostring(rnd(c.x))..","..tostring(rnd(c.y))..","..tostring(rnd(c.z))
end
local function map_pos(value)
    if value.x then
        return value
    else
        return {x = value[1], y = value[2], z = value[3]}
    end
end

local function invparse(location)
    if type(location) == "string" then
        if string.match(location, "^[-]?[0-9]+,[-]?[0-9]+,[-]?[0-9]+$") then
            return "nodemeta:" .. location
        else
            return location
        end
    elseif type(location) == "table" then
        return "nodemeta:" .. fmt(map_pos(location))
    end
end

local function take_railkit(pos)
    local plinv = minetest.get_inventory(invparse(pos))
    local epos=ws.find_named(plinv,'railkit')
   local mv = InventoryAction("move")
    mv:from(invparse(pos), "main", epos)
    mv:to("current_player", "main", 8)
    mv:apply()
    minetest.localplayer:set_wield_index(8)
    return true

end

local restashing=false
function scaffold.restash()
    if restashing then return end
    restashing=true
    ws.dig(ws.dircoord(1,0,1))
    ws.dig(ws.dircoord(1,1,1))
    ws.dig(ws.dircoord(2,0,1))
    ws.dig(ws.dircoord(2,1,1))

    ws.place(ws.dircoord(1,0,1),{'mcl_chests:chest_small','mcl_chests:chest'})
    ws.place(ws.dircoord(1,1,1),{'railroad'})
    take_railkit(ws.dircoord(1,1,1))
    minetest.after("0.5",function()
        ws.place(ws.dircoord(2,0,1),{'railkit'})
        ws.dig(ws.dircoord(1,1,1))
    end)
    minetest.after("1.0",function()
        autodupe.invtake(ws.dircoord(2,0,1))
        restashing=false
    end)
end


local function slowdown(s)
    minetest.localplayer:set_velocity(vector.new(0,0,0))
    minetest.settings:set('movement_speed_fast',math.abs(s))
end
local fullspeed=100
local function speedup()
         minetest.settings:set('movement_speed_fast',fullspeed)
end


ws.rg("RailBot","Bots", "railbot", function()
    local oldi=500
    for i=-50,50,1 do
        local lpos=ws.dircoord(i,2,0)
        local lpn=minetest.get_node_or_nil(ws.dircoord(i,0,0))
        local bln=minetest.get_node_or_nil(ws.dircoord(i,-1,0))
        local ltpn=minetest.get_node_or_nil(lpos)
        if not bln or not lpn or not ltpn then
            speedup()
        elseif ( is_lantern(lpos) and ltpn.name ~= lightblock ) then
            if (oldi > i) then
                slowdown(8)
                oldi=i
            end
        elseif bln.name=="mesecons_torch:redstoneblock" and lpn.name == "mcl_minecarts:golden_rail_on" then
            speedup()
        else
            if (oldi > i) then
                slowdown(8)
                oldi=i
            end
        end
    end
    
    local goon=false
    for i=-4,4,1 do
        local lpos=ws.dircoord(i,2,0)
        local lpn=minetest.get_node_or_nil(ws.dircoord(i,0,0))
        local bln=minetest.get_node_or_nil(ws.dircoord(i,-1,0))
        local lpos=ws.dircoord(i,2,0)
        
        if not ( bln and bln.name=="mesecons_torch:redstoneblock" and lpn and lpn.name == "mcl_minecarts:golden_rail_on" ) then
            goon=false
        else
            goon=true
        end

        digob(ws.dircoord(i,0,0))
        
        blockliquids(ws.dircoord(i,1,0))
        blockliquids(ws.dircoord(i,0,0))
        ws.dig(ws.dircoord(i,1,0))
        if checknode(ws.dircoord(i,0,0)) then ws.dig(ws.dircoord(i,0,0)) end
        if checknode(ws.dircoord(i,-1,0)) then ws.dig(ws.dircoord(i,-1,0)) end
        ws.place(ws.dircoord(i,-1,0),ground,7)
        ws.place(ws.dircoord(i,0,0),rails,6)
        
        local lpos=ws.dircoord(i,2,0)
        if is_lantern(lpos) then
            local ln=minetest.get_node_or_nil(lpos)
            if not ln or ln.name ~= lightblock then
                goon=false
                ws.dig(lpos)
                ws.place(lpos,{lightblock},5)
            end
        end
    end

    if (goon) then
        local dir=ws.getdir()
        local lp=minetest.localplayer:get_pos()
        local rlp=vector.round(lp)
        minetest.localplayer:set_pos(vector.new(rlp.x,lp.y,rlp.z))
        minetest.settings:set_bool('continuous_forward',true)
    else
        slowdown(5)
        minetest.localplayer:set_velocity(vector.new(0,0,0))
        minetest.settings:set_bool('continuous_forward',false)
    end


end,
function()--startfunc
    minetest.settings:set('movement_speed_fast',500)
    minetest.settings:set_bool('continuous_forward',false)
end,function() --stopfunc
    minetest.localplayer:set_velocity(vector.new(0,0,0))
    minetest.settings:set('movement_speed_fast',20)
    minetest.settings:set_bool('continuous_forward',false)
end,{'afly_snap','autorefill'}) --'scaffold_ltbm'



scaffold.register_template_scaffold("LanternTBM", "scaffold_ltbm", function()
   local dir=ws.getdir()
   local lp=vector.round(ws.dircoord(0,0,0))
   local pl=is_lantern(lp)
   if pl then
        local lpos=ws.dircoord(0,2,0)
        local nd=minetest.get_node_or_nil(lpos)
        if nd and nd.name ~= lightblock then
            ws.dig(lpos)
            ws.place(lpos,lightblock,5)
        end
   end
end)