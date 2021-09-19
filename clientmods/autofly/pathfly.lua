local function get_3dpos_from_yaw_and_pitch(r,yaw,pitch)
	local tg=vector.new(0,0,0)
	tg.x= r * math.sin(yaw)
	tg.y= r * math.sin(pitch)
	tg.z= r * math.cos(yaw)
	return tg
end
local nexttarget=vector.new(0,0,0)

local sdst=40

function autofly.pathfind(coords)
    local lp=minetest.localplayer
    autofly.aim(coords)
   local yaw=lp:get_yaw()
   local pitch=lp:get_pitch()
   local ltgt=vector.add(lp:get_pos(),get_3dpos_from_yaw_and_pitch(sdst,yaw,pitch))
   local tgt=vector.new(0,0,0)

   if not minetest.line_of_sight(lp:get_pos(), ltgt) then
        local path=minetest.find_path(lp:get_pos(),ltgt,sdst*2,100,100,'Dijkstra')
        if not path then
            minetest.display_chat_message("no path found.")
            return
        end
        tgt=vector.add(path[1],vector.new(0,2,0))
        if vector.distance(lp:get_pos(),tgt) < 6 then
            tgt=vector.add(path[2],vector.new(0,2,0))
        end
    else
        tgt=ltgt
    end
    autofly.aim(tgt)
    autofly.goto(tgt)
end
