-- CC0/Unlicense system32 2020

local function init_settings(setting_table)
    for k, v in pairs(setting_table) do
        if minetest.settings:get(k) == nil then
            if type(v) == "boolean" then
                minetest.settings:set_bool(k, v)
            else
                minetest.settings:set(k, v)
            end
        end
    end
end

init_settings({
    hignore_ignore_all = false,
    hignore_highlight_all = false,
    hignore_highlight_all_color = "#FFFFFF",
    hignore_strip_all = false,
    hignore_log = true
})

local storage = minetest.get_mod_storage()

local function storage_init_table(key)
    if storage:get(key) == nil or storage:get(key) == "null" then
        storage:set_string(key, "{}")
    end

    return minetest.parse_json(storage:get_string(key))
end

local function storage_save_json(key, value)
    storage:set_string(key, minetest.write_json(value))
end


-- public interface
hignore = {}

-- name: color
hignore.highlight = storage_init_table("hignore_highlight")

-- name: mode
hignore.ignore = storage_init_table("hignore_ignore")

-- strip: mode
hignore.strip = storage_init_table("hignore_strip")


function hignore.save()
    storage_save_json("hignore_highlight", hignore.highlight)
    storage_save_json("hignore_ignore", hignore.ignore)
    storage_save_json("hignore_strip", hignore.strip)
end


local function localize_player(player)
    local info = minetest.get_server_info()

    local name = info.ip
    if info.address ~= "" then
        name = info.address
    end

    return player .. "@" .. name .. ":" .. info.port
end

local playerat

local function log(message)
    if minetest.settings:get_bool("hignore_log") then
        if playerat == nil then
            playerat = localize_player(minetest.localplayer:get_name())
        end
        minetest.log("action", "[hignore] " .. playerat .. " " .. message)
    end
end

local function display(message)
    if minetest.settings:get_bool("hignore_strip_colors") then
        message = minetest.strip_colors(message)
    end

    local dm = message:match(".*rom (.-): .*")
    local pub = message:match("<(.-)>.*")
    local is_dm = false

    local player = dm or pub
    if dm then
        is_dm = true
    end

    if player then
        player = localize_player(dm or pub)
    else
        return
    end

    -- ignore and hide
    if hignore.ignore[player] or minetest.settings:get_bool("hignore_ignore_all") then
        if hignore.ignore[player] == "summarize" then
            if dm then
                minetest.display_chat_message(player .. " sent you a DM.")
            else
                minetest.display_chat_message(player .. " sent a message.")
            end
        end
        return true
    end

    -- strip title
    if not is_dm and (hignore.strip[player] or minetest.settings:get_bool("hignore_strip_all")) then
        message = message:match(".- (.*)") or message
        if hignore.highlight[player] == nil then
            minetest.display_chat_message(message)
            return true
        end
    end

    -- highlight message
    if hignore.highlight[player] then
        minetest.display_chat_message(minetest.colorize(hignore.highlight[player], message))
        return true
    end

    if minetest.settings:get_bool("hignore_highlight_all") then
        minetest.display_chat_message(
            minetest.colorize(
                minetest.settings:get("hignore_highlight_all_color"),
                message))
        return true
    end

    if minetest.settings:get_bool("hignore_strip_colors") then
        minetest.display_chat_message(message)
        return true
    end
end

minetest.register_on_receiving_chat_message(function(message)
    local l = display(message)

    if l then
        log(message)
    end

    return l
end)


local function noplayer()
    minetest.display_chat_message("No player specified.")
end

local function string_table(t)
    local out = ""
    for k, v in pairs(t) do
        if out ~= "" then
            out = out .. ", " .. tostring(k) .. ": " .. tostring(v)
        else
            out = tostring(k) .. ": " .. tostring(v)
        end
    end

    if out == "" then
        return "Empty"
    else
        return out
    end
end


minetest.register_chatcommand("ignore", {
    params = "<player> <mode>",
    description = "Ignore a player's messages, mode can be omitted (hide) or hide/summarize/none (stops ignoring).",
    func = function(params)
        local plist = string.split(params, " ")
        if plist[1] == nil then
            noplayer()
            return
        end

        local player = localize_player(plist[1])
        local val = plist[2]

        -- hide/summarize are already set
        if plist[2] == nil then
            val = "hide"
        elseif plist[2] == "none" then
            val = nil
        end

        hignore.ignore[player] = val
        hignore.save()
    end
})

minetest.register_chatcommand("ignore_list", {
    description = "List ignored players.",
    func = function(params)
        minetest.display_chat_message(string_table(hignore.ignore))
    end
})

minetest.register_chatcommand("highlight", {
    params = "<player> <color>",
    description = "Highlight a player's messages, omit color to stop highlighting. Supports CSS and RGBA hex colors.",
    func = function(params)
        local plist = string.split(params, " ")
        if plist[1] == nil then
            noplayer()
            return
        end

        local player = localize_player(plist[1])

        hignore.highlight[player] = plist[2]
        hignore.save()
    end
})

minetest.register_chatcommand("highlight_list", {
    description = "List highlighted players.",
    func = function(params)
        minetest.display_chat_message(string_table(hignore.highlight))
    end
})

minetest.register_chatcommand("strip", {
    params = "<player>",
    description = "Toggle stripping of a player's titles.",
    func = function(params)
        local plist = string.split(params, " ")
        if plist[1] == nil then
            noplayer()
            return
        end

        local player = localize_player(plist[1])

        if hignore.strip[player] then
            hignore.strip[player] = nil
        else
            hignore.strip[player] = "remove"
        end
        hignore.save()
    end
})

minetest.register_chatcommand("strip_list", {
    description = "List players with stripped titles.",
    func = function(params)
        minetest.display_chat_message(string_table(hignore.strip))
    end
})
