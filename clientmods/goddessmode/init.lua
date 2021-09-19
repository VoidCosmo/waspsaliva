--
-- cora's defensive combat hax



local karange=14
local tping=false
local dodged=false

local function checkair(pos)
	local n=minetest.get_node_or_nil(pos)
	if n==nil or n['name'] == 'air' then return true end
    return false
end

local function checkbadblocks(pos)
    local n=minetest.find_node_near(pos, 2, {'mcl_core:gravel','mcl_core:sand','mcl_core:lava_source','mcl_core:lava_flowing','mcl_core:water_source','mcl_core:water_flowing',
    'mcl_core:obsidian','mcl_core:bedrock'}, true)
    if n == nil then return false end
    return true
end
local function checktrap()
    local lp=minetest.localplayer:get_pos()
    local air,nd=minetest.line_of_sight(vector.add(lp,{x=0,y=-2,z=0}), vector.add(lp,{x=0,y=50,z=0}))
    if(not air) then
	local tn=minetest.get_node_or_nil(nd)
	if(tn == nil) then return false end
	for k,v in ipairs({'mcl_core:lava_source','mcl_core:lava_flowing','mcl_core:water_source','mcl_core:water_flowing'}) do
		if tn.name == v then return true end
	end
    end
    return false
end

local function checkhead()
	local ppos=vector.add(minetest.localplayer:get_pos(),{x=0,y=1,z=0})
	if (checkair(ppos)) then return true end
	return false
end


local function checkprojectile()
    for k, v in ipairs(minetest.localplayer.get_nearby_objects(karange)) do
		if ( v:get_item_textures():sub(-9) == "arrow_box") or ( v:get_item_textures():sub(-7) == "_splash") or v:get_item_textures():sub(-17) == "shulkerbullet.png"  then
			local lp=minetest.localplayer:get_pos()
			local vel=v:get_velocity()
			local dst=vector.distance(lp,v:get_pos())
			if dst > 4 then return false end
			if (vel.x == 0 and vel.y == 0 and vel.z ==0 ) then return false end
			return true
        end
    end
	return false
end


local function amautotool(pos)
	local node=minetest.get_node_or_nil(pos)
	minetest.select_best_tool(node.name)
end

local function get_2dpos_from_yaw(r,yaw)
	local tg={x=0,y=0,z=0}
	tg.x= r * math.sin(yaw)
	tg.z= r * math.cos(yaw)
	return tg
end
local function get_3dpos_from_yaw_and_pitch(r,yaw,pitch)
	local tg={x=0,y=0,z=0}
	tg.x= r * math.sin(yaw)
	tg.y= r * math.sin(pitch)
	tg.z= r * math.cos(yaw)
	return tg
end
local function dhfree()
            if not minetest.localplayer then return end
            local n=vector.add(minetest.localplayer:get_pos(),{x=0,y=2,z=0})
	    local nd=minetest.get_node_or_nil(n)
	    if nd == nil then return end
	    while nd.name ~= "air" do
		amautotool(n)
		minetest.dig_node(n)
		minetest.dig_node(vector.add(n,{x=0,y=-1,z=0}))
		nd=minetest.get_node_or_nil(n)
	     end
		tping=false
end
local lastwrp=0
local function mwarp(pos)
	if tping then return end
	--if os.time() < lastwrp+1 then return end
	--lastwrp=os.time();
	tping=true
	minetest.after("0.1",function() dhfree() end)
	minetest.localplayer:set_pos(pos)
end

local function get_target(epos)
	math.randomseed(os.time())
	local t=vector.add(epos,get_3dpos_from_yaw_and_pitch(karange+1,math.random(90,240),math.random(90,135)))
	if (checkbadblocks(t)) then
		return get_target(epos)
	elseif checkair(t) then
		return t
	else
		amautotool(t)
	end
	return t
end


local function evade(ppos)
	mwarp(get_target(ppos))
end
local function dodge()
	if dodged then return end
	dodged=true
	local t=turtle.dircoord(math.random(0,2)-1,0,math.random(0,2)-1)
	local opos=minetest.localplayer:get_pos()
	mwarp(t)
	minetest.after("0.5",function() mwarp(opos) dodged=false end )
end

local function rro() -- reverse restraining order

    for k, v in ipairs(minetest.localplayer.get_nearby_objects(karange+5)) do
	local name=v:get_name()
        if (v:is_player() and  name ~= minetest.localplayer:get_name()) then
	    if fren.is_friend(name) then
		return end
            local pos = v:get_pos()
            pos.y = pos.y - 1
			local mpos=minetest.localplayer:get_pos()
            local distance=vector.distance(mpos,pos)
            if distance < karange then
				local trg=get_target(pos)
				mwarp(trg)
				minetest.after("0.2",function() autofly.aim(pos) end)
				return
			end
        end
    end
end

minetest.register_globalstep(function()
    if minetest.settings:get_bool("goddess") then
	local ppos=minetest.localplayer:get_pos()
        --rro()
        if(checkprojectile()) then dodge(ppos)  end
        --if(checktrap()) then evade(ppos)  end
        if(not checkhead()) then dhfree()  end
    end
end)
minetest.register_chatcommand("dhf", {	description = "",	func = dhfree })


-- REG cheats on DF
if (_G["minetest"]["register_cheat"] ~= nil) then
	 minetest.register_cheat("Goddess Mode", "Combat", "goddess")
else
	 minetest.settings:set_bool('goddess',true)
end
