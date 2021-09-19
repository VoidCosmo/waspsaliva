-- Wisp by system32
-- CC0/Unlicense 2020
-- version 1.0
--
-- a clientmod for minetest that lets people send 1 on 1 encrypted messages
-- also has a public interface for other mods
--
-- check out cora's tchat mod, which supports using wisp as a backend

-- uses the lua-openssl library by George Zhao: https://github.com/zhaozg/lua-openssl

-- public interface
--
-- Methods
-- send(player, message) - send a message
-- register_on_receive(function(message)) - register a receiving callback (includes To: messages), if it returns true the message will not be shown to the player
-- register_on_receive_split(function(player, message)) - register_on_receive but player and message are pre split
-- register_on_send_split(function(player, message)) - register a sending callback, if it returns true the message will not be sent
--
-- Properties
-- players - list of online players (updated every 2 seconds , when someone may have left, and when a message is queued)

-- minetest mod security doesn't work so require() is still disabled while modsec is off
-- so this doesnt work without patches (it should tho :])

-- PATCHING MINETEST
--
-- in src/script/lua_api/l_util.cpp add the following to ModApiUtil:InitializeClient() below API_FCT(decompress);
--[[
    API_FCT(request_insecure_environment);
--]]
--
-- in src/script/cpp_api/s_security.cpp add the following below int thread = getThread(L); in ScriptApiSecurity:initializeSecurityClient()
--[[
    // Backup globals to the registry
    lua_getglobal(L, "_G");
    lua_rawseti(L, LUA_REGISTRYINDEX, CUSTOM_RIDX_GLOBALS_BACKUP);
--]]
--
-- Recompile Minetest (just using make -j$(nproc) is fine)

-- INSTALLING OPENSSL
--
-- Git clone, make, make install (git repo is https://github.com/zhaozg/lua-openssl)
-- # mkdir /usr/lib/lua/5.1
-- # mv /usr/lib/lua/openssl.so /usr/lib/lua/5.1

-- ADDING TO TRUSTED
--
-- add wisp to the trusted mods setting in Minetest

--[[ protocol:
on joining a game, generate a keypair for ECDH

medium is minetest private messages for all conversation

alice and bob dont know each other
alice introduces herself, giving her ECDH public component to bob (using PEM)
bob generates the secret and gives alice his public component
alice generates the same secret

then at any point alice or bob can talk to the other (for eg, alice talks)
alice generates a 256 bit nonce and encrypts her message using AES 256 CBC with the nonce as the initialization vector, sending the nonce and message to bob (both base64 encoded and separated by a space character)
bob decrypts her message using AES 256 CBC with the nonce as the initialization vector
you can swap alice with bob and vice versa to get what will happen if bob messages alice

the key exchanging step is performed whenever alice or bob don't have the other's key
the encryption step is performed every time a private encrypted message is sent

if a player leaves all players with their public key and other data will forget them, it is important to do this since the keys for a player are not persistent across joining/leaving servers
if this was not done alice may use a stale key for bob or vice versa, giving an incorrect shared secret
this is not damaging to security, it just wouldn't let them talk
--]]


if minetest.request_insecure_environment == nil then
    error("Wisp: Minetest scripting patches were not applied, please apply them and recompile Minetest.")
end

local env = minetest.request_insecure_environment()
if env == nil then
    error("Wisp: not in trusted mods (secure.trusted_mods), please go into the advanced settings and add wisp (all lowercase).")
end

local openssl = env.require("openssl")


-- private stuff

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
    wisp_prefix = "&**&",
    wisp_curve = "prime256v1",
    wisp_cipher = "aes256",
    wisp_digest = "sha256",
    wisp_iv_size = 8,
    wisp_whisper = "msg",
    wisp_hide_sent = true,
    wisp_timeout = 10
})

-- players must agree on these
local prefix = minetest.settings:get("wisp_prefix")
local curve = minetest.settings:get("wisp_curve")
local cipher = minetest.settings:get("wisp_cipher")
local digest = minetest.settings:get("wisp_digest")

local iv_size = minetest.settings:get("wisp_iv_size")
local whisper = minetest.settings:get("wisp_whisper")
local hide_sent = minetest.settings:get_bool("wisp_hide_sent")

local timeout = tonumber(minetest.settings:get("wisp_timeout"))

local my_key = openssl.pkey.new("ec", curve)
local my_ec = my_key:parse().ec
local my_export = my_key:get_public():export()

local pem_begin = "-----BEGIN PUBLIC KEY-----\n"
local pem_end = "\n-----END PUBLIC KEY-----\n"

my_export = my_export:sub(pem_begin:len() + 1, -pem_end:len() - 1):gsub("\n", "~")

local friends = {}


-- convenience aliases
local function qsplit(message)
    return string.split(message, " ")
end

local function b64_decode(message)
    return minetest.decode_base64(message)
end

local function b64_encode(message)
    return minetest.encode_base64(message)
end

local function in_list(list, value)
    for k, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

local function append(list, item)
    list[#list + 1] = item
end

local function popfirst(t)
    local out = {}

    for i = 2, #t do
        out[#out + 1] = t[i]
    end

    return out
end

local function unpack(t, i)
    if type(t) ~= "table" then
        return t
    end

    i = i or 1
    if t[i] ~= nil  then
        return t[i], unpack(t, i + 1)
    end
end


-- key trading

local function dm(player, message)
    minetest.send_chat_message("/" .. whisper .. " " .. player .. " " .. message)
end

-- initialize
local function establish(player)
    dm(player, prefix .. "I " .. my_export)
end

-- receiving
local function establish_receive(player, message, sendout)
    friends[player] = {}
    local friend = friends[player]

    local key = pem_begin .. message:gsub("~", "\n") .. pem_end

    friend.pubkey = openssl.pkey.read(key)

    friend.secret = my_ec:compute_key(friend.pubkey:parse().ec)
    friend.key = openssl.digest.digest(digest, friend.secret, true)

    if sendout == true then
        dm(player, prefix .. "R " .. my_export)
    end
end


-- encryption

local function run_callbacks(list, params)
    for k, v in ipairs(list) do
        if v(unpack(params)) then
            return true
        end
    end
end

-- encrypt and send
local function message_send(player, message, hide_to, force_send)
    local me = minetest.localplayer:get_name()

    if run_callbacks(wisp.send_split_callbacks, {player, message}) then
        return
    end

    -- for displaying the To: stuff
    if not hide_to then
        local target = player
        if target == me then
            target = "Yourself"
        end
        local display_message = "To " .. target .. ": " .. message

        local callback_value = run_callbacks(wisp.receive_callbacks, display_message)
        callback_value = callback_value or run_callbacks(wisp.receive_split_callbacks, {player, message})

        if not callback_value then
            minetest.display_chat_message(display_message)
        end
    end

    -- actual encryption
    local friend = friends[player]
    if friend == nil then
        return
    end

    local nonce = openssl.random(iv_size, true)
    local enc_message = openssl.cipher.encrypt(cipher, message, friend.key, nonce)
    local final_message = b64_encode(nonce) .. " " .. b64_encode(enc_message)

    if player ~= me or force_send then
        dm(player, prefix .. "E " .. final_message)
    end
end

-- decrypt and show
local function message_receive(player, message)
    local friend = friends[player]
    if friend == nil then
        return
    end

    local nonce = b64_decode(qsplit(message)[1])
    local enc_message = b64_decode(qsplit(message)[2])
    local dec_message = openssl.cipher.decrypt(cipher, enc_message, friend.key, nonce)
    final_message = "From " .. player .. ": " .. dec_message

    local callback_value = run_callbacks(wisp.receive_callbacks, final_message)
    callback_value = callback_value or run_callbacks(wisp.receive_split_callbacks, {player, dec_message})

    if not callback_value then
        minetest.display_chat_message(final_message)
    end
end


-- check if a player actually left
local function player_left(message)
    for player in message:gmatch("[^ ]* (.+) left the game.") do
        wisp.players = minetest.get_player_names()
        for k, v in ipairs(wisp.players) do
            if v == player then
                return player
            end
        end
    end
end

-- check if a message is a PM
local function pm(message)
    for player, message in message:gmatch(".*rom (.+): (.*)") do
        return player, message
    end

    return nil, nil
end

-- check if a message is encrypted
local function encrypted(message)
    local split = string.split(message, " ")

    if split[1] == prefix then
        return string.sub(message, string.len(prefix) + 2)
    end
end

-- check if a message is 'Message sent.' or similar
local function message_sent(message)
    return message == "Message sent."
end



wisp = {}
wisp.receive_callbacks = {}
wisp.receive_split_callbacks = {}
wisp.send_split_callbacks = {}
wisp.players = {}


local player_check_epoch = 0

-- message queue, accounts for establishing taking non-zero time
-- messages are enqueued and dequeued once they can be sent
local queue = {}

local function enqueue(player, message, hide_to, force_send)
    append(queue, {
        player = player,
        message = message,
        hide_to = hide_to,
        force_send = force_send,
        time = os.time()
    })
    wisp.players = minetest.get_player_names()
end

local function dequeue()
    local new_queue = {}
    local out = queue[1]
    for k, v in ipairs(queue) do
        if k ~= 1 then
            append(new_queue, v)
        end
    end
    queue = new_queue
    return out
end

local function peek()
    return queue[1]
end


function wisp.send(player, message, hide_to, force_send)
    if (player ~= minetest.localplayer:get_name() or force_send) and friends[player] == nil then
        establish(player)
    end
    enqueue(player, message, hide_to, force_send)
end

function wisp.register_on_receive(func)
    append(wisp.receive_callbacks, func)
end

function wisp.register_on_receive_split(func)
    append(wisp.receive_split_callbacks, func)
end

function wisp.register_on_send_split(func)
    append(wisp.send_split_callbacks, func)
end


-- glue

minetest.register_on_receiving_chat_message(
    function(message)
        -- hide Message sent.
        if hide_sent and message_sent(message) then
            return true
        end

        -- if its a PM
        local player, msg = pm(message)
        if player and msg then

            local split = qsplit(msg)
            local plain = table.concat(popfirst(split), " ")

            -- initial key trade
            if split[1] == prefix .. "I" then
                establish_receive(player, plain, true)
                return true
            -- key trade response
            elseif split[1] == prefix .. "R" then
                establish_receive(player, plain)
                return true
            -- encrypted message receive
            elseif split[1] == prefix .. "E" then -- encrypt
                message_receive(player, plain)
                return true
            end
        end

        -- remove friends if they leave
        local player = player_left(message)
        if player then
            friends[player] = nil
        end
    end
)


minetest.register_globalstep(
    function()
        if os.time() > player_check_epoch + 2 then
            wisp.players = minetest.get_player_names()
        end

        local p = peek()
        if p then
            if not in_list(wisp.players, peek().player) then
                minetest.display_chat_message("Player " .. p.player .. " is not online. If they are please resend the message.")
                dequeue()
                return
            end

            if os.time() > p.time + timeout then
                minetest.display_chat_message("Player " .. p.player .. " is not responsive.")
                dequeue()
                return
            end

            if (p.player == minetest.localplayer:get_name() and not p.force_send) or friends[p.player] then
                local v = dequeue()
                message_send(v.player, v.message, v.hide_to, v.force_send)
            end
        end
    end
)


minetest.register_chatcommand("e", {
    params = "<player>",
    description = "Send encrypted whisper to player",
    func = function(param)
        local player = qsplit(param)[1]
        local message = table.concat(popfirst(qsplit(param)), " ")
        if player == nil then
            minetest.display_chat_message("Player not specified.")
            return
        end
        wisp.send(player, message)
    end
})
