-- CC0/Unlicense Emilia 2020

local dirt = {
    "mcl_core:dirt",
    "mcl_core:dirt_with_grass",
    "mcl_core:dirt_with_grass_snow",
    "mcl_core:podzol"
}

local saplings = {
    "mcl_core:sapling",
    "mcl_core:darksapling",
    "mcl_core:junglesapling",
    "mcl_core:sprucesapling",
    "mcl_core:birchsapling",
    "mcl_core:acaciasapling"
}

scaffold.register_template_scaffold("SapScaffold", "scaffold_saplings", function(below)
    local lp = vector.round(minetest.localplayer:get_pos())

    if scaffold.place_if_needed(dirt, below) then
        scaffold.place_if_needed(saplings, lp)
    end
end)
