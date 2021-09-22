-- CC0/Unlicense Emilia 2020

-- TODO: support noteblocks on different blocktypes
--          denoted with S/W/O/etc. then the tone in a string?
-- TODO: polyphony?
-- TODO: multiple mod support

muse = {}
muse.playing = nil

-- assumes tone in param2
muse.noteblocks = {
    "mesecons_noteblock:noteblock"
}

muse.tracks = {
    ["test"] = {
        name = "example",
        interval = 0.25, -- in seconds
        notes = {
            10,
            10
        }
    }
}

local toneblocks = {}

local tones = {}

function muse.find_toneblocks(radius)
    radius = radius or 20

    local pos = vector.round(minetest.localplayer:get_pos())
    local nodes = minetest.find_nodes_near(pos, radius, muse.noteblocks)

    for i, v in ipairs(nodes) do
        local p2 = minetest.get_node_or_nil(v).param2
        local i = tostring(p2)

        if not toneblocks[i] then
            toneblocks[i] = {}
        end

        toneblocks[i][#toneblocks[i] + 1] = v
    end
end

function muse.play(note)
    if not note then
        return
    end

    if note == -1 then
        return
    end

    if type(note) == "string" then
        note = tones[note]
    end

    local poses = toneblocks[tostring(note)]
    if poses then
        local pos = poses[1]

        minetest.localplayer:set_pos(pos)
        minetest.interact("start_digging", pos)
        minetest.interact("stop_digging", pos)
    end
end

function muse.play_track(track)
    muse.playing = track
    muse.playing.idx = 1
    muse.playing.last = 0
end

minetest.register_globalstep(function()
    local now = os.clock()
    if muse.playing and muse.playing.last + muse.playing.interval <= now then
        muse.playing.last = now
        local note = muse.playing.notes[muse.playing.idx]
        if note then
            muse.play(note)
            muse.playing.idx = muse.playing.idx + 1
        else
            muse.playing = nil
        end
    end
end)

local function timestring(seconds)
    seconds = math.floor(seconds + 0.5)
    local mins = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d", mins, secs)
end

function muse.get_playing_string()
    if muse.playing then
        return string.format("Currently playing: %s, %d/%d (%s/%s)",
            muse.playing.name,
            muse.playing.idx,
            #muse.playing.notes,
            timestring(muse.playing.idx * muse.playing.interval),
            timestring(#muse.playing.notes * muse.playing.interval))
    else
        return "Nothing is playing"
    end
end

minetest.register_chatcommand("findtones", {
    description = "Find tone blocks in the vicinity.",
    func = function()
        toneblocks = {}
        muse.find_toneblocks()

        local len = 0
        for k, v in pairs(toneblocks) do
            len = len + 1
        end

        minetest.display_chat_message("Found " .. tostring(len) .. " out of 25 tones")
    end
})

minetest.register_chatcommand("play", {
    description = "Play a musical track",
    params = "<track>",
    func = function(params)
        local track = muse.tracks[params]
        if track then
            muse.play_track(track)
            minetest.display_chat_message("Now playing " .. muse.playing.name)
        else
            minetest.display_chat_message("Track not found.")
        end
    end
})

minetest.register_chatcommand("playing", {
    description = "Show currently playing track and its progress",
    func = function()
        minetest.display_chat_message(muse.get_playing_string())
    end
})
