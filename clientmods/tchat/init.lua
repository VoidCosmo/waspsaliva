---
-- coras teamchat ..  indev v0.5
--
-- adds a team chat for you and a couple friends, also prevents accidental sending of coordinates
-- to say something in teamchat either activate teammode in the dragonfire menu or use .t message
--
-- supports the Wisp encrypted whisper mod
--
-- .t to say something in team chat (or regular chat if team mode is on)
-- .tadd to add a team member
-- .tdel to remove
-- .tlist to list team
--
-- .coords to send a message containing coordinates
-- .mcoord to send a player your current coordinates


--[[
Public methods

tchat.contains_coords(message) - returns true if the message contains coordinates (2d or 3d)

tchat.send(message) - send a message to teamchat, returns true if sent, nil if not
tchat.send_conditional(message, inverse?) - send a message to teamchat or regular chat, returns true if sent to teamchat, false if main chat, nil if not sent
tchat.send_coords(message) - send a message containing coordinates, true if sent, nil if not

tchat.whisper_coords(player) - DM current coords to a player

tchat.chat_clear() - clear chat widget
tchat.chat_set([]) - set chat widget
tchat.chat_append([] or message) - append to chat widget

tchat.team_add_player(player) - add player to team list
tchat.team_remove_player(player) - remove player from team list
tchat.team_clear() - clear team list
tchat.team_set([]) - set team list


Public properties

tchat.chat: last few chat messages
tchat.team: team list
tchat.team_online: online team list
tchat.players: currently online players


Settings

bool tchat_view_chat        - if the team chat is shown
bool tchat_view_team_list   - if the team list is shown
bool tchat_view_player_list - if the player list is shown
bool tchat_team_mode        - if team mode is on

bool tchat_colorize_team    - if true, team list will show all team members colored for who is online
bool tchat_use_wisp         - if true, encrypt all messages using Wisp

str  tchat_prefix_message   - prefix for teamchat messages
str  tchat_prefix_receive   - prefix for received messages
str  tchat_prefix_self      - prefix for self sent messages
str  tchat_prefix_send      - prefix for sent messages

str  tchat_blacklist        - comma separated list of accounts that cannot send team chat messages (useful for secret alts)

num  tchat_chat_length      - chat length (messages, not lines)
num  tchat_chat_width       - chat width (columns)
--]]


---
-- settings

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
    tchat_view_chat = false,
    tchat_view_team_list = true,
    tchat_view_player_list = true,
    tchat_team_mode = false,

    tchat_colorize_team = false,

    tchat_prefix_message = "TCHAT",
    tchat_prefix_receive = "From",
    tchat_prefix_self = "To Yourself",
    tchat_prefix_send = "To",

    tchat_use_wisp = false,

    tchat_hide_sent = true,
    tchat_blacklist = "",

    tchat_chat_length = 6,
    tchat_chat_width = 80
})


---
-- globals

tchat = {}

tchat.team = {}
tchat.team_online = {}
tchat.chat = {}
tchat.players = {}

-- used for logs
local server_info = minetest.get_server_info()
local server_id = server_info.address .. ':' .. server_info.port

local max_total_chat_length = 1024

local player_list_epoch = 0

local message_prefix = minetest.settings:get("tchat_prefix_message")
local message_receive = minetest.settings:get("tchat_prefix_receive")
local message_receive_self = minetest.settings:get("tchat_prefix_self")
local message_to = minetest.settings:get("tchat_prefix_send")

local team_mode = minetest.settings:get_bool("tchat_team_mode")

local use_wisp = minetest.settings:get_bool("tchat_use_wisp")

local hide_sent = minetest.settings:get_bool("tchat_hide_sent")
local blacklist = string.split(minetest.settings:get("tchat_blacklist"))

local chat_length = tonumber(minetest.settings:get("tchat_chat_length"))
local chat_width = tonumber(minetest.settings:get("tchat_chat_width"))

local storage = minetest.get_mod_storage()

if storage:get("tchat_team") == nil or storage:get("tchat_team") == "null" then
    storage:set_string("tchat_team", "[]")
end

tchat.team = minetest.parse_json(storage:get_string("tchat_team"))

-- overrides contains_coords() the next time it runs
local message_confirmed_safe = false

-- coordinate matching
local pattern = "[-]?%d[.%d]*"
local space = "[,%s]+"
local pattern_three = pattern .. space .. pattern .. space .. pattern
local pattern_two = pattern .. space .. pattern

local chat_idx
local player_list_idx
local team_list_idx
local chat_str = ""


---
-- private stuff

local function apply(list, func, filter)
    local out = {}
    for k, v in ipairs(list) do
        if filter(v) then
            out[#out + 1] = func(v)
        else
            out[#out + 1] = v
        end
    end
    return out
end

local function uniq(list)
    local last
    local out = {}
    for k, v in ipairs(list) do
        if last ~= v then
            out[#out + 1] = v
        end
        last = v
    end
    return out
end

-- limit a list to the last size elements
local function limit_list(list, size)
    local out = {}
    for i = math.max(1, #list - size), #list do
        out[#out + 1] = list[i]
    end
    return out
end

local function in_list(list, value)
    for k, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end


local function get_team_str()
    if minetest.settings:get_bool("tchat_colorize_team") then
        return table.concat(apply(tchat.team,
            function(value)
                return minetest.colorize("#00FFFF", value)
            end,
            function(value)
                return in_list(tchat.team_online, value)
            end), "\n")
    else
        return table.concat(tchat.team_online, "\n")
    end
end


local function display_chat()
    return minetest.localplayer:hud_add({
        hud_elem_type = 'text',
        name          = "Teamchat",
        text          = "Team Chat\n\n" .. chat_str,
        number        = 0xEEFFEE,
        direction     = 0,
        position      = {x=0.01, y=0.45},
        scale         = {x=0.9, y=0.9},
        alignment     = {x=1, y=1},
        offset        = {x=0, y=0}
    })
end

local function display_player_list()
    return minetest.localplayer:hud_add({
        hud_elem_type = 'text',
        name          = "Online Players",
        text          = "Players\n\n" .. table.concat(tchat.players, "\n"),
        number        = 0xDDFFDD,
        direction     = 0,
        position      = {x=0.9, y=0.01},
        alignment     = {x=1, y=1},
        offset        = {x=0, y=0}
    })
end

-- should prob have all team members with online ones colored
local function display_team_list()
    return minetest.localplayer:hud_add({
        hud_elem_type = 'text',
        name          = "Team",
        text          = "Team\n\n" .. get_team_str(),
        number        = 0x00FF00,
        direction     = 0,
        position      = {x=0.8, y=0.01},
        alignment     = {x=1, y=1},
        offset        = {x=0, y=0}
    })
end

local function auto_display(idx, setting, func)
    if minetest.settings:get_bool(setting) then
        if not idx then
            return func()
        end
    else
        if idx then
            minetest.localplayer:hud_remove(idx)
            return nil
        end
    end
    return idx
end

local function auto_update(idx, text)
    if idx ~= nil then
        minetest.localplayer:hud_change(idx, "text", text)
    end
end

local function update_team_online()
    tchat.team_online = {}
    for k, v in ipairs(tchat.players) do
        if in_list(tchat.team, v) then
            tchat.team_online[#tchat.team_online + 1] = v
        end
    end
end

local function update_chat_str()
    chat_str = ""
    for k, v in ipairs(limit_list(tchat.chat, chat_length - 1)) do
        chat_str = chat_str .. "\n" .. minetest.wrap_text(v, chat_width)
    end
    chat_str = table.concat(limit_list(string.split(chat_str, "\n"), chat_length - 1), "\n")

    -- update chat (do it here so external mods can add to the chat)
    auto_update(chat_idx, "Team Chat\n\n" .. chat_str)
end

local function team_add_self()
    tchat.team_add_player(minetest.localplayer:get_name())
end


---
-- public interface


function tchat.contains_coords(message)
    if (not message_confirmed_safe and (message:find(pattern_three) or message:find(pattern_two))) then
        return true
    end
    return false
end


local function dm(player, message)
    if wisp == nil or not use_wisp then
        minetest.send_chat_message("/msg " .. player .." " .. message)
    else
        wisp.send(player, message, true)
    end
end

-- send
function tchat.send(message, force_coords, force_commands)
    if (tchat.contains_coords(message) and not force_coords) or in_list(blacklist, minetest.localplayer:get_name()) then
        return
    end

    if message:sub(1,1) == "/" and not force_commands then
        minetest.display_chat_message("A /command was scheduled to be sent to team chat but wasn't sent.")
        return
    end

    local me = minetest.localplayer:get_name()

    if not in_list(tchat.team, minetest.localplayer:get_name()) then
        team_add_self()
    end

    update_team_online()

    local prepend = ""
    if use_wisp then
        prepend = "E "
    end

    tchat.chat_append(prepend .. me .. ": " .. message)

    for k, p in ipairs(tchat.team_online) do
        if p ~= me then
            dm(p, message_prefix .. " " .. message)
        end
    end
    return true
end

function tchat.send_conditional(message, inverse, force_coords)
    if tchat.contains_coords(message) and not force_coords then
        return
    end

    team_mode = minetest.settings:get_bool("tchat_team_mode")

    local tm = team_mode
    if inverse then
        tm = not team_mode
    end

    if tm then
        tchat.send(message)
        return true
    else
        minetest.send_chat_message(message)
        return false
    end
end

function tchat.send_coords(message)
    message_confirmed_safe = true
    local ret = tchat.send_conditional(message)
    message_confirmed_safe = false
    return ret
end


function tchat.whisper_coords(player)
    if player == "" then
        return
    end
    local coords = minetest.pos_to_string(vector.round(minetest.localplayer:get_pos()))
    minetest.run_server_chatcommand("w", param .. " " .. coords)
end


-- chat
local function autoclear_chat()
    if #tchat.chat > max_total_chat_length then
        tchat = limit_list(tchat.chat, max_chat_total_length)
    end
end

function tchat.chat_clear()
    tchat.chat = {}
    update_chat_str()
end

function tchat.chat_set(message_list)
    chat = message_list
    autoclear_chat()
    update_chat_str()
end

function tchat.chat_append(message)
    tchat.chat[#tchat.chat + 1] = message
    autoclear_chat()

    minetest.log("action", "[tchat] " .. minetest.localplayer:get_name() .. "@" .. server_id .. " " .. message)

    update_chat_str()

    -- popup chat if its closed
    minetest.settings:set_bool("tchat_view_chat", true)
    chat_idx = auto_display(chat_idx, "tchat_view_chat", display_chat)
end


local function team_save()
    storage:set_string("tchat_team" , minetest.write_json(tchat.team))
end

-- team
function tchat.team_add_player(player)
    if not in_list(tchat.team, player) then
        tchat.team[#tchat.team + 1] = player
        update_team_online()
        team_save()
    end
end

function tchat.team_remove_player(player)
    local out = {}
    for k, v in ipairs(tchat.team) do
        if v ~= player then
            out[#out + 1] = v
        end
    end
    tchat.team = out
    team_save()
end

function tchat.team_clear()
    tchat.team = {}
    team_save()
end

function tchat.team_set(player_list)
    tchat.team = player_list
    team_save()
end


---
-- callbacks

minetest.register_on_sending_chat_message(function(message)
    if tchat.contains_coords(message) then
        minetest.display_chat_message("Message contained coordinates, be careful.")
        return true
    end

    team_mode = minetest.settings:get_bool("tchat_team_mode")

    if not team_mode then
        return
    end

    tchat.send(message)
    return true
end)


local function message_sent(message)
    return message == "Message sent."
end

local function clean_message(message)
    -- dirty, strips out legitimate uses of the prefix
    message = message:gsub(message_prefix, "")
    message = message:gsub("^" .. message_receive, "")
    message = message:gsub("^" .. message_receive_self, minetest.localplayer:get_name())

    message = message:gsub(":  ", ": ")
    message = message:match("^%s*(.-)%s*$")

    return message
end

-- greedily be the first in the receiving list (prob doesnt always work)
table.insert(minetest.registered_on_receiving_chat_message, 1, function(message)
    if hide_sent and message_sent(message) then
        return true
    end

    -- bit dirty, doesnt check the prefix position
    if not message:find(message_prefix) then
        return
    end

    local player = message:match(message_receive .. " (.+): " .. message_prefix)

    local from_self = message:sub(1, message_receive_self:len()) == message_receive_self
    local received = message:sub(1, message_receive:len()) == message_receive
    local sent = message:sub(1, message_to:len()) == message_to

    if sent and not from_self then
        return true
    end

    if not from_self and not in_list(tchat.team_online, player) then
        return
    end

    -- add to chat list
    if from_self or received then
        tchat.chat_append(clean_message(message))
        return true
    end
end)

if wisp ~= nil then
    wisp.register_on_receive_split(function(player, message)
        if message:find(message_prefix) then
            tchat.chat_append("E " .. player .. ": " .. clean_message(message))
            return true
        end
    end)
end

minetest.register_globalstep(function()
    -- update data
    if player_list_epoch < os.time() + 2 then
        -- update players, remove duplicates
        tchat.players = minetest.get_player_names()
        table.sort(tchat.players)
        tchat.players = uniq(tchat.players)

        update_team_online()

        -- update HUD
        auto_update(player_list_idx, "Players\n\n" .. table.concat(tchat.players, "\n"))
        auto_update(team_list_idx, "Team\n\n" .. get_team_str())

        player_list_epoch = os.time()
    end

    -- display (if we need to)
    if minetest.localplayer then
        chat_idx = auto_display(chat_idx, "tchat_view_chat", display_chat)
        player_list_idx = auto_display(player_list_idx, "tchat_view_player_list", display_player_list)
        team_list_idx = auto_display(team_list_idx, "tchat_view_team_list", display_team_list)
    end
end)


---
-- command/cheat interface

minetest.register_chatcommand("t", {
    params = "<message>",
    description = "Send a message to your team chat, or regular chat if team mode is on.",
    func = function(message)
        if tchat.contains_coords(message) then
            minetest.display_chat_message("Message contained coordinates, be careful.")
            return
        end
        tchat.send_conditional(message, true)
    end
})
minetest.register_chatcommand("tcoords", {
    params = "<message>",
    description = "Send a message containing coordinates to teamchat.",
    func = function(message)
        tchat.send(message, true)
    end
})
minetest.register_chatcommand("tlist", {
    description = "List your team.",
    func = function(param)
        minetest.display_chat_message(table.concat(tchat.team, ", "))
    end
})
minetest.register_chatcommand("tadd", {
    params = "<player>",
    description = "Add player to your team.",
    func = tchat.team_add_player
})
minetest.register_chatcommand("tdel", {
    params = "<player>",
    description = "Remove player from your team.",
    func = tchat.team_remove_player
})
minetest.register_chatcommand("tclear", {
    description = "Clear team list.",
    func = tchat.team_clear
})

minetest.register_chatcommand("tchat_clear", {
    description = "Clear team chat widget.",
    func = tchat.chat_clear
})

minetest.register_chatcommand("coords", {
    params = "<message>",
    description = "Send message containing coordinates.",
    func = tchat.send_coords
})
minetest.register_chatcommand("mcoord", {
    params = "<player>",
    description = "Whisper current coordinates to player.",
    func = tchat.whisper_coords
})


-- this fallbacks to showing everything if the cheat menu is unavailable
-- use advanced settings instead :]
if (_G["minetest"]["register_cheat"] == nil) then
    minetest.settings:set_bool('tchat_team_mode', true)
    minetest.settings:set_bool('tchat_view_team_list', true)
    minetest.settings:set_bool('tchat_view_player_list', true)
    minetest.settings:set_bool('tchat_view_chat', true)
else
    minetest.register_cheat("Teamchat Mode", "Chat", "tchat_team_mode")
    minetest.register_cheat("Show Team List", "Chat", "tchat_view_team_list")
    minetest.register_cheat("Show Player List", "Chat", "tchat_view_player_list")
    minetest.register_cheat("Show Teamchat", "Chat", "tchat_view_chat")
end
