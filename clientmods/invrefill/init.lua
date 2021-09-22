-- CC0/Unlicense Emilia 2021

refill = {}

local function nameformat(description)
    description = description:gsub(string.char(0x1b) .. "%(.@[^)]+%)", "")
    description = description:match("([^\n]*)")
    return description
end

function refill.find_named(list, name, test)
    for i, v in ipairs(list) do
        if (v:get_name():find("shulker_box")
            and nameformat(v:get_description()) == name
            and (test and test(v))) then
            return i
        end
    end
end

function refill.shulker_has_items(stack)
    local list = minetest.deserialize(stack:get_metadata())

    for i, v in ipairs(list) do
        if not ItemStack(v):is_empty() then
            return true
        end
    end

    return false
end

function refill.shulk_switch(name)
    local plinv = minetest.get_inventory("current_player")

    local pos = refill.find_named(plinv.main, name, refill.shulker_has_items)
    if pos then
        minetest.log("main " .. tostring(pos))
        minetest.localplayer:set_wield_index(pos)
        return true
    end

    local epos = refill.find_named(plinv.enderchest, name, refill.shulker_has_items)
    if epos then
        minetest.log("enderchest " .. tostring(epos))
        local tpos
        for i, v in ipairs(plinv.main) do
            if v:is_empty() then
                tpos = i
                break
            end
        end

        if tpos then
            local mv = InventoryAction("move")
            mv:from("current_player", "enderchest", epos)
            mv:to("current_player", "main", tpos)
            mv:apply()
            minetest.localplayer:set_wield_index(tpos)
            return true
        end
    end
end

local function invposformat(pos)
    pos = vector.round(pos)
    return string.format("nodemeta:%i,%i,%i", pos.x, pos.y, pos.z)
end

local function do_refill(pos)
    local q = quint.invaction_new()
    quint.invaction_dump(q,
        {location = invposformat(pos), inventory = "main"},
        {location = "current_player", inventory = "main"})
    quint.invaction_apply(q)
end

function refill.refill_at(pos, name)
    if refill.shulk_switch(name) then
        minetest.after(1, minetest.place_node, pos)
        minetest.after(2, do_refill, pos)
        minetest.after(3, minetest.dig_node, pos)
    end
end

function refill.refill_here(name)
    local pos = vector.round(minetest.localplayer:get_pos())
    refill.refill_at(pos, name)
end

minetest.register_chatcommand("refill", {
    description = "Refill the inventory with a named shulker.",
    params = "<shulker name>",
    func = refill.refill_here
})
