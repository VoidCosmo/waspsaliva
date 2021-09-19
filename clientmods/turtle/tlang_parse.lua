-- CC0/Unlicense Emilia 2020

-- parse types
--[[
quote
identifier
code
map
string
number
symbol
--]]

local tlang = ...

local internal = {}

local function sublist(list, istart, iend, inclusive)
    local o = {}
    local oi = 1

    inclusive = inclusive or false

    for i, v in ipairs(list) do
        iend = iend or 0 -- idk how but iend can become nil

        local uninc = i > istart and i < iend
        local incl = i >= istart and i <= iend

        if (inclusive and incl) or (not inclusive and uninc) then
            o[oi] = v
            oi = oi + 1
        end
    end

    return o
end


local function parse_peek(state)
    return state.lexed[state.position]
end

local function parse_next(state)
    local n = parse_peek(state)
    state.position = state.position + 1
    return n
end

local function parse_identifier(state)
    local lexid = parse_next(state).value

    for i, v in ipairs(lexid) do
        if v:match("^[0-9]+$") then
            lexid[i] = tonumber(v)
        end
    end

    return {type = "identifier", value = lexid}
end

local function parse_map(state)
    local map = {}
    local mapi = 1

    if parse_next(state).type ~= "map_open" then
        return nil -- ERROR
    end

    while true do
        local n = parse_next(state)
        local skip = false -- lua has no continue, 5.1 has no goto

        if n == nil then
            return nil -- ERROR
        end

        if n.type == "map_close" then
            break
        elseif n.type == "literal" and (n.subtype == "identifier" or n.subtype == "string") then
            local key = n.value
            local mr = parse_peek(state)

            if type(key) == "table" then
                key = key[1]
            end

            if mr.type == "map_relation" then
                parse_next(state)
                local nval = internal.parse_step(state)

                if nval == nil then
                    return nil -- ERROR
                end

                map[key] = nval
                skip = true
            end
        end

        if not skip then
            local nval = tlang.parse({n})

            if nval == nil then
                return nil -- ERROR
            end

            map[mapi] = nval[1]
            mapi = mapi + 1
        end
    end

    return {type = "map", value = map}
end

local function parse_find_matching(state, open, close)
    local level = 1

    parse_next(state) -- skip beginning

    while level ~= 0 do
        local n = parse_next(state)
        if n == nil then
            return nil -- ERROR
        elseif n.type == open then
            level = level + 1
        elseif n.type == close then
            level = level - 1
        end
    end

    return state.position - 1
end

local function parse_code(state, open, close)
    local istart = state.position
    local iend = parse_find_matching(state, open, close)

    return {
        type = "code",
        value = tlang.parse(sublist(state.lexed, istart, iend))
    }
end

function internal.parse_step(state)
    local n = parse_peek(state)

    if n == nil then
        return nil
    elseif n.type == "code_open" then
        return parse_code(state, "code_open", "code_close")
    elseif n.type == "code_e_open" then
        return {
            parse_code(state, "code_e_open", "code_e_close"),
            {type = "identifier", value = "run"}
        }
        -- also return run
    elseif n.type == "map_open" then
        local istart = state.position
        local iend = parse_find_matching(state, "map_open", "map_close")
        return parse_map({lexed = sublist(state.lexed, istart, iend, true), position = 1})
    elseif n.type == "literal" then
        if n.subtype == "number" then
            parse_next(state)
            return {type = "number", value = tonumber(n.value)}
        elseif n.subtype == "string" then
            parse_next(state)
            return {type = "string", value = n.value}
        elseif n.subtype == "identifier" then
            return parse_identifier(state)
        elseif n.subtype == "quote" then
            parse_next(state)
            return {type = "quote", value = n.value}
        end
    elseif n.type == "symbol" then
        parse_next(state)
        return {type = "symbol", value = n.value}
    end
end


-- parse
function tlang.parse(lexed)
    local state = {lexed = lexed, position = 1}
    local tree = {}
    local treei = 1

    while true do
        local n = internal.parse_step(state)

        if n == nil then
            if state.position <= #state.lexed then
                return nil
            else
                return tree
            end
        end

        if n.type == nil then -- () = {} run
            tree[treei] = n[1]
            tree[treei + 1] = n[2]
            treei = treei + 2
        else
            tree[treei] = n
            treei = treei + 1
        end
    end
end
