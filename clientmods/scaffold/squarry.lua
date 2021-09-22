local sq_pos1={x=-30800,y=1,z=-30800}
local sq_pos2={x=-30880,y=80,z=-30880}
local digging=false
local flying=false
local target=vector.new(0,0,0)


local function between(x, y, z) return y <= x and x <= z end -- x is between y and z (inclusive)

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

local function get_nodes_in_range(range,air)
    local lp=minetest.localplayer:get_pos()
    local p1=vector.add(lp,{x=range,y=range,z=range})
    local p2=vector.add(lp,{x=-range,y=-range,z=-range})
    local nn=nlist.get_mclnodes()
    if air then table.insert(nn,'air') end
    local nds,cnt=minetest.find_nodes_in_area(p1,p2,nn,true)
    local rt={}
    for k,v in pairs(nds) do for kk,vv in pairs(v) do
        local nd=minetest.get_node_or_nil(vv)
        if nd then table.insert(rt,vv) end
    end end
    return rt
end

local function get_randompos(wpos1,wpos2)
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
    return vector.new(math.random(xmin,xmax),math.random(ymin,ymax),math.random(zmin,zmax))
end

local nextdig=0
local function flythere(pos)
    flying=true
    minetest.settings:set_bool('noclip',false)
    minetest.settings:set_bool('scaffold_quarrytool',true)
    minetest.settings:set_bool("pitch_move",true)
    minetest.settings:set_bool("free_move",true)
    minetest.settings:set_bool("continuous_forward",true)
    autofly.aim(pos)
    core.set_keypress("special1", true)
end

local function stopflight()
    flying=false
    digging=true
    minetest.settings:set_bool("continuous_forward",false)
    minetest.settings:set_bool('scaffold_walltool',false)
    minetest.settings:set_bool("noclip",false)
    minetest.settings:set_bool("pitch_move",false)
    core.set_keypress("special1", false)
end

local function do_nodes_in_range(action)
    local nds={}
    if action == 'dig' then nds=get_nodes_in_range(6)
    else nds=get_nodes_in_range(6,true) end
    if #nds > 0 then diggin=true else diggin=false end
    for k,v in pairs(nds) do
        if v then
            --minetest.switch_to_item("mcl_books:book_written")
            if action == 'dig' then
                minetest.select_best_tool(minetest.get_node_or_nil(v).name)
                minetest.dig_node(v)
            else
                local headpos=vector.add(minetest.localplayer:get_pos(),{x=0,y=0,z=0})
                if vector.distance(headpos,v) == 0 then return end
                scaffold.place_if_able(v)
            end
        end
    end

end
--randomseed(os.clock())
scaffold.register_template_scaffold("QuarryTool", "scaffold_quarrytool", function(pos)

    do_nodes_in_range('dig')
end)
scaffold.register_template_scaffold("PlaceRange", "scaffold_placer", function(pos)
    do_nodes_in_range()
    local headpos=vector.add(minetest.localplayer:get_pos(),vector.new(0,1,0))
    local headnod=minetest.get_node_or_nil(headpos)
    if headnod.name ~= 'air' then scaffold.dig(headpos) end
end)
local qbot_wason=false

ws.register_globalhacktemplate("QuarryBot", "Bots", "scaffold_quarrybot", function(pos)
    local lp=minetest.localplayer:get_pos()
    if not digging and not flying then
        local nds=get_nodes_in_range(50)
        if #nds == 0 then
            target=get_randompos(sq_pos1,sq_pos2)
        else
            target=nds[math.random(#nds)]
        end
        flythere(target)
    elseif vector.distance(lp,target) < 5 then
        stopflight()
    end
end,function()
    scaffold.set_pos1(sq_pos1)
    scaffold.set_pos2(sq_pos2)
    minetest.settings:set_bool('scaffold_constrain',true)
    minetest.settings:set_bool('scaffold_quarrytool',true)
end,function()
    qbot_wason=false
    flying=false
    digging=false
    minetest.settings:set_bool('scaffold_quarrytool',false)
    stopflight()
end)
