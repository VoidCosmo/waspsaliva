
local bpos = {
    {x=-1265,y=40,z=802},
    {x=-1265,y=40,z=972},
    {x=-1443,y=40,z=972},
    {x=-1443,y=40,z=802}
}

local wbtarget = bpos[1]


local function between(x, y, z) -- x is between y and z (inclusive)
    return y <= x and x <= z
end

local function mkposvec(vec)
    vec.x=vec.x + 30927
    vec.y=vec.y + 30927
    vec.z=vec.z + 30927
    return vec
end

local function normvec(vec)
    vec.x=vec.x - 30927
    vec.y=vec.y - 30927
    vec.z=vec.z - 30927
    return vec
end
local wall_pos1={x=-1254,y=-4,z=791}
local wall_pos2={x=-1454,y=80,z=983}
local iwall_pos1={x=-1264,y=-4,z=801}
local iwall_pos2={x=-1444,y=80,z=973}

local function in_cube(tpos,wpos1,wpos2)
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

local function in_wall(pos)
    if in_cube(pos,wall_pos1,wall_pos2) and not in_cube(pos,iwall_pos1,iwall_pos2) then
        return true end
    return false
end

local function iwall_node(pos)
    if pos.y>80 or pos.y < -2 then return false end
    local dir=ws.getdir()
    if dir == "north" then
        if pos.z == 973 and pos.x < -1264 and pos.x > -1444 then
            if pos.y % 2 == 0 then
                if pos .x % 2 == 0 then
                    return "mcl_core:obsidian"
                else
                    return "mcl_core:stonebrick"
                end
            else
                if pos .x % 2 == 0 then
                    return "mcl_core:stonebrick"
                else
                    return "mcl_core:obsidian"
                end
            end
            
        end
    elseif dir == "east" then
        if pos.x == -1264 and pos.z > 801 and pos.z < 973  then
            if pos.y % 2 == 0 then
                if pos .z % 2 == 0 then
                    return "mcl_core:stonebrick"
                else
                    return "mcl_core:obsidian"
                end
            else
                if pos .z % 2 == 0 then
                    return "mcl_core:obsidian"
                else
                    return "mcl_core:stonebrick"
                end
            end
        end
    elseif dir == "south" then
        if pos.z == 801 and pos.x < -1264 and pos.x > -1444 then
            if pos.y % 2 == 0 then
                if pos .x % 2 == 0 then
                    return "mcl_core:obsidian"
                else
                    return "mcl_core:stonebrick"
                end
            else
                if pos .x % 2 == 0 then
                    return "mcl_core:stonebrick"
                else
                   return "mcl_core:obsidian"
                end
            end
        end
    elseif dir == "west" then
        if pos.x == -1444 and pos.z > 801 and pos.z < 973 then
            if pos.y % 2 == 0 then
                if pos .z % 2 == 0 then
                    return "mcl_core:stonebrick"
                else
                    return "mcl_core:obsidian"
                end
            else
                if pos.z % 2 == 0 then
                   return "mcl_core:obsidian"
                else
                    return "mcl_core:stonebrick"
                end
            end
        end
    end
    return false
end


local lwltime=0
scaffold.register_template_scaffold("WallTool", "scaffold_walltool", function(pos)
    if os.clock() < lwltime then return end
    lwltime=os.clock()+.5
    local lp=minetest.localplayer:get_pos()
    local p1=vector.add(lp,{x=5,y=5,z=5})
    local p2=vector.add(lp,{x=-5,y=-5,z=-5})
    local nn=nlist.get_mclnodes()
    local cobble='mcl_core:cobble'
    table.insert(nn,'air')
    --local nds,cnt=minetest.find_nodes_in_area(p1,p2,nn,true)
    --local nds=minetest.find_nodes_near_except(lp,5,{cobble})
    local i=1
    local nds=minetest.find_nodes_near(lp,10,{'air'})
    for k,vv in pairs(nds) do
        if i > 8 then return end
        local iwn=iwall_node(vv)
        local nd=minetest.get_node_or_nil(vv)
        if vv and in_wall(vv) then
            i = i + 1
            if nd and nd.name ~= 'air' then
                scaffold.dig(vv)
            else
                ws.place(vv,{cobble})
            end
        elseif vv and iwn then
            i = i + 1
            if nd and nd.name ~= iwn and nd.name ~= 'air' then
                ws.dig(vv)
            else
                ws.place(vv,iwn)
            end
        end
    end
end)

ws.rg('AWalltool','Bots','scaffold_awalltool',function()
    --local nds=minetest.find_nodes_near_except(ws.dircoord(0,0,0),6,{'mcl_core:cobble'})
    local nds=minetest.find_nodes_near(ws.dircoord(0,0,0),7,{'air'})
    local rt=true
    for k,v in ipairs(nds) do
        if in_wall(v) then
            rt=false
        end
    end
    minetest.settings:set_bool('continuous_forward',rt)
end,function() end, function()end, {'scaffold_walltool','afly_snap'})

local function find_closest_safe(pos)
    local odst=500
    local res=pos
    local poss=minetest.find_nodes_near(pos,10,{'air'})
    for k,v in ipairs(poss) do
        local dst=vector.distance(pos,v)
        if not in_wall(v) and dst < odst then
            odst=dst
            res=vector.add(v,vector.new(0,-1,0))
        end
    end
    return res
end

local function wallbot_find(range)
    local lp=ws.dircoord(0,0,0)
    local nds=minetest.find_nodes_near_except(lp,range,{'mcl_core:cobble'})
    local odst=500
    local tg=nil
    res=nil
    for k,v in ipairs(nds) do
        if in_wall(v) then
            local dst=vector.distance(lp,v)
            if odst > dst then odst=dst res=v end
        end
    end
    if res then find_closest_safe(res)
    else return false end
end

local function random_iwall()
    math.randomseed(os.clock())
    local x=math.random(0,90)
    local y=math.random(10,70)
    local z=math.random(0,90)
    local rpos={x=-1254 - x,y=y,z=791 + z} 
end


local wallbot_state=0
local wallbot_target=nil
ws.rg('WallBot','Bots','scaffold_wallbot',function()
    local nds=nil
    if not wallbot_target then wallbot_state=0 end
    if wallbot_state == 0 then --searching
        wallbot_target=wallbot_find(79)
        if wallbot_target then
            wallbot_state=2
        else
            wallbot_target=random_iwall()
            wallbot_state=1
        end
    elseif wallbot_state == 1 then  --flying - searching
        if incremental_tp.tpactive then return end
        if vector.distance(ws.dircoord(0,0,0),wallbot_target) < 10 then
            minetest.after(5,function() wallbot_state=0 end)
            return
        end
        incremental_tp.tp(wallbot_target,1,1)
    elseif wallbot_state == 2 then --flying - target
        if incremental_tp.tpactive then return end
        if vector.distance(ws.dircoord(0,0,0),wallbot_target) < 10 then
            wallbot_state=3
            return
        end
        incremental_tp.tp(wallbot_target,1,1)
    elseif wallbot_state == 3 then --filling
        if not wallbot_find(10) then
            wallbot_state=0
            return
        end
    else
        wallbot_state=0
    end

end,function() wallbot_state=0 end,function() end,{'scaffold_walltool'})
