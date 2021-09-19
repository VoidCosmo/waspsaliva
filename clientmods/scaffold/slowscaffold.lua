-- CC0/Unlicense Emilia 2020

if minetest.settings:get("slow_blocks_per_second") == nil then
    minetest.settings:set("slow_blocks_per_second", 8)
end

-- Could remove the queue and have nowplace() check if it can place at the position

local lastt = 0

local posqueue = {}

local function posq_pos(pos)
    local plen = #posqueue
    for i = 0, #posqueue - 1 do
        if vector.equals(pos, posqueue[plen - i]) then
            return plen - i
        end
    end
end

local function nowplace(pos)
    local p = posq_pos(pos)
    if p then
        table.remove(posqueue, p)
    end

    minetest.place_node(pos)
end

local function place(pos)
    if not posq_pos(pos) then
        local now = os.clock()

        if lastt < now then
            lastt = now
        end

        local interval = 1 / minetest.settings:get("slow_blocks_per_second")
        lastt = lastt + interval

        minetest.after(lastt - now, nowplace, pos)

        posqueue[#posqueue + 1] = pos
    end
end

scaffold.register_template_scaffold("SlowScaffold", "scaffold_slow", function(pos)
    if scaffold.can_place_wielded_at(pos) then
        place(pos)
    end
end)
