-- CC0/Unlicense Emilia 2020

local seeds = {
    "mcl_farming:wheat_seeds",
    "mcl_farming:beetroot_seeds",
    "mcl_farming:carrot_item",
    "mcl_farming:potato_item"
}

local nodeseeds = {
    "mcl_farming:melon_seeds",
    "mcl_farming:pumpkin_seeds"
}

local tillable = {
    "mcl_core:dirt",
    "mcl_core:dirt_with_grass",
    "mcl_farming:soil"
}

local hoes = {
    "mcl_farming:hoe_wood",
    "mcl_farming:hoe_stone",
    "mcl_farming:hoe_iron",
    "mcl_farming:hoe_gold",
    "mcl_farming:hoe_diamond"
}

local water = {
    "mcl_core:water_source",
    "mcl_buckets:bucket_water",
    "mcl_buckets:bucket_river_water"
}

scaffold.register_template_scaffold("AutoFarm", "scaffold_farm", function(below)
    local lp = vector.round(minetest.localplayer:get_pos())

    -- farmland
    if below.x % 5 ~= 0 or below.z % 5 ~= 0 then
        if scaffold.place_if_needed(tillable, below) then
            if scaffold.can_place_at(lp) then
                if scaffold.find_any_swap(hoes) then
                    minetest.interact("place", below)
                    scaffold.place_if_needed(seeds, lp)
                end
            end
        end
    -- water
    else
        scaffold.place_if_needed(water, below)
    end
end)

scaffold.register_template_scaffold("AutoMelon", "scaffold_melon", function(below)
    local lp = vector.round(minetest.localplayer:get_pos())

    local x = below.x % 5
    local z = below.z % 5

    -- water
    if x == 0 and z == 0 then
        scaffold.place_if_needed(water, below)
    -- dirt
    elseif z == 2 or z == 4 or ((x == 2 or x == 4) and z == 0) then
        scaffold.place_if_needed(tillable, below)
    -- farmland
    elseif (x == 1 or z == 1) or (x == 3 or z == 3) then
        if scaffold.place_if_needed(tillable, below) then
            if scaffold.can_place_at(lp) then
                if scaffold.find_any_swap(hoes) then
                    minetest.interact("place", below)
                    scaffold.place_if_needed(nodeseeds, lp)
                end
            end
        end
    end
end)
