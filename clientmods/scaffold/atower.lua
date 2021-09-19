ws.rg('AutoTower','Scaffold','atower',function()
	local it=minetest.localplayer:get_wielded_item():get_name()
	local lp=ws.dircoord(0,0,0)
	local nds=minetest.find_nodes_near_under_air(lp,4,{it},false)
	for k,v in ipairs(nds) do
		ws.place(vector.add(v,vector.new(0,1,0)),it)
	end
end,function() end,function() end, {'autorefill'})