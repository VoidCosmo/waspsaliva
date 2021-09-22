
-- TODO
--[[
    free space could be a concern
    traverse_recurse should replace groups with the concrete item
        maybe recursions yield an item name?
        that way has_sub could indicate the item which would be yielded in traverse_recurse and replaced in the recipe before being queued
    autocraft.recipes should be loaded and custom per modset
    it might choke on empty items in the recipe
    this needs to handle groups a bit better, i dont think it will mix woods/etc
--]]

autocraft = {}


autocraft.recipes = {
    ["mcl_core:crafting_table"] = {
        recipes = {
            {
                recipe = {
                    {"group:planks", "group:planks"},
                    {"group:planks", "group:planks"}}
            }
        }
    },
    ["mcl_core:wood"] = {
        groups = {"planks"},
        recipes = {
            {
                count = 4,
                recipe = {
                    "mcl_core:tree"
                },
                shapeless = true -- redundant, can detect from the lack of subtables
            }
        }
    }
}

autocraft.groups = {}

-- extract groups from autocraft.recipes
local function group_arrange()
    for k, v in pairs(autocraft.recipes) do
        if v.groups then
            for gi, gv in ipairs(v.groups) do
                if not autocraft.groups[gv] then
                    autocraft.groups[gv] = {}
                end

                table.insert(autocraft.groups[gv], k)
            end
        end
    end
end

group_arrange()

local function startswith(str, start)
    return string.sub(str, 1, #start) == start
end

local function combine(t1, t2)
    local t1l = #t1
    local o = {}

    for i, v in ipairs(t1) do
        o[i] = v
    end

    for i, v in ipairs(t2) do
        o[t1l + i] = v
    end

    return o
end

local function parse_group(str)
    if startswith(str, "group:") then
        return str:match("group:(.+)")
    end
end

-- get recipes for an item/group
local function get_recipes(str)
    local group = parse_group(str)

    if group then
        local o = {}

        if autocraft.groups[group] then
            for i, v in ipairs(autocraft.groups[group]) do
                o = combine(o, get_recipes(v))
            end

            return o
        end
    else
        local idef = autocraft.recipes[str]
        if idef then
            local o = idef.recipes

            for i, v in ipairs(o) do
                v.name = str
            end

            return o
        end
    end

    return {}
end

-- count up all the items in the player's inventory
-- output:
-- {
--  item = n,
--  item = n
-- }
local function count_inv()
    local o = {}
    local lpim = minetest.get_inventory("current_player").main

    for i, v in ipairs(lpim) do
        if not v:is_empty() then
            o[v:get_name()] = (o[v:get_name()] or 0) + v:get_count()
        end
    end

    return o
end

-- effectively turn a recipe shapeless
local function flatten_recipe(recipe)
    if type(recipe[1]) == "table" then
        local o = {}

        for i, v in ipairs(recipe) do
            o = combine(o, v)
        end

        return o
    else
        return recipe
    end
end

-- count the requirements for a recipe, uses count_inv format
local function count_recipe(recipe)
    local o = {}

    for i, v in ipairs(flatten_recipe(recipe)) do
        local item = ItemStack(v)
        o[item:get_name()] = (o[item:get_name()] or 0) + item:get_count()
    end

    return o
end

-- get all item strings for an item or group string
local function get_items_of(str)
    local group = parse_group(str)

    if group then
        return autocraft.groups[group]
    else
        return {str}
    end
end

-- check if the recipe can be crafted with current resources
local function can_craft(resources, recipe)
    for k, count in pairs(count_recipe(recipe)) do
        for i, vv in ipairs(get_items_of(k)) do
            local item = ItemStack(vv)
            if (resources[item:get_name()] or 0) >= count then
                break
            end
        end
    end

    return true
end

-- traverse all items in a recipe
local function recurse_recipe(resources, queue, recipe)
    for i, v in ipairs(flatten_recipe(recipe)) do
        if not autocraft.traverse_recurse(resources, queue, ItemStack(v)) then
            return false
        end
    end

    return true
end

-- checks if the item/group is in the resource list and subtracts it
-- is the base case for traverse_recurse
local function has_sub(resources, item)
    for i, v in ipairs(get_items_of(item:get_name())) do
        if resources[v] and resources[v] >= item:get_count() then
            resources[v] = resources[v] - item:get_count()
            return true
        end
    end

    return false
end

-- enqueues a recipe for an item and its needed sub items
function autocraft.traverse_recurse(resources, queue, item)
    if type(item) == "string" then
        item = ItemStack(item)
    end

    -- base case, uncraftibles/already in inventory
    if has_sub(resources, item) then
        return true
    else
        for i, v in ipairs(get_recipes(item:get_name())) do
            if can_craft(resources, v.recipe) then
                if recurse_recipe(resources, queue, v.recipe) then
                    table.insert(queue, v.recipe)

                    local tgt = item:get_count()
                    local result = v.count or 1
                    local delta = tgt - result

                    resources[v.name] = (resources[v.name] or 0) + result

                    if delta > 0 then
                        item:set_count(delta)
                        traverse_recurse(resources, queue, item)
                    end

                    return true
                end
            end
        end
    end

    -- not enough resources
    return false
end

-- create a crafting queue for an item
-- return queue if enough resources, nil if not
function autocraft.traverse(item)
    local queue = {}
    local resources = count_inv()

    if autocraft.traverse_recurse(resources, queue, item) then
        return queue
    end
end

-- craft a traversed craft tree
local function queuecraft(tree)

end

-- make a queue and craft it
function autocraft.craft(item)

end
