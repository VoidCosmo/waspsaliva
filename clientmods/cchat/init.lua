--
-- coras Chat hacks
-- * verify death messages
-- * log chat to stdout

cchat = {}

-- verify death
table.insert(minetest.registered_on_receiving_chat_message, 1, function(msg)
    local d = msg:find('\1b@mcl_death_messages\1b') --mineclone specific
    if d then
       -- minetest.send_chat_message("real.") --uncomment to publish approval
        minetest.display_chat_message("real.")
    end

end)


-- chat logging
local mod_name = minetest.get_current_modname()

local function log(level, message)
    minetest.log(level, ('[%s] %s'):format(mod_name, message))
end

log('action', 'Chatlog loading...')

local LOG_LEVEL = 'action'

local server_info = minetest.get_server_info()
local server_id = server_info.address .. ':' .. server_info.port
local my_name = ''

local register_on_send = minetest.register_on_sending_chat_message or minetest.register_on_sending_chat_messages
local register_on_receive = minetest.register_on_receiving_chat_message or minetest.register_on_receiving_chat_messages


local function safe(func)
    -- wrap a function w/ logic to avoid crashing the game
    local f = function(...)
        local status, out = pcall(func, ...)
        if status then
            return out
        else
            log('warning', 'Error (func):  ' .. out)
            return nil
        end
    end
    return f
end

local set_my_name_tries = 0
local function set_my_name()
    if minetest.localplayer then
        my_name = minetest.localplayer:get_name()
    elseif set_my_name_tries < 20 then
        set_my_name_tries = set_my_name_tries + 1
        minetest.after(1, set_my_name)
    else
        my_name = ''
    end
end



local function loglastlogs()
    if not fren then return end
    for k,v in pairs(fren.friends) do
        if fren.on_server(fren.name_of(k)) then
            log("LASTLOGLOG START")
            --minetest.display_chat_message('Last login of friend ' .. fren.name_of(k))
            log("Last login of friend "..fren.name_of(k))
            minetest.send_chat_message("/last-login "..fren.name_of(k))
        end
    end
    for k,v in pairs(fren.enemies) do
        if fren.on_server(fren.name_of(k)) then
            log("Last login of enemy "..fren.name_of(k))
            --minetest.display_chat_message('Last login of friend ' .. fren.name_of(k))
            minetest.send_chat_message("/last-login "..fren.name_of(k))
            minetest.after("5.0",function() log("LASTLOGLOG END") end)
        end
    end
end

--minetest.after("5.0",function() loglastlogs() end)

if minetest.register_on_connect then
    minetest.register_on_connect(set_my_name)
elseif minetest.register_on_mods_loaded then
    minetest.register_on_mods_loaded(set_my_name)
else
    minetest.after(1, set_my_name)
end


if register_on_send then
    register_on_send(safe(function(message)
        local msg = minetest.strip_colors(message)
        if msg ~= '' then
            log(LOG_LEVEL, ('%s@%s [sent] %s'):format(my_name, server_id, msg))
        end
    end))
end

if register_on_receive then
    register_on_receive(safe(function(message)
        local msg = minetest.strip_colors(message)
        if msg ~= '' then
            log(LOG_LEVEL, ('%s@%s %s'):format(my_name, server_id, msg))
        end
    end))
end
