fren = {}
frenemies = fren

fren.friends = {}
fren.friend_color = "#00FF00"

fren.enemies = {}
fren.enemy_color = "#FF0000"

fren.neutral_color = "#FFFFFF"

fren.groups = {}


--[[

storage:
player is {level = n, color = ""}
group is {name = "", level = n, color = "", members = {"", ""}}

available:
player is {level = n, color = "", groups = {"", ""}}
group is {name = "", level = n, color = "", members = {"", ""}}

qualify(player)
name_of(qualified)

is_enemy(player)
is_friend(player)
is_current_player(player)
is_neutral(player)

player_color(player)
player_groups(player)
player_level(player)

get_online_players()
get_online_friends()
get_online_enemies()
get_online_neutrals()
get_online_group(group)

if a player name contains @ it is a fully qualified name


.friend and .enemy should support level

.friend player <color>  -- make player friend or recolor them
.fr player
.unfriend player
.unfr player

.enemy player <color>   -- make player enemy or recolor them
.en player
.unenemy player
.unen player

.group name <color>     -- create or recolor group
.rm_group name
.gadd group player
.grm group player

.lfriends
.lenemies
.lgroup group

.lfriends_all
.lenemies_all
.lgroup_all group

maybe groups should be qualified per server?
--]]


local storage = minetest.get_mod_storage()

-- should remove groups
function fren.serialize()
    return minetest.write_json({
        friends = fren.friends,
        friend_color = fren.friend_color,
        enemies = fren.enemies,
        enemy_color = fren.enemy_color,
        neutral_color = fren.neutral_color,
        groups = fren.groups
    })
end

-- should relate groups
function fren.deserialize(str)
    local des = minetest.parse_json(str)
    if des then
        fren.friends = des.friends or {}
        fren.friend_color = des.friend_color
        fren.enemies = des.enemies or {}
        fren.enemy_color = des.enemy_color
        fren.neutral_color = des.neutral_color
        fren.groups = des.groups or {}
    end
end

function fren.store()
    storage:set_string("data", fren.serialize())
end

function fren.load()
    local d = storage:get("data")
    if d then
        fren.deserialize(d)
    end
end

fren.load()

local server_info = minetest.get_server_info()

function fren.qualify(player)
    local name = server_info.ip

    if server_info.address ~= "" then
        name = server_info.address
    end

    return player .. "@" .. name .. ":" .. server_info.port
end

function fren.name_of(qualified)
    return qualified:match("(.-)@")
end

function fren.on_server(name)
    local qname=fren.qualify(name)
    for k,v in pairs(fren.friends) do
        if k == qname then return true end
    end
    for k,v in pairs(fren.enemies) do
        if k == qname then return true end
    end
    return false
end


-- player required, color/level optional
function fren.friend(player, color, level)
    local n = fren.qualify(player)

    fren.friends[n] = {placeholder = true} -- true because the way Minetest serializes Json replaces {} with null
    fren.friends[n].color = color
    fren.friends[n].level = level

    fren.store()
end

function fren.unfriend(player)
    fren.friends[fren.qualify(player)] = nil

    fren.store()
end

function fren.enemy(player, color, level)
    local n = fren.qualify(player)

    fren.enemies[n] = {placeholder = true}
    fren.enemies[n].color = color
    fren.enemies[n].level = level

    fren.store()
end

function fren.unenemy(player)
    fren.enemies[fren.qualify(player)] = nil

    fren.store()
end


function fren.group(name, color, level)
    fren.groups[name] = {placeholder = true}
    fren.groups[name].color = color
    fren.groups[name].level = level

    fren.store()
end

function fren.remove_group(name)
    fren.groups[name] = nil

    fren.store()
end

function fren.group_add_player(group, player, level)
    if fren.groups[group] then
        local q = fren.qualify(player)
        fren.groups[group].members[q] = {placeholder = true}
        fren.groups[group].members[q].level = level

        fren.store()
    end
end

function fren.group_remove_player(group, player)
    if fren.groups[group] then
        fren.groups[group].members[fren.qualify(player)] = nil

        fren.store()
    end
end


function fren.is_enemy(player)
    return fren.enemies[fren.qualify(player)] ~= nil
end

function fren.is_friend(player)
    return fren.friends[fren.qualify(player)] ~= nil
end

function fren.is_neutral(player)
    return not fren.is_enemy(player) and not fren.is_friend(player)
end

function fren.is_current_player(player)
    return player == minetest.locaplayer:get_name()
end

function fren.in_group(player, group)
    if fren.groups[group] then
        return fren.groups[group].members[fren.qualify(player)] ~= nil
    end
end

-- maybe groups should be involved?
function fren.color(player)
    local q = fren.qualify(player)

    if fren.is_friend(player) then
        return fren.friends[q].color or fren.friend_color
    elseif fren.is_enemy(player) then
        return fren.enemies[q].color or fren.enemy_color
    else
        return friend.neutral_color
    end
end


-- should be a setting
local check_interval = 1

local online_cached = {}
local online_cached_last = 0

local friend_online_cached = {}
local friend_online_cached_last = 0

local enemy_online_cached = {}
local enemy_online_cached_last = 0

local neutral_online_cached = {}
local neutral_online_cached_last = 0

local group_online_cached = {}
local group_online_cached_last = {}

local function is_time(epoch)
    if epoch == nil then
        return true
    end

    return os.clock() - epoch >= check_interval
end

local function uniq(l)
    local o = {}
    local oi = 1
    local last

    for i, v in ipairs(l) do
        if last ~= v then
            o[oi] = v
            oi = oi + 1
        end

        last = v
    end

    return o
end

function fren.get_online_players()
    if is_time(online_cached_last) then
        online_cached_last = os.clock()

        online_cached = minetest.get_player_names()
        table.sort(online_cached)
        online_cached = uniq(online_cached)
    end

    return online_cached
end

local function filter(filter, source)
    local o = {}

    for k, v in pairs(source) do
        if filter(v) then
            o[k] = v
        end
    end

    return o
end

function fren.get_online_friends()
    if is_time(friend_online_cached_last) then
        friend_online_cached_last = os.clock()

        friend_online_cached = filter(fren.is_friend, fren.get_online_players())
    end

    return friend_online_cached
end

function fren.get_all_friends()
    if is_time(friend_online_cached_last) then
        friend_online_cached_last = os.clock()

        friend_online_cached = filter(fren.is_friend, fren.get_online_players())
    end

    return friend_online_cached
end

function fren.get_online_enemies()
    if is_time(enemy_online_cached_last) then
        enemy_online_cached_last = os.clock()

        enemy_online_cached = filter(fren.is_enemy, fren.get_online_players())
    end

    return enemy_online_cached
end

function fren.get_online_neutrals()
    if is_time(neutral_online_cached_last) then
        neutral_online_cached_last = os.clock()

        neutral_online_cached = filter(fren.is_neutral, fren.get_online_players())
    end

    return neutral_online_cached
end

function fren.get_online_group(group)
    if is_time(group_online_cached_last[group]) then
        group_online_cached_last[group] = os.clock()

        group_online_cached[group] = filter(
            function(v)
                return fren.in_group(v, group)
            end, fren.get_online_players())
    end

    return group_online_cached[group]
end


-- first second [opt_third]
-- converts to
-- {
--  [1] = {name = "first", required = true},
--  [2] = {name = "second", required = true},
--  [3] = {name = "opt_third", required = false}
-- }
local function parse_opts(str)
    local o = {}
    local opts = string.split(str, " ")

    for i, v in ipairs(opts) do
        if v:match("%[(.-)%]") then
            o[i] = {name = v, required = false}
        else
            o[i] = {name = v, required = true}
        end
    end

    return o
end

-- first second [opt_third]
-- returns {first = a, second = a, opt_third = a/nil} or nil if parsing failed
local function parse_args(str, args)
    local opts = parse_opts(str)
    local splargs = string.split(args, " ")
    local parsed = {}

    for i, v in ipairs(opts) do
        if splargs[i] then
            parsed[v.name] = splargs[i]
        elseif v.required then
            minetest.display_chat_message("Error: argument '" .. v.name .. "' is required.")
            return nil
        else
            break
        end
    end

    return parsed
end


minetest.register_chatcommand("friend", {
    description = "Add a player as a friend.",
    params = "<player> <?color>",
    func = function(params)
        local args = parse_args("player [color]", params)
        if args then
            fren.friend(args.player, args.color)
        end
    end
})

minetest.register_chatcommand("unfriend", {
    description = "Remove player from friend list.",
    params = "<player>",
    func = function(params)
        local args = parse_args("player", params)
        if args then
            fren.unfriend(args.player)
        end
    end
})

minetest.register_chatcommand("enemy", {
    description = "Add player as an enemy.",
    params = "<player> <?color>",
    func = function(params)
        local args = parse_args("player [color]", params)
        if args then
            fren.enemy(args.player, args.color)
        end
    end
})

minetest.register_chatcommand("unenemy", {
    description = "Remove player from enemy list.",
    params = "<player>",
    func = function(params)
        local args = parse_args("player", params)
        if args then
            fren.unenemy(args.player)
        end
    end
})


local function lcat(l)
    return table.concat(l, ", ")
end

local function displist(l)
    minetest.display_chat_message(lcat(l))
end


minetest.register_chatcommand("lfriends", {
    description = "List online friends.",
    func = function()
        displist(fren.get_online_friends())
    end
})

minetest.register_chatcommand("lenemies", {
    description = "List online enemies.",
    func = function()
        displist(fren.get_online_enemies())
    end
})

minetest.register_chatcommand("lgroup", {
    description = "List online members of a group.",
    params = "<group>",
    func = function(params)
        local args = parse_args("group", params)
        if args then
            displist(fren.get_online_group(args.group))
        end
    end
})
