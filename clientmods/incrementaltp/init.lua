-- CC0/Unlicense Emilia 2021

incremental_tp = {}

incremental_tp.fudge = 0.8 -- cause the tp time isn't synced with the server
incremental_tp.tpactive=false

-- for Clamity
incremental_tp.max_instantaneous_tp = {
    x = 6,
    y = 50,
    z = 6
}
local wason=false
local function sign(n)
    if n == 0 then
        return 0
    end

    return n / math.abs(n)
end

local function max_dist_per(vec, time)
    local mitp = vector.multiply(incremental_tp.max_instantaneous_tp,
                                  incremental_tp.fudge)
    local nvec = {x = 0, y = 0, z = 0}
    nvec.x = sign(vec.x) * math.min(math.abs(vec.x), mitp.x * time)
    nvec.z = sign(vec.z) * math.min(math.abs(vec.z), mitp.z * time)
    -- negative y speed cap is infinity, so if y < 0 it is always allowed
    nvec.y = math.min(vec.y, mitp.y * time)
    return nvec
end

local function tpstep(target, time, second, variance,sfunc)
    local pos = minetest.localplayer:get_pos()
    local vec = vector.subtract(target, pos)
    minetest.settings:set_bool("free_move",true)
    if not incremental_tp.tpactive and wason then
        wason=false
        return
    end
    wason=true
    incremental_tp.tpactive=true
    if  math.abs(vec.x) + math.abs(vec.y) + math.abs(vec.z) < 1 then
        minetest.localplayer:set_pos(target)
        incremental_tp.tpactive=false
        minetest.display_chat_message("Arrived at " .. minetest.pos_to_string(target))
        if sfunc then
            minetest.after(time, function()
                sfunc(target)
            end)
        end
        return
    end

    if second < 0.001 then
        second = 1
    end

    local intime = math.min(time, second)
    if variance then
        -- you can't move faster than 1 second of distance instantaneously
        intime = math.min(1, math.random() * variance - variance / 2 + intime)
    end

    local nvec = max_dist_per(vec, intime)

    minetest.localplayer:set_pos(vector.add(pos, nvec))

    minetest.after(intime, function()
        tpstep(target, time, second - intime, variance,sfunc)
    end)
end

function incremental_tp.tp(target, time, variance)
    if incremental_tp.tpactive then return end
    tpstep(target, time, 1, variance)
end

function incremental_tp.tpafter(target,time,variance,sfunc)
    if incremental_tp.tpactive then return end
    tpstep(target,time,1,variance,sfunc)
end

if autofly then autofly.register_transport('itp',function(pos,name) incremental_tp.tp(pos,1) end) end

if autofly then autofly.register_transport('jitp',function(pos,name) incremental_tp.tp(pos,0.5,0.4) end) end

minetest.register_chatcommand("itp", {
    description = "Teleport to destination with fixed increments.",
    params = "<destination>",
    func = function(params)
        local pos = minetest.string_to_pos(params)

        incremental_tp.tp(pos, 1)
    end
})

minetest.register_chatcommand("jittertp", {
    description = "Teleport to destination with jittery increments.",
    params = "<destination>",
    func = function(params)
        local pos = minetest.string_to_pos(params)

        incremental_tp.tp(pos, 0.5, 0.4)
    end
})

-- chunk_rand
