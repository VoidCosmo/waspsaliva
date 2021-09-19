-- CC0/Unlicense Emilia 2020

--[[
invaction
place
dig
interact
--]]

-- invaction stuff needs to change indices to 1 indexed soon(tm)


-- Queue Interact
-- think of it like minetest.after() but with automatic time calculation and a bit more parallel
quint = {}

-- New empty invaction quint
function quint.invaction_new()
    return {start = {}, q = {}, current = {}, last = 0, index = 1}
end

-- Get a global index for an inventory location from part of an invaction
local function format_inv(taction)
    return taction.location .. ";" .. taction.inventory
end

-- Split a global inventory index
local function parse_inv(inv)
    local spl = string.split(inv, ";")
    return {location = spl[1], inventory = spl[2]}
end

-- Get some useful things from an invaction
local function parse_invaction(lists, taction)
    local idx = format_inv(taction)
    local slot = taction.slot
    local itemstack = lists[idx][slot]

    return idx, slot, itemstack
end

-- Simulates an inventory action, performing the collateral operations
local function simulate_invaction(lists, invaction)
    local fidx, fslot, fis = parse_invaction(lists, invaction:to_table().from)
    local tidx, tslot, tis = parse_invaction(lists, invaction:to_table().to)

    local tcount = invaction:to_table().count
    if tcount == 0 then
        tcount = fis:get_count()
    end

    -- can't do anything
    if fis:is_empty() then
        return
    end

    -- dump
    if tis:is_empty() then
        lists[tidx][tslot] = fis
        lists[fidx][fslot] = ItemStack()
        return
    end

    -- swap
    if ((fis:get_name() ~= tis:get_name())
          or (fis:get_name() == tis:get_name()
            and tcount > tis:get_free_space())
          or (tcount > tis:get_free_space())) then
        local t = fis
        lists[fidx][fslot] = tis
        lists[tidx][tslot] = t
        return
    end

    -- fill
    if fis:get_name() == tis:get_name() and tcount <= tis:get_free_space() then
        local count = math.min(fis:get_count(), tis:get_free_space(), tcount)

        lists[tidx][tslot]:set_count(tis:get_count() + count)

        if fis:get_count() - count == 0 then
            lists[fidx][fslot] = ItemStack()
        else
            lists[fidx][fslot]:set_count(fis:get_count() - count)
        end

        return
    end
end

-- Deepcopy an inventory list
local function invlist_copy(list)
    local o = {}

    for i, v in ipairs(list) do
        o[i] = ItemStack(v:to_string())
    end

    return o
end

-- Add an invlist to a invaction quint if not there already
local function insert_invlist(q, taction)
    local idx = format_inv(taction)
    if q.start[idx] == nil then
        local mdata = minetest.get_inventory(taction.location)
        if mdata then
            q.start[idx] = mdata[taction.inventory]
            q.current[idx] = invlist_copy(mdata[taction.inventory])
        end
    end
end

-- Enqueue and preview an InventoryAction
function quint.invaction_enqueue(q, invaction)
    insert_invlist(q, invaction:to_table().from)
    insert_invlist(q, invaction:to_table().to)

    table.insert(q.q, invaction)

    simulate_invaction(q.current, invaction)
end

-- Dump a slot into destination, perform another dump if there is extra
local function invaction_dump_slot(q, src, dst, srci, dstbounds)
    local empty
    local matching

    local sinv = q.current[format_inv(src)]
    local dinv = q.current[format_inv(dst)]

    if sinv[srci]:is_empty() then
        return true
    end

    for i = dstbounds.min, dstbounds.max do
        if not empty and dinv[i]:is_empty() then
            empty = i
        end

        if not matching and dinv[i]:get_name() == sinv[srci]:get_name() then
            if dinv[i]:get_free_space() ~= 0 then
                matching = i
            end
        end

        if matching and empty then
            break
        end
    end

    if matching then
        local free = dinv[matching]:get_free_space()
        local scount = sinv[srci]:get_count()
        local count = math.min(free, scount)

        local act = InventoryAction("move")
        act:from(src.location, src.inventory, srci)
        act:to(dst.location, dst.inventory, matching)
        act:set_count(count)

        quint.invaction_enqueue(q, act)

        if scount > free then
            return invaction_dump_slot(q, src, dst, srci, dstbounds)
        end

        return true
    elseif empty then
        local act = InventoryAction("move")
        act:from(src.location, src.inventory, srci)
        act:to(dst.location, dst.inventory, empty)
        quint.invaction_enqueue(q, act)

        return true
    else
        return false
    end
end

local function rebind(lists, inv, bounds)
    local invlist = lists[format_inv(inv)]

    if not bounds then
        bounds = {min = 0, max = 0}
    end

    if bounds.max == 0 then
        bounds.max = #invlist
    end

    bounds.min = math.max(bounds.min, 1)
    bounds.max = math.min(bounds.max, #invlist)

    return bounds
end

-- Dump from src to dst
-- src and dest are in the format of {location = "", inventory = ""}
-- like {location = "current_player", inventory = "main"}
-- srcbounds and dstbounds are inclusive beginning and ends to the selectible invslots
-- in the form {min = n, max = n}, if max is 0 it is changed to the maximum index
function quint.invaction_dump(q, src, dst, srcbounds, dstbounds)
    if src.location .. src.inventory == dst.location .. dst.inventory then
        return
    end

    insert_invlist(q, src)
    insert_invlist(q, dst)

    srcbounds = rebind(q.current, src, srcbounds)
    dstbounds = rebind(q.current, dst, dstbounds)

    for i = srcbounds.min, srcbounds.max do
        if not invaction_dump_slot(q, src, dst, i, dstbounds) then
            return
        end
    end

    return
end

-- Remake a invaction quint up to index, refreshing the starts
function quint.invaction_remake(q, index)
    local t = quint.invaction_new()

    for i = 1, index do
        invaction_enqueue(t, q.q[i])
    end

    return t
end

-- Preview an invaction quint after the first n (index) actions
function quint.invaction_view_state_at(q, index)
    local t = quint.invaction_remake(q, index)

    return t.current
end

-- Refresh starts and get new currents
function quint.invaction_refresh(q)
    local t = quint.invaction_remake(q, #q.q)
    q.start = t.start
    q.current = t.current
end

quint.invaction_gsteps = {}

-- Apply an invaction quint, with optional delay
function quint.invaction_apply(q, delay)
    q.delay = delay

    if not delay or delay == 0 then
        for i, v in ipairs(q.q) do
            v:apply()
        end

        return
    end

    table.insert(quint.invaction_gsteps, q)
end

minetest.register_globalstep(function()
    local dead = {}

    local ctime = os.clock()

    for i, v in ipairs(quint.invaction_gsteps) do
        if not v.delay or ctime >= v.last + v.delay then
            if v.delay then
                v.last = v.last + v.delay
            end

            if v.q[v.index] then
                v.q[v.index]:apply()
                v.index = v.index + 1
            else
                table.insert(dead, 1, i)
            end
        end
    end

    for i, v in ipairs(dead) do
        table.remove(quint.invaction_gsteps, v)
    end
end)
