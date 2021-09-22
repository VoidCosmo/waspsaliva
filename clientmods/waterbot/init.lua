-- CC0/Unlicense Emilia 2020
waterbot = {}

-- TODO: FreeRefills tries to pick up too much at once
--          quint time :]

-- Lua doesnt have enums and tables look gross
-- should still be a table tho
local WATER_USABLE = 0  -- water source
local WATER_STABLE = 1  -- water source used for refreshing other sources
local WATER_USED = 2    -- water source that can be bucketed
local AIR = 3           -- something that water can flow into and renew
local SOLID = 4         -- something that water cannot flow into and renew

local function get_offset(pos, radius)
    return vector.round({
        x = pos.x - radius - 1,
        y = pos.y - radius - 1,
        z = pos.z - radius - 1
    })
end

-- returns {{{n n n} {n n n} ...} {...} ...}
local function get_intarr(pos, radius)
    local offset = get_offset(pos, radius)
    local out = {}
    local diameter = radius * 2 + 1

    for z = 1, diameter do
        table.insert(out, {})
        for y = 1, diameter do
            table.insert(out[#out], {})
            for x = 1, diameter do
                local npos = {x = x, y = y, z = z}
                local node = minetest.get_node_or_nil(vector.add(offset, npos))
                local v = SOLID
                if node then
                    if node.name == "mcl_core:water_source" then
                        v = WATER_USABLE
                    elseif node.name == "air" then
                        v = AIR
                    end
                end
                table.insert(out[#out][#out[#out]], v)
            end
        end
    end

    return out
end

local function coord_valid(coord, width, height)
    return ((coord[1] > 0) and (coord[2] > 0)) and ((coord[1] <= width) and (coord[2] <= height))
end

-- returns modified list and safe sources
-- table is [z][y][x] accessed
-- safe sources is a coordinate list
-- this is like cellular automata but the state is mogrified in place
local function mogrify_stable(t, offset)
    local safe = {}

    -- indented like this because this is necessary and full indent would be ugly
    for zi, zv in ipairs(t) do
     for yi, yv in ipairs(zv) do
      for xi, xv in ipairs(yv) do
       if xv == WATER_USABLE then
            local nhood = {
                {xi - 1, zi},
                {xi, zi - 1},
                {xi + 1, zi},
                {xi, zi + 1}
            }

            local last
            local applied = false

            for i, v in ipairs(nhood) do
                if not applied and coord_valid(v, #yv, #t) then
                    local check = t[v[2]][yi][v[1]]
                    if check == WATER_USABLE or check == WATER_STABLE then
                        if not last then
                            last = v
                        else
                            t[   v[2]][yi][   v[1]] = WATER_STABLE
                            t[last[2]][yi][last[1]] = WATER_STABLE
                            yv[xi] = WATER_USED
                            table.insert(safe,
                                vector.add(offset,
                                    {x = xi, y = yi, z = zi}))
                            applied = true
                        end
                    end
                end
            end
       end
      end
     end
    end

    return t, safe
end

function waterbot.find_renewable_water_near(pos, radius)
    local int = get_intarr(pos, radius)
    local offset = get_offset(pos, radius)
    local mint, safe = mogrify_stable(int, offset)
    return safe
end


local epoch = os.clock()

minetest.register_globalstep(function()
    if minetest.settings:get_bool("waterbot_refill") and os.clock() >= epoch + 2 then
        local pos = minetest.localplayer:get_pos()
        local sources = waterbot.find_renewable_water_near(pos, 6)

        for i, v in ipairs(sources) do
            if minetest.switch_to_item("mcl_buckets:bucket_empty") then
                minetest.interact("place", v)
            else
                break
            end
        end

        epoch = os.clock()
    end
end)

minetest.register_cheat("FreeRefills", "Inventory", "waterbot_refill")
