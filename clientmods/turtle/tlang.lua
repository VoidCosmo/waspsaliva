-- CC0/Unlicense Emilia 2020

local tlang = {}

local prefix = ""
if minetest ~= nil then
    prefix = minetest.get_modpath(minetest.get_current_modname()) .. "/"
end

local function merge_tables(l1, l2)
    local out = {}

    for k, v in pairs(l1) do
        out[k] = v
    end

    for k, v in pairs(l2) do
        out[k] = v
    end

    return out
end

local function load_api_file(file)
    loadfile(prefix .. file)(tlang)
end

load_api_file("tlang_lex.lua")
load_api_file("tlang_parse.lua")
load_api_file("tlang_vm.lua")


function tlang.combine_builtins(b1, b2)
    return merge_tables(b1, b2)
end

function tlang.construct_builtins(builtins)
    return merge_tables(tlang.builtins, builtins)
end

-- TODO
--[[
lexer should include line/character number in symbols
error messages
maps should be able to have out of order number indexes (like [1 2 3 10:"Out of order"])
map.key accessing syntax
    parse as identifier, include . as identifier character, split on . and thats the indexing tree
--]]

function tlang.run(state)
    while true do
        local more = tlang.step(state)
        if more == true or more == nil then
            -- continue along
        elseif type(more) == "string" then
            print(more) -- error
        elseif more == false then
            return -- done
        else
            print("Unknown error, tlang.step returned: " .. tostring(more))
        end
    end
end

function tlang.get_state(code)
    local lexed = tlang.lex(code)
    local parsed = tlang.parse(lexed)

    return {
        locals = {{
            pc = {sg = 1, pos = {"__ast__"}, elem = 1},
            vars = {
                __src__ = tlang.value_to_tlang(code),
                __lex__ = tlang.value_to_tlang(lexed),
                __ast__ = {type = "code", value = parsed}
            }
        }},
        stack = {},
        code_stack = {},
        builtins = tlang.builtins
    }
end

function tlang.exec(code)
    local state = tlang.get_state(code)
    tlang.run(state)
end

function tlang.pretty_pc(pc)
    return tostring(pc.sg) .. ";" .. table.concat(pc.pos, ".") .. ";" .. tostring(pc.elem)
end

function tlang.format_table(t, depth, maxdepth)
    depth = depth or 0
    maxdepth = maxdepth or -1

    if depth == maxdepth then
        return "{...}"
    end

    local out = {}
    out[1] = "{\n"

    for k, v in pairs(t) do
        local idx = k
        if type(k) == "string" then
            idx = '"' .. k .. '"'
        elseif type(k) == "table" then
            idx = "{...}"
        end

        out[#out + 1] = string.rep("\t", depth + 1) .. "[" .. idx .. "] = "

        if type(v) == "table" then
            out[#out + 1] = tlang.format_table(v, depth + 1, maxdepth)
        elseif type(v) == "string" then
            out[#out + 1] = '"' .. v .. '"'
        else
            out[#out + 1] = tostring(v)
        end

        out[#out + 1] = ",\n"
    end

    out[#out + 1] = string.rep("\t", depth) .. "}"
    return table.concat(out)
end

function tlang.print_table(t, maxdepth)
    print(tlang.format_table(t, nil, maxdepth))
end

local function test()
    local complex = [[{dup *} `square =
    -5.42 square
    "Hello, world!" print
    [1 2 3 str:"String"]
    ]]

    local number = "-4.2123"

    local simple = "{dup *}"

    local map = "[this:2 that:3]"

    local square = [[{dup *} `square =
    5 square print]]

    local square_run = "5 {dup *} run print"

    local comment_test = "'asd' print # 'aft' print"

    local forever_test = [[
    5  # iteration count
    {
        dup     # duplicate iter count
        print   # print countdown
        --      # decrement
        dup 0 ==    # check if TOS is 0
        {break} if  # break if TOS == 0
    }
    forever   # run loop
    ]]

    local local_test = [[
    'outside' `var =
    {
        var print       # should be 'outside'
        'inside' `var =
        var print       # should be 'inside'
    } run
    var print           # should be 'inside'
    ]]

    local while_test = [[
    5 `cur =
    {
        `cur --
        cur
    } {
        "four times" print
    } while
    ]]

    local repeat_test = [[
    {
        "four times" print
    } 4 repeat
    {
        i print
    } 5 `i repeat
    ]]

    local stack_test = "5 5 == print"

    local args_test = [[
    {   0 `first `second args
        first print
        second print
    } `test =
    1 2 test
    ]]

    local ifelse_test = [[
        {
            {
                'if' print
            } {
                'else' print
            } if
        } `ifprint =

        1 ifprint
        0 ifprint
    ]]

    local nest_run = [[
        {
            {
                'innermost' print
            } run
        } run
        'work' print
    ]]

    local mapid_test = "this.that.2.here .81..wao.88912"

    local paren_test = "('works' print) 'out' print"

    local mapdot_test = [[
        [1 a:5 b:[a:2 b:3] 3] `a =
        4 `a.a =
        a.1 print
        a.2 print
        a.a print
        a.b.b print
    ]]

    local stackdot_test = [[
        [a:1 b:2]
        .b print
        6 `.a =
        .a print
    ]]

    local funcfunc_test = [[
    {dup *} `square =
    {dup square *} `cube =
    5 cube print
    ]]

    local test = funcfunc_test

    --tlang.print_table(tlang.lex(test))
    --tlang.print_table(tlang.parse(tlang.lex(test)))
    tlang.exec(test)
end

if minetest == nil then
    test()
end

return tlang
