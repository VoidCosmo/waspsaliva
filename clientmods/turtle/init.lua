-- CC0/Unlicense Emilia 2020

turtle = {}

local mod_prefix = minetest.get_modpath(minetest.get_current_modname())
tlang = dofile(mod_prefix .. "/tlang.lua")

function turtle.coord(x, y, z)
    return {x = x, y = y, z = z}
end

turtle.pos1 = turtle.coord(0, 0, 0)
turtle.pos2 = turtle.coord(0, 0, 0)

local function format_coord(c)
    return tostring(c.x) .. " " .. tostring(c.y) .. " " .. tostring(c.z)
end

local function parse_coord(c)
end

-- can include ~ + - along with num and ,
local function parse_relative_coord(c)
end

function turtle.ordercoord(c)
    if c.x == nil then
        return {x = c[1], y = c[2], z = c[3]}
    else
        return c
    end
end

-- x or {x,y,z} or {x=x,y=y,z=z}
function turtle.optcoord(x, y, z)
    if y and z then
        return turtle.coord(x, y, z)
    else
        return turtle.ordercoord(x)
    end
end

-- swap x and y if x > y
local function swapg(x, y)
    if x > y then
        return y, x
    else
        return x, y
    end
end

-- swaps coordinates around such that (matching ords of) c1 < c2 and the overall cuboid is the same shape
function turtle.rectify(c1, c2)
    c1.x, c2.x = swapg(c1.x, c2.x)
    c1.y, c2.y = swapg(c1.y, c2.y)
    c1.z, c2.z = swapg(c1.z, c2.z)
    return c1, c2
end

-- converts a coordinate to a system where 0,0 is the southwestern corner of the world
function turtle.zeroidx(c)
    local side = 30912
    return turtle.coord(c.x + side, c.y + side, c.z + side)
end

-- swaps coords and subtracts such that c1 == {0, 0, 0} and c2 is the distance from c1
-- returns rectified c1/c2 and the relativized version
function turtle.relativize(c1, c2)
    c1, c2 = turtle.rectify(c1, c2)

    local c1z = turtle.zeroidx(c1)
    local c2z = turtle.zeroidx(c2)

    local rel = turtle.coord(c2z.x - c1z.x, c2z.y - c1z.y, c2z.z - c1z.z)

    return c1, rel
end


-- get the inventory index of the best tool to mine x, y, z
-- returns a wield index, which starts at 0
function turtle.get_best_tool_index(x, y, z)
    local node = minetest.get_node_or_nil(turtle.optcoord(x, y, z))
    if not node then
        return
    end

    local nodecaps = minetest.get_node_def(node.name).groups

    local idx = minetest.localplayer:get_wield_index()
    local best = math.huge

    for i, v in ipairs(minetest.get_inventory("current_player").main) do
        for gk, gv in pairs(v:get_tool_capabilities().groupcaps) do
            local level = nodecaps[gk]
            if level and gv.times[level] < best then
                idx = i
                best = gv.times[level]
            end
        end
    end

    return idx
end

-- switch to the fastest tool to mine x, y, z
function turtle.switch_best(x, y, z)
    local prev = minetest.localplayer:get_wield_index()

    local index = turtle.get_best_tool_index(x, y, z)

    if prev ~= index then
        minetest.localplayer:set_wield_index(index)
    end
end


function turtle.mine(x, y, z)
    turtle.switch_best(x, y, z)
    minetest.dig_node(turtle.optcoord(x, y, z))
end

function turtle.place(x, y, z)
    minetest.place_node(turtle.optcoord(x, y, z))
end

function turtle.cadd(c1, c2)
    return turtle.coord(c1.x + c2.x, c1.y + c2.y, c1.z + c2.z)
end

function turtle.relcoord(x, y, z)
    local pos = minetest.localplayer:get_pos()
    if pos.y > -5000 then pos.y=pos.y-1 end
    return turtle.cadd(pos, turtle.optcoord(x, y, z))
end

local function between(x, y, z) -- x is between y and z (inclusive)
    return y <= x and x <= z
end

function turtle.getdir() --
    local rot = minetest.localplayer:get_yaw() % 360
    if between(rot, 315, 360) or between(rot, 0, 45) then
        return "north"
    elseif between(rot, 135, 225) then
        return "south"
    elseif between(rot, 225, 315) then
        return "east"
    elseif between(rot, 45, 135) then
        return "west"
    end
end
function turtle.setdir(dir) --
    if dir == "north" then
        minetest.localplayer:set_yaw(0)
    elseif dir == "south" then
        minetest.localplayer:set_yaw(180)
    elseif dir == "east" then
        minetest.localplayer:set_yaw(270)
    elseif dir == "west" then
        minetest.localplayer:set_yaw(90)
    end
end

function turtle.dircoord(f, y, r)
    local dir=turtle.getdir()
    local coord = turtle.optcoord(f, y, r)
    local f = coord.x
    local y = coord.y
    local r = coord.z
    local lp=minetest.localplayer:get_pos()
    if dir == "north" then
        return turtle.relcoord(r, y, f)
    elseif dir == "south"  then
        return turtle.relcoord(-r, y, -f)
    elseif dir == "east" then
        return turtle.relcoord(f, y, -r)
    elseif dir== "west" then
        return turtle.relcoord(-f, y, r)
    end

    return turtle.relcoord(0, 0, 0)
end

function turtle.move(x, y, z)
    minetest.localplayer:set_pos(turtle.optcoord(x, y, z))
end

function turtle.advance(amount)
    amount = amount or 1
    turtle.move(turtle.dircoord(amount, 0, 0))
end

function turtle.descend(amount)
    amount = amount or 1
    turtle.move(turtle.relcoord(0, -amount, 0))
end

function turtle.rotate_abs(deg)
    minetest.localplayer:set_yaw(deg)
end

function turtle.rotate(deg)
    local prev = minetest.localplayer:get_yaw()
    minetest.localplayer:set_yaw((prev + deg) % 360)
end

function turtle.rotate_right(deg)
    deg = deg or 90
    turtle.rotate(-deg)
end

function turtle.rotate_left(deg)
    deg = deg or 90
    turtle.rotate(deg)
end

function turtle.isblock(block, x, y, z)
    local node = minetest.get_node_or_nil(turtle.optcoord(x, y, z))
    return node ~= nil and block == node.name
end

function turtle.checkmine(x, y, z)
    while true do
        turtle.mine(x, y, z)
        busysleep(0.125)
        -- i hate lua
        minetest.log(tostring(turtle.isblock("air", x, y, z)))
        if turtle.isblock("air", x, y, z) then
            break
        end
    end
end

function turtle.tp(coords)
    minetest.localplayer:set_pos(coords)
end

function turtle.moveto(x, y, z)
    turtle.tp(turtle.optcoord(x, y, z))
end

function turtle.linemine(distance, func)
    for i = 1, distance do
        turtle.checkmine(turtle.dircoord(1, 1, 0))
        turtle.checkmine(turtle.dircoord(1, 0, 0))
        turtle.advance()

        if func then
            func()
        end
    end
end


local function left_or_right(left)
    if left then
        turtle.rotate_left()
    else
        turtle.rotate_right()
    end
end


local function quarry_clear_liquids()
    -- puts blocks in front, both sides, and two below where they are liquid
    -- it does all this one step ahead so no spillage may occur
end


-- needs to check for liquids (would need to be done in linemine)
function turtle.quarry(cstart, cend)
    -- get a nice cuboid
    cstart, cend = turtle.rectify(cstart, cend)
    local start, relend = turtle.relativize(cstart, cend)

    -- makes it start at the top rather than the bottom
    cend.y, cstart.y = swapg(cend.y, cstart.y)

    -- go to the start
    turtle.moveto(turtle.cadd(cstart, turtle.coord(0, 1, 0)))
    turtle.rotate_abs(0)

    -- main loop (zig zag pattern)
    for height = 0, math.floor(relend.y / 2) do
        -- go down two blocks
        turtle.mine(turtle.relcoord(0, -1, 0))
        turtle.mine(turtle.relcoord(0, -2, 0))
        turtle.descend(2)

        for width = 0, relend.x do
            -- swaps left/right rotations each layer and zig zag
            local leftiness = ((height + width + 1) % 2) == 0

            -- actually mine
            turtle.linemine(relend.z) -- maybe relend.z to make the end inclusive?
            left_or_right(leftiness)
            -- dont rotate at the end of the layer
            if width ~= relend.x then
                turtle.linemine(1)
                left_or_right(leftiness)
            end
        end

        -- flip around to start again on the next layer
        turtle.rotate(180)
    end
end


minetest.register_chatcommand("quarry", {
    func = function()
        turtle.quarry({x = -60, y = 1, z = -60}, {x = -40, y = -5, z = -40})
    end
})

turtle.builtins = {}

function turtle.builtins.mine(state)

end

function turtle.builtins.advance(state)

end

function turtle.builtins.descend(state)

end

function turtle.builtins.v3add(state)

end

function turtle.builtins.rotate(state)

end

function turtle.builtins.relativize(state)

end

function turtle.builtins.swapg(state)

end

function turtle.builtins.rectify(state)

end

local quarry_tlang = [[
# turtle.builtins: mine advance v3add descend rotate relativize swapg rectify
# tlang operators: //

################################
# Mine ahead length nodes (including head and feet)
{   0 `length args
####
    {
        i length == {break} if

        [1 1 0] dircoord mine
        [1 0 0] dircoord mine
        1 wait
        advance
    } `i forever
} `linemine =


################################
# Mine the cuboid defined by start and end
{   0 `start `end args
####
    rectify `start = `end =
    start end relativize

    start end swapg_y `relstart = `relend =

    start [0 1 0] v3add moveto
    0 rotate_abs

    relend.y 2 // `yend =

    {
        height yend > {break} if

        [0 -1 0] dircoord mine
        [0 -2 0] dircoord mine
        2 descend

        {
            width relend.x > {break} if

            height width + 1 + 2 % 0 == `leftiness =

            relend.z linemine
            leftiness left_or_right

            width relend.x != {
                1 linemine
                leftiness left_or_right
            } if
        } `width forever

        180 rotate
    } `height forever
} `quarry =
]]


turtle.states = {}
turtle.states_available = false

function turtle.schedule(name, state)
    if type(name) == "table" then
        error("turtle.schedule: first parameter should be the task's name")
        return
    end

    turtle.states[#turtle.states + 1] = {name = name, state = state}
    turtle.states_available = true
end

function turtle.get_symbolic(name)
    local dead = {}

    for i, v in ipairs(turtle.states) do
        if i == name or v.name == name then
            table.insert(dead, 1, i)
        end
    end

    return dead
end

function turtle.kill_symbolic(name)
    local dead = turtle.get_symbolic(name)

    for i, v in ipairs(dead) do
        table.remove(turtle.states, v)
    end
end

function turtle.pause_symbolic(name)
    local dead = turtle.get_symbolic(name)

    for i, v in ipairs(dead) do
        turtle.states[v].state.paused = true
    end
end

function turtle.resume_symbolic(name)
    local dead = turtle.get_symbolic(name)

    for i, v in ipairs(dead) do
        turtle.states[v].state.paused = nil
    end
end

function turtle.run_states(dtime)
    if turtle.states_available then
        local dead = {}

        for i, v in ipairs(turtle.states) do
            local ret = tlang.step(v.state)
            if ret ~= true and ret ~= nil then
                if type(ret) == "string" then
                    minetest.display_chat_message("Turtle/tlang ERROR in " .. v.name .. ": " .. ret)
                end
                table.insert(dead, 1, i)
            end
        end

        for i, v in ipairs(dead) do
            table.remove(turtle.states, v)
        end

        turtle.states_available = #turtle.states ~= 0
    end
end

minetest.register_globalstep(turtle.run_states)

minetest.register_chatcommand("tlang", {
    description = "Run a tlang program.",
    params = "<code>",
    func = function(params)
        local state = tlang.get_state(params)
        turtle.schedule("chat_script", state)
    end
})

minetest.register_chatcommand("tl_list", {
    description = "List running tlang states.",
    func = function()
        for i, v in ipairs(turtle.states) do
            minetest.display_chat_message(tostring(i) .. " " .. v.name)
        end
    end
})

minetest.register_chatcommand("tl_kill", {
    description = "Kill a tlang state.",
    params = "<task>",
    func = turtle.kill_symbolic
})

minetest.register_chatcommand("tl_pause", {
    description = "Pause a tlang state.",
    params = "<task>",
    func = turtle.pause_symbolic
})

minetest.register_chatcommand("tl_resume", {
    description = "Resume a tlang state.",
    params = "<task>",
    func = turtle.resume_symbolic
})
