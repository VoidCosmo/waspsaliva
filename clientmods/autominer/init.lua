---
-- autominer


autominer = {}
local dmg=false
local digging=false
local radius=6

local nodes=nlist.get("autominer")


local function sleep(n)  -- seconds
  local t0 = os.clock()
  while os.clock() - t0 <= n do end
end
local function shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end
local function checklava(pos)
    local n=minetest.find_node_near(pos, 2, {'mcl_core:lava_source','mcl_core:lava_flowing'}, true)
    if n == nil then return false end
    return true
end
local function checkgravel(pos)
    local n=minetest.find_node_near(pos, 1, {'mcl_core:gravel','mcl_core:sand'}, true)
    if n == nil then return false end
    return true
end

-- shamelessly stolen from dragonfire autotool
local function check_tool(stack, node_groups, old_best_time)
	local toolcaps = stack:get_tool_capabilities()
	if not toolcaps then return end
	local best_time = old_best_time
	for group, groupdef in pairs(toolcaps.groupcaps) do
		local level = node_groups[group]
		if level then
			local this_time = groupdef.times[level]
			if this_time < best_time then
				best_time = this_time
			end
		end
	end
	return best_time < old_best_time, best_time
end

local function amautotool(pos)
	local player = minetest.localplayer
	local inventory = minetest.get_inventory("current_player")
    local node=minetest.get_node_or_nil(pos)
	local node_groups = minetest.get_node_def(node.name).groups
	local new_index = player:get_wield_index()
	local is_better, best_time = false, math.huge
	is_better, best_time = check_tool(player:get_wielded_item(), node_groups, best_time)
	is_better, best_time = check_tool(inventory.hand[1], node_groups, best_time)
	for index, stack in pairs(inventory.main) do
		is_better, best_time = check_tool(stack, node_groups, best_time)
		if is_better then
			new_index = index
		end
	end
	player:set_wield_index(new_index)
end

local function find_tnod()
    local pos = minetest.localplayer:get_pos()
	local rr = vector.add(pos,{x=0,y=0,z=radius})
	local pos1 = vector.add(pos,{x=radius,y=radius,z=radius})
    local pos2 = vector.add(pos,{x=-radius,y=-radius,z=-radius})
    local rt=shuffle(minetest.find_nodes_in_area(pos1, pos2, shuffle(nodes), true))
    for k,v in pairs(rt) do
        for kk,vv in pairs(shuffle(v)) do
       -- minetest.display_chat_message("Found nodes:" ..dump(rt))
            if ( vv.y > -57 ) and not checkgravel(vv) and not checklava(vv) then
                rr=vv
                break
            end
        end
    end
    if (checkgravel(rr) or checklava(rr)) then return minetest.after(0.2,find_tnod) end
    return rr
--    return rt
end
local function get_hnode()
    local ppos=minetest.localplayer:get_pos()
    local n=minetest.get_node_or_nil(vector.add(ppos,{x=0,y=1,z=0}))
    return n
end
local function dighead()
            if not minetest.localplayer then return end
            local ppos=vector.add(minetest.localplayer:get_pos(),{x=0,y=1,z=0})
            local n=get_hnode()
            if n==nil or n['name'] == 'air' then return end
            --amautotool(ppos)
	    minetest.localplayer:set_wield_index(1)
            minetest.dig_node(ppos)
            minetest.dig_node(vector.add(ppos,{x=0,y=1,z=0}))
            digging=false
            if (minetest.settings:get_bool('aminer_active')) then
                local hp=minetest.localplayer:get_hp()
                local hn=get_hnode()
                if (hp > 17) then
                    minetest.after(0.2,autominer.aminer )
                else
                        minetest.display_chat_message("taken too much damage. wait.")
                        local ppos=vector.add(minetest.localplayer:get_pos(),{x=0,y=1,z=0})
                        minetest.dig_node(ppos)
                        minetest.dig_node(vector.add(ppos,{x=0,y=1,z=0}))
                        minetest.after(1.0,function() minetest.dig_node(vector.add(ppos,{x=0,y=0,z=0})) end )
                        minetest.after(1.4,function() minetest.dig_node(vector.add(ppos,{x=0,y=1,z=0})) end )
                        minetest.after(1.8,function() minetest.dig_node(vector.add(ppos,{x=0,y=0,z=0})) end )
                        minetest.after(2.5,function() minetest.dig_node(vector.add(ppos,{x=0,y=1,z=0})) end )
                       -- minetest.settings:set_bool("aminer_active",false)
                end
            end
end

local function rwarp()
    if not (minetest.settings:get_bool("aminer_active")) then return end
    digging=true
    local nod=find_tnod()
    if not nod then
        minetest.display_chat_message('lava detected. stop.')
        return
    end
    minetest.localplayer:set_pos(vector.add(nod,{x=0.3,y=-1.2,z=0.3}))
    dighead()
    minetest.after(0.2, dighead)
end

local function amine()
            minetest.after(1.0,rwarp)
end
function autominer.aminer()
        if not digging then
            digging=true
            dmg=hpchange.get_status()
            if dmg then
                minetest.after(3.0,rwarp)
            else
                minetest.after(0.5,rwarp)
            end
        end
end
local lastch=0
minetest.register_globalstep(function()
    if os.time() < lastch + 5 then return end
    lastch=os.time()
    if ( minetest.settings:get_bool('aminer_active') ) then
        dmg=true
        digging=false
        autominer.aminer()
    end
end)

minetest.register_chatcommand("aminer", {
	description = "",
	func = function()
        dmg=true
        digging=false
        minetest.settings:set_bool("aminer_active",true)
        autominer.aminer()
    end,
})
minetest.register_chatcommand("amine", {
	description = "",
	func = amine
})
minetest.register_chatcommand("dhe", {
	description = "",
	func = dighead
})
minetest.register_on_damage_taken(function(hp)
    dmg=true
end)


if (_G["minetest"]["register_cheat"] ~= nil) then
    minetest.register_cheat("Autominer    (!!! ALPHA!! this will lead to you dying!!!)", "Player", "aminer_active")
else
    minetest.settings:set_bool('aminer_active',true)
end
