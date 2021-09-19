-- CC0/Unlicense system32 2020

local function parse_coord(c)
    c = string.split(c, " ")
    return {x = tonumber(c[1] or 0), y = tonumber(c[2] or 0), z = tonumber(c[3] or 0)}
end

minetest.register_chatcommand("cpeek", {
    func = function(params)
        local oldpos = minetest.localplayer:get_pos()

        local c = parse_coord(params)
        local dist = vector.distance(c, oldpos)
        local d = tostring(c.x) .. "," .. tostring(c.y) .. "," .. tostring(c.z)
        local f = "size[10,10]\nlabel[0,0;Can access: " .. tostring(dist < 6) .. "(" .. tostring(dist) .. ")]\nlist[nodemeta:" .. d .. ";main;0,0.5;9,3;]"

        minetest.localplayer:set_pos(c)
        minetest.show_formspec("ChestPeek", f)
        minetest.localplayer:set_pos(oldpos)
    end
})


local formspec_template = "size[9,Y]label[0,0;L]button[8,0;1,1;up;^Up^]"
local formspec_base = formspec_template:gsub("Y", "4")
local formspec_base_label = formspec_template:gsub("Y", "4.5")

local formspec_item = "\nitem_image_button[X,Y;1,1;I;N;]"
local formspec_item_label = formspec_item .. "\nlabel[X,Z;T]"

local function map(f, t)
    local out = {}
    for i, v in ipairs(t) do
        out[i] = f(v)
    end
    return out
end

local inventories = {}

-- include_label because i implemented the label then realized item buttons did it themselves
local function make_formspec(name, items, include_label)
    if items == nil then
        return nil
    end

    local form = formspec_base
    if include_label then
        form = formspec_base_label
    end

    -- color strip cause yellow is unreadible with default styling
    form = form:gsub("L", minetest.formspec_escape(minetest.strip_colors(name)))

    for i, v in ipairs(items) do
        local x = (i - 1) % 9
        local y = 1 + math.floor((i - 1) / 9) -- +1 for the shulker name

        if include_label then
            y = y + (y * 0.2) -- shifts each layer down a bit
        end

        local it = formspec_item
        if include_label then
            it = formspec_item_label
        end

        it = it:gsub("X", x)
        it = it:gsub("Y", y)
        if include_label then
            it = it:gsub("I", v:get_name())
            it = it:gsub("Z", y + 0.8)
            it = it:gsub("T", v:get_count())
        else
            it = it:gsub("I", v:get_name() .. " " .. tostring(v:get_count()))
        end

        local item_name = "button" .. tostring(i)
        it = it:gsub("N", item_name)

        if minetest.get_item_def(v:get_name()).description ~= v:get_description() then
            it = it .. "tooltip[" .. item_name .. ";" .. v:get_description() .. "]"
        end

        form = form .. it
    end

    return form
end

local function get_items(item)
    local meta = item:get_metadata()
    local list = minetest.deserialize(meta)

    if list == nil then
        return
    end

    local items = map(ItemStack, list)
    return items
end

local function make_list(name, items, prevent_push)
    local fs = make_formspec(name, items)

    if not prevent_push then
        table.insert(inventories, {name = name, items = items})
    end

    if fs ~= nil then
        minetest.show_formspec("PeekInventory", fs)
    end
end

local function show_form(shulker)
    make_list(shulker:get_description(), get_items(shulker))
end

local function top(list)
    return list[#list]
end

minetest.register_on_formspec_input(function(formname, fields)
    if formname == "PeekInventory" then
        if fields.quit then
            inventories = {}
            return true
        end

        if fields.up and #inventories > 1 then
            table.remove(inventories)
            local t = top(inventories)
            make_list(t.name, t.items, true)
            return true
        end

        for k, v in pairs(fields) do
            if k:find("button") then
                local idx = tonumber(k:match("([0-9]+)"))
                local item = top(inventories).items[idx]
                local iname = item:get_name()
                if iname:find("mcl_chests:.-_shulker_box") then
                    show_form(top(inventories).items[idx])
                    return true
                elseif iname:find("mcl_books:.-written_book") then
                    -- to be implemented with bookbot
                    -- bookbot.read(item)
                end
            end
        end
    end
end)

minetest.register_chatcommand("peek", {
    description = "Peek inside a Mineclone Shulker box.",
    func = function()
        show_form(minetest.localplayer:get_wielded_item())
    end
})

