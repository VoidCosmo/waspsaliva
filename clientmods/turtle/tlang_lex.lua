-- CC0/Unlicense Emilia 2020

local tlang = ...

local function in_list(value, list)
    for k, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end


-- lex state
--[[
{
    code = "",
    position = int
}
--]]

-- lex types
--[[
literal
    number
    quote
    identifier
    mapid   -- TEMP
    string
symbol
code_open
code_close
code_e_open
code_e_close
map_open
map_close
map_relation
--]]


-- yeah yeah regex im lazy in this time consuming way shush
local whitespace = {" ", "\t", "\n", "\r", "\v"}
local identifier_start = {
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "_", "."
}
local identifier_internal = {
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "_",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
}
local symbol_start = {"!", "-", "+", "=", "&", "*", "/", "^", "%", ">", "<", "?", "~"}
local symbol_values = {
    "!", "-", "+", "=", "&", "*", "/", "^", "%", ">", "<", "?", "~"
}
local string_start = {"\"", "'"}
local number_start = {"-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}
local number_values = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}
local escape_values = {n = "\n", r = "\r", v = "\v", t = "\t", ['"'] = '"', ["'"] = "'"}
local symbols = {
    "!", "-", "+", "=", "&", "*", "/", "^", "%", ">", "<", "?", "~",
    "&&", "||", "==", "!=", ">=", "<=", "--", "++"
}

local function lex_peek(state)
    local out = state.code:sub(state.position, state.position)
    if out == "" then
        return nil
    end
    return out
end

local function lex_next(state)
    local value = lex_peek(state)
    state.position = state.position + 1
    return value
end

local function lex_expect(state, chars)
    if type(chars) == "string" then
        chars = {chars}
    end

    local n = lex_next(state)
    if in_list(n, chars) then
        return n
    else
        return nil -- ERROR!
    end
end

local function lex_whitespace(state)
    while true do
        local n = lex_peek(state)
        if not in_list(n, whitespace) then
            return
        end
        lex_next(state)
    end
end

local function lex_identifier_raw(state, top)
    local identifier = {}
    local n = 1

    while true do
        local cur = lex_peek(state)
        if in_list(cur, identifier_internal) then
            identifier[n] = lex_next(state)
            n = n + 1
        elseif cur == "." then
            lex_next(state)
            local subs = lex_identifier_raw(state)

            if type(subs) == "string" then
                subs = {subs}
            end

            if n > 1 then
                table.insert(subs, 1, table.concat(identifier))
            elseif top then -- TOS .key.key syntax
                table.insert(subs, 1, '')
            end

            return subs
        else
            break
        end
    end

    return {table.concat(identifier)}
end

local function lex_identifier(state)
    local id = lex_identifier_raw(state, true)
    return {type = "literal", subtype = "identifier", value = id}
end

-- `identifier
local function lex_quote(state)
    lex_next(state)
    local val = lex_identifier(state)
    val.subtype = "quote"
    return val
end

local function lex_single_char(state, t, char)
    lex_next(state)
    return {type = t, value = char}
end

local function lex_code_open(state)
    return lex_single_char(state, "code_open", "{")
end

local function lex_code_close(state)
    return lex_single_char(state, "code_close", "}")
end

local function lex_code_e_open(state)
    return lex_single_char(state, "code_e_open", "(")
end

local function lex_code_e_close(state)
    return lex_single_char(state, "code_e_close", ")")
end

local function lex_map_open(state)
    return lex_single_char(state, "map_open", "[")
end

local function lex_map_relation(state)
    return lex_single_char(state, "map_relation", ":")
end

local function lex_map_close(state)
    return lex_single_char(state, "map_close", "]")
end

local function lex_string_escape(state)
    local n = lex_next(state)
    return escape_values[n]
end

local function lex_string(state)
    local bchar = lex_next(state)

    local escaped = false
    local string = {}
    local stringi = 1

    while true do
        local n = lex_next(state)

        if n == bchar then
            return {type = "literal", subtype = "string", value = table.concat(string)}
        elseif n == "\\" then
            n = lex_string_escape(state)
        end

        if n == nil then
            return nil -- ERROR
        end

        string[stringi] = n
        stringi = stringi + 1
    end
end

local function lex_number(state)
    local used_sep = false
    local num = {}
    local numi = 1
    
    local n = lex_peek(state)
    if in_list(n, number_start) then
        num[numi] = lex_next(state)
        numi = numi + 1

        while true do
            n = lex_peek(state)

            if n == "." and not used_sep then
                used_sep = true
            elseif not in_list(n, number_values) then
                return {type = "literal", subtype = "number", value = table.concat(num)}
            end

            num[numi] = lex_next(state)
            numi = numi + 1
        end
    end
end

local function lex_symbol(state)
    local sym = {}
    local symi = 1

    while true do
        local n = lex_peek(state)
        if not in_list(n, symbol_values) then
            local symbol = table.concat(sym)
            if in_list(symbol, symbols) then
                return {type = "symbol", value = symbol}
            else
                return nil -- ERROR
            end
        elseif n == nil then
            return nil -- ERROR
        else
            sym[symi] = lex_next(state)
            symi = symi + 1
        end
    end
end

local function lex_number_or_symbol(state)
    local nextpeek = state.code:sub(state.position + 1, state.position + 1)
    if in_list(nextpeek, number_values) then
        return lex_number(state)
    else
        return lex_symbol(state)
    end
end

local function lex_comment(state)
    while true do
        local n = lex_next(state)
        if n == nil or n == "\n" then
            return false
        end
    end
end

local function lex_step(state)
    local cur = lex_peek(state)

    if cur == nil then
        return nil
    end

    if in_list(cur, whitespace) then
        lex_whitespace(state)
    end
    
    cur = lex_peek(state)

    if cur == "`" then
        return lex_quote(state)
    elseif cur == "-" then -- special case for negative numbers and the minus
        return lex_number_or_symbol(state)
    elseif in_list(cur, symbol_start) then
        return lex_symbol(state)
    elseif cur == "{" then
        return lex_code_open(state)
    elseif cur == "}" then
        return lex_code_close(state)
    elseif cur == "(" then
        return lex_code_e_open(state)
    elseif cur == ")" then
        return lex_code_e_close(state)
    elseif cur == "[" then
        return lex_map_open(state)
    elseif cur == "]" then
        return lex_map_close(state)
    elseif cur == ":" then
        return lex_map_relation(state)
    elseif in_list(cur, identifier_start) then
        return lex_identifier(state)
    elseif in_list(cur, string_start) then
        return lex_string(state)
    elseif in_list(cur, number_start) then
        return lex_number(state)
    elseif cur == "#" then
        return lex_comment(state)
    end
end

-- lex
function tlang.lex(code)
    local state = {code = code, position = 1}
    local lexed = {}
    local lexi = 1

    while true do
        local n = lex_step(state)

        if n == nil then
            if state.position <= #state.code then
                return nil
            else
                return lexed
            end
        end

        -- comment lexer returns false
        if n ~= false then
            lexed[lexi] = n
            lexi = lexi + 1
        end
    end
end
