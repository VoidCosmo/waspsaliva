-- CC0/Unlicense system32 2020

--[[
Commands:

.qb_add_commander player
.qb_list_commanders
.qb_del_commander player

.qb_set ID quote
.qb_list

.qb_say <ID>
.qb_direct player <ID>

.qb_chance num/player <num>

.qb_enable
.qb_disable

-- requires unsafe
.qb_export file
.qb_import file
--]]


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


quotebot = {}
quotebot.quotes = storage_init_table("quotebot_quotes")
quotebot.chance = tonumber(storage:get_string("quotebot_chance")) or 0
quotebot.chances = storage_init_table("quotebot_chances")
quotebot.commanders = storage_init_table("quotebot_commanders")
quotebot.enabled = false

function quotebot.save()
    storage_save_json("quotebot_quotes", quotebot.quotes)
    storage:set_string("quotebot_chance", tostring(quotebot.chance))
    storage_save_json("quotebot_chances", quotebot.chances)
    storage_save_json("quotebot_commanders", quotebot.commanders)
    storage:set_bool("quotebot_enabled", quotebot.enabled)
end


local function localize_player(player)
    if player == nil then
        return nil
    end

    local info = minetest.get_server_info()

    local name = info.ip
    if info.address ~= "" then
        name = info.address
    end

    return player .. "@" .. info.ip .. ":" .. info.port
end


local function say(id, prefix)
    if quotebot.enabled then
        minetest.send_chat_message((prefix or "") .. quotebot.quotes[id])
    end
end

local function index_table(t, ti)
    local i = 1
    for k, v in pairs(t) do
        if i == ti then
            return k, v
        end
        i = i + 1
    end
end

local function in_list(list, value)
    for i, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

local function table_size(t)
    local n = 0
    for k, v in pairs(t) do
        n = n + 1
    end
    return n
end

local function rand_say(trigger, id, prefix)
    id = id or index_table(quotebot.quotes, math.random(table_size(quotebot.quotes)))

    if trigger.type == "message" or trigger.type == "api" then
        local chance = quotebot.chances[trigger.player] or quotebot.chance

        if math.random() <= chance then
            say(id, prefix)
        end
    elseif trigger.type == "command" or trigger.type == "api_command" then
        say(id, prefix)
    elseif trigger.type == "dm" and trigger.content == "say" and in_list(trigger.player, quotebot.commanders) then
        say(id, prefix)
    end
end

function quotebot.force_say(id, prefix)
    rand_say({
        type = "api_command",
        player = "",
        content = ""
    }, id, prefix)
end

function quotebot.say(id, prefix)
    rand_say({
        type = "api",
        player = "",
        content = ""
    }, id, prefix)
end


minetest.register_on_mods_loaded(function()
    math.randomseed(os.time())
end)


minetest.register_on_receiving_chat_message(function(message)
    local dm_player, dm_content = message:match(".*rom (.-): (.*)")
    local message_player, message_content= message:match("<(.-)> (.*)")

    local mtype = "message"
    local player = localize_player(message_player)
    local content = message_content

    if dm_player then
        mtype = "dm"
        player = localize_player(dm_player)
        content = dm_content
    end

    rand_say({
        type = mtype,
        player = player,
        content = content
    })
end)


local function set_append(set, value)
    if not in_list(set, value) then
        set[#set + 1] = value
    end
end

local function list_remove(list, value)
    local out = {}
    for i, v in ipairs(list) do
        if v ~= value then
            out[#out] = value
        end
    end
    return out
end


local function noplayer()
    minetest.display_chat_message("No player specified.")
end

local function parse_player(params)
    local player = string.split(params, " ")[1]
    if player == nil then
        noplayer()
        return
    end
    return player
end

local function get_keys(t)
    local out = {}
    for k, v in pairs(t) do
        out[#out + 1] = k
    end
    return out
end


minetest.register_chatcommand("qb_add_commander", {
    params = "<player>",
    description = "Add a user who can DM 'say' to the bot to force it to say a random quote.",
    func = function(params)
        local player = parse_player(params)
        if player then
            set_append(quotebot.commanders, player)

            quotebot.save()
        end
    end
})
minetest.register_chatcommand("qb_list_commanders", {
    description = "List users who can force the bot to say a random quote.",
    func = function(params)
        minetest.display_chat_message(table.concat(quotebot.commanders, ", "))
    end
})
minetest.register_chatcommand("qb_del_commander", {
    params = "<player>",
    description = "Remove a commander.",
    func = function(params)
        local player = parse_player(params)
        if player then
            list_remove(quotebot.commanders, player)

            quotebot.save()
        end
    end
})

minetest.register_chatcommand("qb_set", {
    params = "<id> <quote>",
    description = "Set a quote ID to a value, omit quote to remove the quote.",
    func = function(params)
        local id, quote = params:match("(.-) (.*)")
        if id == "" then
            minetest.display_chat_message("ID not specified.")
            return
        end
        
        if quote == "" then
            quote = nil
        end

        quotebot.quotes[id] = quote

        quotebot.save()
    end
})
minetest.register_chatcommand("qb_list", {
    description = "List quote IDs.",
    func = function(params)
        minetest.display_chat_message(table.concat(get_keys(quotebot.quotes), ", "))
    end
})
minetest.register_chatcommand("qb_show", {
    params = "<ID>",
    description = "Show a quote",
    func = function(params)
        minetest.display_chat_message(quotebot.quotes[params] or "No quote with specified ID.")
    end
})


minetest.register_chatcommand("qb_say", {
    params = "<ID>",
    description = "Say a random quote (or specific if ID is specified).",
    func = function(params)
        if params ~= "" then
            rand_say({
                type = "command",
                player = "",
                content = ""
            }, params)
        else
            rand_say({
                type = "command",
                player = "",
                content = ""
            })
        end
    end
})
minetest.register_chatcommand("qb_direct", {
    params = "<player> <ID>",
    description = "Say a random quote (or specific if ID is specified) directed towards a player.",
    func = function(params)
        local player = parse_player(params)

        if player then
            if params ~= "" then
                rand_say({
                    type = "command",
                    player = "",
                    content = ""
                }, params, player .. ": ")
            else
                rand_say({
                    type = "command",
                    player = "",
                    content = ""
                }, nil, player .. ": ")
            end
        end
    end
})

minetest.register_chatcommand("qb_chance", {
    params = "<num/player> <num>",
    description = "Set the say chance to number (0.percentage). If first is num, set global chance. If first is player and second is num then set player's chance. If first is player and second num is not set, clear player chance.",
    func = function(params)
        local plist = string.split(params, " ")

        local first_num = tonumber(plist[1] or "")
        local player = plist[1]
        local second_num = tonumber(plist[2] or "")

        if first_num then
            quotebot.chance = first_num
        elseif player then
            quotebot.chances[player] = second_num
        end

        quotebot.save()
    end
})

minetest.register_chatcommand("qb_enable", {
    description = "Enable the quotebot.",
    func = function(params)
        quotebot.enable = true
        quotebot.save()
    end
})
minetest.register_chatcommand("qb_disable", {
    description = "Disable the quotebot.",
    func = function(params)
        quotebot.enable = false
        quotebot.save()
    end
})


if minetest.settings:get_bool("quotebot_export") then
    if minetest.request_insecure_environment == nil then
        error("Request insecure environment not accessible. Apply patches or disable quotebot_export.")
    end

    local env = minetest.request_insecure_environment()

    if env == nil then
        error("Could not get an insecure environment, is quotebot in trusted mods?")
    end

    function quotebot.export(file)
        fdesc = io.open(file, "w")
        fdesc:write(minetest.write_json({
            quotes = quotebot.quotes,
            chance = quotebot.chance,
            chances = quotebot.chances,
            commanders = quotebot.commanders,
            enabled = quotebot.enabled
        }))
        fdesc:close()
    end

    function quotebot.import(file)
        fdesc = io.open(file, "r")
        local t = minetest.parse_json(fdesc:read("*all")) or {}
        fdesc:close()
        quotebot.quotes = t.quotes or {}
        quotebot.chance = t.chance or 0
        quotebot.chances = t.chances or {}
        quotebot.commanders = t.commanders or {}
        quotebot.enabled = t.enabled or false
        quotebot.save()
    end

    minetest.register_chatcommand("qb_export", {
        params = "<file>",
        description = "Export quote setup to a file.",
        func = function(params)
            quotebot.export(params)
        end
    })
    minetest.register_chatcommand("qb_import", {
        params = "<file>",
        description = "Import quote setup from a file.",
        func = function(params)
            quotebot.import(params)
        end
    })
end
