-- autofly by cora
-- gui shit shamelessly stolen from advmarkers
-- https://git.minetest.land/luk3yx/advmarkers-csm
--[[
    PATCHING MINETEST: (for autoaim)
in l_localplayer.h add:
	static int l_set_yaw(lua_State *L);
	static int l_set_pitch(lua_State *L);

in l_localplayer.cpp add:
    int LuaLocalPlayer::l_set_yaw(lua_State *L)
    {
        LocalPlayer *player = getobject(L, 1);
        f32 p = (float) luaL_checkinteger(L, 2);
        player->setYaw(p);
        g_game->cam_view.camera_yaw = p;
        g_game->cam_view_target.camera_yaw = p;
        player->setYaw(p);
        return 0;
    }
    int LuaLocalPlayer::l_set_pitch(lua_State *L)
    {
        LocalPlayer *player = getobject(L, 1);
        f32 p = (float) luaL_checkinteger(L, 2);
        player->setPitch(p);
        g_game->cam_view.camera_pitch = p;
        g_game->cam_view_target.camera_pitch = p;
        player->setPitch(p);
        return 0;
    }
in src/client/game.h, below class Game { public: add:
	CameraOrientation cam_view = {0};
	CameraOrientation cam_view_target  = { 0 };

from src/client/game.cpp remove
    CameraOrientation cam_view = {0};
	CameraOrientation cam_view_target  = { 0 };

--]]

-- Chat commands:
-- .wa x,y,z name - add waypoint with coords and name
-- .wah - quickadd this location (name will be time and date)
-- .wp - open the selection menu
-- .cls - remove hud

autofly = {}
wps={}


local landing_distance=5
local speed=0;
local ltime=0

local storage = minetest.get_mod_storage()
local oldpm=false
local lpos={x=0,y=0,z=0}
local info=minetest.get_server_info()
local stprefix="autofly-".. info['address']  .. '-'
--local stprefix="autofly-"
local hud_wps={}
autofly.flying=false
autofly.cruiseheight = 30

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
dofile(modpath .. "/wpforms.lua")
dofile(modpath .. "/pathfly.lua")

local hud_wp
local hud_info
-- /COMMON
local pos_to_string = ws.pos_to_string
local string_to_pos = ws.string_to_pos


function autofly.get2ddst(pos1,pos2)
    return vector.distance({x=pos1.x,y=0,z=pos1.z},{x=pos2.x,y=0,z=pos2.z})
end

local last_sprint = false
local hud_ah=nil



function autofly.update_ah()
    local pos=vector.new(0,0,0)
    local ppos=minetest.localplayer:get_pos()
    local yaw=math.floor(minetest.localplayer:get_yaw())

    local theta =(yaw * math.pi / 180)
	pos.x= math.floor( 100 * math.cos(theta) )
	pos.z= math.floor( 100 * math.sin(theta) )
    pos=vector.add(ppos,pos)
    pos.y=ppos.y
    local nname=pos_to_string(pos).."\n"..yaw.."\n"..'__________________________________________________________________________________________________________________________________________________'
    if hud_ah then
        minetest.display_chat_message(pos.x..","..pos.z)
        minetest.localplayer:hud_change(hud_ah, 'world_pos', pos)
        minetest.localplayer:hud_change(hud_ah, 'name', nname)
    else
        hud_ah = minetest.localplayer:hud_add({
            hud_elem_type = 'waypoint',
            name          = nname,
            title       = pos_to_string(pos),
            text          = '',
            number        = 0x00ff00,
            world_pos     = pos,
            precision     = 0,
            width         = 1000
        })
    end
end
minetest.register_globalstep(function()

    if not minetest.localplayer then return end
  -- autofly.update_ah()
end)

minetest.register_globalstep(function()
    if not minetest.localplayer then return end

    autofly.axissnap()
    if minetest.settings:get_bool("autosprint") or (minetest.settings:get_bool("continuous_forward") and minetest.settings:get_bool("autofsprint")) then
        core.set_keypress("special1", true)
        last_sprint = true
    elseif last_sprint then
        core.set_keypress("special1", false)
        last_sprint = false
    end
    if not autofly.flying then autofly.set_hud_info("")
     else
        autofly.set_hud_info("")
        local pos = autofly.last_coords
        if pos then
            local dst = vector.distance(pos,minetest.localplayer:get_pos())
            local etatime=-1
            if not (speed == 0) then etatime = ws.round2(dst / speed / 60,2) end
            autofly.etatime=etatime
            autofly.set_hud_info(autofly.last_name .. "\n" .. pos_to_string(pos) .. "\n" .. "ETA" .. etatime .. " mins")
            local pm=minetest.settings:get_bool('pitch_move')
            local hdst=autofly.get2ddst(pos,minetest.localplayer:get_pos())
            if pm then hdst=vector.distance(pos,ws.dircoord(0,0,0)) end
            if  autofly.flying and hdst < landing_distance then
                autofly.arrived()
            end
        end
    end

    if not minetest.settings:get_bool("freecam") and autofly.flying and (minetest.settings:get_bool('afly_autoaim')) then
        autofly.aim(autofly.last_coords)
    end

    if ( os.time() < ltime + 1 ) then return end
    ltime=os.time()
    if lpos then
        local dst=vector.distance(minetest.localplayer:get_pos(),lpos)
        speed=ws.round2(dst,1)
        autofly.speed=speed
    end
    lpos=minetest.localplayer:get_pos()
    autofly.cruise()
end)

function autofly.get_speed()
    return speed
end


function autofly.set_hud_wp(pos, title)
    if hud_wp then
            minetest.localplayer:hud_remove(hud_wp)
    end
    pos = string_to_pos(pos)
    hud_wp=nil
    if not pos then return end
    if not title then
        title = pos.x .. ', ' .. pos.y .. ', ' .. pos.z
    end
    autofly.last_name=title
    if hud_wp then
        minetest.localplayer:hud_change(hud_wp, 'name', title)
        minetest.localplayer:hud_change(hud_wp, 'world_pos', pos)
    else
        hud_wp = minetest.localplayer:hud_add({
            hud_elem_type = 'waypoint',
            name          = title,
            text          = 'm',
            number        = 0x00ff00,
            world_pos     = pos
        })
    end
    return true
end

local hud_info
function autofly.get_quad()
    local lp=minetest.localplayer:get_pos()
    local quad=""

    if lp.z < 0 then quad="South"
    else quad="North" end

    if lp.x < 0 then quad=quad.."-west"
    else quad=quad.."-east" end

    return quad
end

function autofly.get_wdir()
    local qd=autofly.get_quad()

end



function autofly.get_local_name()
    local ww=autofly.getwps()
    local lp=minetest.localplayer:get_pos()
    local odst=500;
    local rt=false
    for k,v in pairs(ww) do
        local lwp=autofly.get_waypoint(v)
        if type(lwp) == 'table' then
            local dst=vector.distance(lp,lwp)
            if dst < 500 then
                if dst < odst then
                    odst=dst
                    rt=v
                end
            end
        end
    end
    if not rt then rt=autofly.get_quad() end
    return rt
end


local function countents()
    local obj = minetest.localplayer.get_nearby_objects(10000)
    return #obj
end


function autofly.set_hud_info(text)
    if not minetest.localplayer then return end
    if type(text) ~= "string" then return end
    local dir=ws.getdir()
    local ddir=""
    if dir == "north" then
        ddir="north(+z)"
    elseif dir == "east" then
        ddir="east(+x)"
    elseif dir == "south" then
        ddir="south(-z)"
    elseif dir == "west" then
        ddir="west(-x)"
    end
    local lp=minetest.localplayer
    local vspeed=lp:get_velocity()
    local ttext=text.."\nSpeed: "..speed.."n/s\n"
    ..ws.round2(vspeed.x,2) ..','
    ..ws.round2(vspeed.y,2) ..','
    ..ws.round2(vspeed.z,2) .."\n"
    .."Yaw:"..ws.round2(lp:get_yaw(),2).."° Pitch:" ..ws.round2(lp:get_pitch(),2).."° "
    if turtle then ttext=ttext..ddir end
    if minetest.settings:get_bool('afly_shownames') then
        ttext=ttext.."\n"..autofly.get_local_name() .."\nEntities: " .. countents()
    end
    if hud_info then
        minetest.localplayer:hud_change(hud_info,'text',ttext)
    else
        hud_info = minetest.localplayer:hud_add({
            hud_elem_type = 'text',
            name          = "Flight Info",
            text          = ttext,
            number        = 0x00ff00,
            direction   = 0,
            position = {x=0,y=0.8},
            alignment ={x=1,y=1},
            offset = {x=0, y=0}
        })
    end
    return true
end

function autofly.display(pos,name)
    if name == nil then name=pos_to_string(pos) end
    local pos=string_to_pos(pos)
    autofly.set_hud_wp(pos, name)
    return true
end


function autofly.display_waypoint(name)
    local pos=name
    if type(name) ~= 'table' then pos=autofly.get_waypoint(name) end
    autofly.last_name = name
    --autofly.last_coords = pos
    autofly.set_hud_info(name)
    autofly.aim(autofly.last_coords)
    autofly.display(pos,name)
    return true
end

function autofly.goto_waypoint(name)
    local wp=autofly.get_waypoint(name)
    autofly.goto(wp)
    autofly.last_name=name
    autofly.display_waypoint(autofly.last_name)
    return true
end

function autofly.goto(pos)
    minetest.settings:set_bool("free_move",true)
    minetest.settings:set_bool("continuous_forward",true)
    if minetest.settings:get_bool("afly_sprint") then
        minetest.settings:set_bool("autofsprint",true)
        minetest.settings:set_bool("autoeat_timed",true)
    end
    minetest.settings:set_bool("afly_autoaim",true)
    autofly.last_coords = pos
    autofly.last_name = minetest.pos_to_string(pos)
    autofly.aim(autofly.last_coords)
    autofly.flying=true
    autofly.set_hud_wp(autofly.last_coords, autofly.last_name)
    return true
end

function autofly.fly3d(pos)
    minetest.settings:set_bool("pitch_move",true)
    autofly.goto(pos)
end

function autofly.fly2d(pos)
    minetest.settings:set_bool("pitch_move",false)
    autofly.goto(pos)
end

function autofly.arrived()
    if not autofly.flying then return end
    minetest.settings:set("continuous_forward", "false")
    minetest.settings:set_bool("autofsprint",false)
    minetest.settings:set_bool("pitch_move",oldpm)
    minetest.settings:set_bool("afly_autoaim",false)
    minetest.settings:set_bool("autoeat_timed",false)
    autofly.set_hud_info("Arrived!")
    autofly.flying = false
    minetest.sound_play({name = "default_alert", gain = 1.0})
end

local cruise_wason=false
local nfctr=0


function autofly.cruise()
    if not minetest.settings:get_bool('afly_cruise') then
        if cruise_wason then
            cruise_wason=false
            core.set_keypress("jump",false)
            core.set_keypress("sneak",false)
        end
    return end

    local lp=minetest.localplayer:get_pos()
    local pos1 = vector.add(lp,{x=16,y=100,z=16})
    local pos2 = vector.add(lp,{x=-16,y=-100,z=-16})
    local nds=minetest.find_nodes_in_area_under_air(pos1, pos2, nlist.get_mclnodes())
    local y=0
    local found=false


    for k,v in ipairs(nds) do
        local nd = minetest.get_node_or_nil(v)
        if nd ~= nil and nd.name ~= "air" then
            if v.y > y then
                y=v.y
                found=true
            end
        end
    end
    if (autofly.cruiseheight ~= nil) then y=y+autofly.cruiseheight end
    local diff = math.ceil(lp.y - y)

    if not cruise_wason then --initially set the cruiseheight to the current value above ground
       -- if not found then return end --wait with activation til a ground node has been found.
        local clr,nnd=minetest.line_of_sight(lp,vector.add(lp,{x=1,y=-200,z=1}))
        if not clr then diff = math.ceil(lp.y - nnd.y)
        elseif not found then return end
        if diff < 1 then autofly.cruiseheight = 20
        else autofly.cruiseheight = diff end

        cruise_wason=true
        minetest.display_chat_message("cruise mode activated. target height set to " .. diff .. " nodes above ground.")
    end

    if not found then
        if nfctr<20 then nfctr = nfctr + 1 return end
        --minetest.display_chat_message("no nodes found for 20 iterations. lowering altitude.")
        nfctr=0
        minetest.settings:set_bool("free_move",false)
        core.set_keypress("jump",false)
        core.set_keypress("sneak",false)
        return
    end

    local tolerance = 1
    if diff < -tolerance then
        minetest.settings:set_bool("free_move",true)
        core.set_keypress("jump",true)
        core.set_keypress("sneak",false)
        --minetest.display_chat_message("too low: " .. y)
    elseif diff > tolerance * 10 then
        core.set_keypress("jump",false)
        core.set_keypress("sneak",true)
        minetest.settings:set_bool("free_move",false)
        --minetest.display_chat_message("too high: " .. y)
    elseif diff > tolerance then
        core.set_keypress("jump",false)
        core.set_keypress("sneak",true)
    else
        minetest.settings:set_bool("free_move",true)
        core.set_keypress("jump",false)
        core.set_keypress("sneak",false)
        --minetest.display_chat_message("target height reached: " .. y)
    end


end

function autofly.aim(tpos)
    return ws.aim(tpos)
end

function autofly.autotp(tpname)
   if minetest.localplayer == nil then autofly.autotp(tpname) end
    local tpos=nil
    if tpname == nil then
        tpos = autofly.get_waypoint('AUTOTP')
    elseif type(tpname) == "table" then
        tpos = tpname
    else
        tpos=autofly.get_waypoint(tpname)
    end
    if tpos == nil then return end
    local lp=minetest.localplayer
    local dst=vector.distance(lp:get_pos(),tpos)
    if (dst < 300) then
        minetest.sound_play({name = "default_alert", gain = 3.0})
        autofly.delete_waypoint('AUTOTP')
        return true
    end
    autofly.set_waypoint(tpos,'AUTOTP')
    local boat_found=false
    for k, v in ipairs(lp.get_nearby_objects(4)) do
        local txt = v:get_item_textures()
		if ( txt:find('mcl_boats_texture')) then
            boat_found=true
            minetest.display_chat_message("boat found. entering and tping to "..minetest.pos_to_string(autofly.get_waypoint('AUTOTP')))
            autofly.aim(vector.add(v:get_pos(),{x=0,y=-1.5,z=0}))
            minetest.after("0.2",function()
                minetest.interact("place") end)
            minetest.after("1.5",function()
                 autofly.warpae('AUTOTP')
              end)
            return true
        end
    end
    if not boat_found then
        minetest.display_chat_message("no boat found. trying again in 5.")
        minetest.after("5.0",function() autofly.autotp(tpname) end)
    return end
end



autofly.register_transport('Fly3D',function(pos,name) autofly.fly3d(pos,name) end)
autofly.register_transport('Fly2D',function(pos,name) autofly.fly2d(pos,name) end)
autofly.register_transport('wrp',function(pos,name) autofly.warp(name) end)
--autofly.register_transport('atp',function(pos,name) autofly.autotp(name) end)

function autofly.axissnap()
    if not minetest.settings:get_bool('afly_snap') then return end
    if minetest.settings:get_bool("freecam") then return end
    local y=minetest.localplayer:get_yaw()
    local yy=nil
    if ( y < 45 or y > 315 ) then
        yy=0
    elseif (y < 135) then
        yy=90
    elseif (y < 225 ) then
        yy=180
    elseif ( y < 315 ) then
        yy=270
    end
    if yy ~= nil then
        minetest.localplayer:set_yaw(yy)
    end
end

minetest.register_on_death(function()
    if minetest.localplayer then
        local name = 'Death waypoint'
        local pos  = minetest.localplayer:get_pos()
        autofly.last_coords = pos
        autofly.last_name = name
        autofly.set_waypoint(pos,name)
        autofly.display(pos,name)
    end
end)

local function get_dimension(pos)
    if pos.y > -65 then return "overworld"
    elseif pos.y > -8000 then return "void"
    elseif pos.y > -27000 then return "end"
    elseif pos.y >29000 then return "void"
    elseif pos.y >31000 then return "nether"
    else return "void"
    end
end

function autofly.warp(name)
    local pos=autofly.get_waypoint(name)
    if pos then
        if get_dimension(pos) == "void" then return false end
        minetest.localplayer:set_pos(pos)
        return true
    end
end
function autofly.warpae(name)
		local s, m = autofly.warp(name)
		if s then
			minetest.disconnect()
		end
		return true
end

function autofly.getwps()
    local wp={}
    for name, _ in pairs(storage:to_table().fields) do
        if name:sub(1, string.len(stprefix)) == stprefix then
            table.insert(wp, name:sub(string.len(stprefix)+1))
        end
    end
    table.sort(wp)
    return wp
end



function autofly.impfromsrv(srv,sel)
    local srvstr="autofly-".. srv  .. '-'
    for name, _ in pairs(storage:to_table().fields) do
        if name:sub(1, string.len(srvstr)) == srvstr then
            local name=name:sub(string.len(srvstr)+1)
            if not sel or ( sel and name:sub(1, string.len(sel)) == sel ) then
                local pos=string_to_pos(storage:get_string(srvstr .. tostring(name)))
                autofly.set_waypoint(pos,name)
            end
        end
    end
    return wp
end

function autofly.set_waypoint(pos, name)
    pos = pos_to_string(pos)
    if not pos then return end
    storage:set_string(stprefix .. tostring(name), pos)
    return true
end

function autofly.delete_waypoint(name)
    storage:set_string(stprefix .. tostring(name), '')
end

function autofly.get_waypoint(name)
    return string_to_pos(storage:get_string(stprefix .. tostring(name)))
end

function autofly.rename_waypoint(oldname, newname)
    oldname, newname = tostring(oldname), tostring(newname)
    local pos = autofly.get_waypoint(oldname)
    if not pos or not autofly.set_waypoint(pos, newname) then return end
    if oldname ~= newname then
        autofly.delete_waypoint(oldname)
    end
    return true
end
local function log(level, message)
    minetest.log(level, ('[%s] %s'):format(mod_name, message))
end
function autofly.dumptolog()
    local wp=autofly.getwps()
    for name, _ in pairs(wp) do
        --local lname=name:sub(string.len(stprefix)+1)
       -- local ppos=string_to_pos(storage:get_string(tostring(name)))
        if ppos then
            log('action',name .. ' :: ')
        end
    end
end

minetest.after("5.0",function()
    if autofly.get_waypoint('AUTOTP') ~= nil then autofly.autotp(nil) end
end)


math.randomseed(os.time())

local randflying = false

minetest.register_globalstep(function()
    if randflying and not autofly.flying then
        local x = math.random(-31000, 31000)
        local y = math.random(2000, 31000)
        local z = math.random(-31000, 31000)

        autofly.goto({x = x, y = y, z = z})
    end
end)

local function randfly()
    if not randflying then
        randflying = true
        local lp = minetest.localplayer:get_pos()
        autofly.goto(turtle.coord(lp.x, 6000, lp.z))
    else
        randflying = false
        autofly.arrived()
    end
end



minetest.register_chatcommand('waypoints', {
    params      = '',
    description = 'Open the autofly GUI',
    func = function(param) autofly.display_formspec() end
})

ws.register_chatcommand_alias('waypoints','wp', 'wps', 'waypoint')

-- Add a waypoint
minetest.register_chatcommand('add_waypoint', {
    params      = '<pos / "here" / "there"> <name>',
    description = 'Adds a waypoint.',
    func = function(param)
        local s, e = param:find(' ')
        if not s or not e then
            return false, 'Invalid syntax! See .help add_mrkr for more info.'
        end
        local pos = param:sub(1, s - 1)
        local name = param:sub(e + 1)
        if not pos then
            return false, err
        end
        if not name or #name < 1 then
            return false, 'Invalid name!'
        end
        return autofly.set_waypoint(pos, name), 'Done!'
    end
})
ws.register_chatcommand_alias('add_waypoint','wa', 'add_wp')


minetest.register_chatcommand('add_waypoint_here', {
    params      = 'name',
    description = 'marks the current position',
    func = function(param)
        local name = os.date("%Y-%m-%d %H:%M:%S")
        local pos  = minetest.localplayer:get_pos()
        return autofly.set_waypoint(pos, name), 'Done!'
    end
})
ws.register_chatcommand_alias('add_waypoint_here', 'wah', 'add_wph')

minetest.register_chatcommand('clear_waypoint', {
    params = '',
    description = 'Hides the displayed waypoint.',
    func = function(param)
        if autofly.flying then autofly.flying=false end
        if hud_wp then
            minetest.localplayer:hud_remove(hud_wp)
            hud_wp = nil
            return true, 'Hidden the currently displayed waypoint.'
        elseif not minetest.localplayer.hud_add then
            minetest.run_server_chatcommand('clrmrkr')
            return
        elseif not hud_wp then
            return false, 'No waypoint is currently being displayed!'
        end
        for k,v in wps do
            minetest.localplayer:hud_remove(v)
            table.remove(k)
        end

    end,
})
ws.register_chatcommand_alias('clear_waypoint', 'cwp','cls')

minetest.register_chatcommand('autotp', {
    params      = 'position',
    description = 'autotp',
    func = function(param)
      autofly.autotp(minetest.string_to_pos(param))
    end
})
ws.register_chatcommand_alias('autotp', 'atp')

minetest.register_chatcommand('wpdisplay', {
    params      = 'position name',
    description = 'display waypoint',
    func = function(pos,name)
      autofly.display(pos,name)
    end
})
ws.register_chatcommand_alias('wpdisplay', 'wpd')



minetest.register_chatcommand("randfly", {
    description = "Randomly fly up high (toggle).",
    func = randfly
})


    minetest.register_cheat("Aim", "Autofly", "afly_autoaim")
    minetest.register_cheat("AxisSnap", "Autofly", "afly_snap")
    minetest.register_cheat("Cruise", "Autofly", "afly_cruise")
    minetest.register_cheat("Sprint", "Autofly", "afly_sprint")
    minetest.register_cheat("ShowNames", "Autofly", "afly_shownames")
    minetest.register_cheat("Waypoints", "Autofly", autofly.display_formspec)
