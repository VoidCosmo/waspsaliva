local Y=1337
local plnodes={'mcl_core:cobble','mcl_core:dirt','mcl_core:dirt_with_grass','mcl_core:obsidian'}
ws.rg("OW2Bot","Bots","ow2bot", function(pos)
    local lp=minetest.localplayer:get_pos()
    local r=3
    local pos1=vector.add(lp,{x=r,y=0,z=r})
    local pos2=vector.add(lp,{x=-r,y=0,z=-r})
    pos1.y=Y
    pos2.y=Y

    ws.do_area(3,function(pos)
        ws.place(pos,plnodes)
    end,true)

end,function()


end)
