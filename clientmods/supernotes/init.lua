-- CC0/Unlicense system32 2020

-- WIKI FORMATTING
-- [[link]] -> link to 'link'
-- [[link|Wow]] -> link to 'link' with the display value of 'Wow'
-- {{coords|X Y Z}} -> coordinates for X Y Z that adds an autofly waypoint at that coordinate when clicked

--[[
TODO/wishlist:

<nowiki></nowiki> maybe extract text between these and put them somewhere, replacing them with a temp marker which is replaced with the original text once formatting is done

headers

maybe make the page list a wiki page?

page history
--]]

local storage = minetest.get_mod_storage()

local start_page = "Welcome to supernotes! Click Edit/Save to edit or save a page, Pages to list all pages, and type in that Page bar to go to a page."

local sidebar_page = "Sidebar"

local example_json = '{"sidebar": "' .. sidebar_page .. '", "start": "' .. start_page .. '"}'

local pages = minetest.parse_json(storage:get("supernotes_pages") or example_json)

local function save()
    storage:set_string("supernotes_pages", minetest.write_json(pages))
end


local formspec_base = [[
size[10,9]

field[0.3,0.5;6.5,1;page;Page/search;NOTE_TITLE]
button[6.6,0.2;1.5,1;go;Go]
button[8.2,0.2;1.5,1;pages;Pages]

hypertext[0.3,1.7;2,7;sidebar;SIDEBAR_TEXT]
ARTICLE_AREA

button_exit[0,8.2;2,1;quit;Quit]
button[7.9,8.2;2,1;edit;Edit/Save]

field_close_on_enter[page;false]
]]

local formspec_article = formspec_base:gsub("ARTICLE_AREA", "hypertext[2.5,1.7;7,7;article;ARTICLE_TEXT]")

local formspec_edit = formspec_base:gsub("ARTICLE_AREA", "textarea[2.5,1.7;7,7;article;;ARTICLE_TEXT]")

local formspec_pagelist = formspec_base:gsub("ARTICLE_AREA", "textlist[2.5,1.7;7,6.3;article;ARTICLES]")

local function format_coords(text)
    local num = "([-]?%d+.?%d*)"
    local space = "%s+"
    text = text:gsub("{{coords|" .. num .. space .. num .. space .. num .. "}}", "<action name=coords_%1_%2_%3>%1 %2 %3</action>")
    return text
end

local function format_wikilinks(text)
    local tmatch = "[^%[%|%]]"
    text = text:gsub("%[%[(" .. tmatch .. "-)|(" .. tmatch .. "-)%]%]", "<action name=link_%1>%2</action>")
    text = text:gsub("%[%[(" .. tmatch .. "-)%]%]", "<action name=link_%1>%1</action>")
    return text
end

local function wikiformat(text)
    text = format_coords(text)
    text = format_wikilinks(text)
    return text
end


local function getkeys(t)
    local out = {}
    for k, v in pairs(t) do
        out[#out + 1] = k
    end
    return out
end

local function startswith(s1, s2)
    return string.sub(s1, 1, string.len(s2)) == s2
end

local editing = false
local current_page = nil

local function show_page(page, mode)
    page = page or ""
    current_page = page

    local fs = ""
    if mode == nil then
        fs = formspec_article
        fs = fs:gsub("ARTICLE_TEXT", wikiformat(pages[page] or "Page empty. Click Edit to create."))
    elseif mode == "list" then
        fs = formspec_pagelist
        fs = fs:gsub("ARTICLES", table.concat(getkeys(pages), ","))
    elseif mode == "edit" then
        editing = true
        fs = formspec_edit
        fs = fs:gsub("ARTICLE_TEXT", minetest.formspec_escape(pages[page] or ""))
    end

    fs = fs:gsub("NOTE_TITLE", page)
    fs = fs:gsub("SIDEBAR_TEXT", wikiformat(pages.sidebar or ""))

    minetest.show_formspec("supernotes", fs)
end

local function linkfield(field)
    if startswith(field or "", "action:") then
        local action = field:match("action:(.*)")
        local wikilink = action:match("link_(.*)")
        local x, y, z = action:match("coords_([^_]+)_([^_]+)_([^_]+)")

        if wikilink then
            show_page(wikilink)
            return true
        elseif x and y and z then
            if autofly then
                -- maybe use autofly.set_hud_wp instead?
                autofly.set_waypoint(x .. "," .. y .. "," .. z, "Supernotes: " .. x .. "," .. y .. "," .. z)
                autofly.display_formspec()
            end
            return true
        end
    end
end


minetest.register_on_formspec_input(function(formspec, fields)
    if formspec == "supernotes" then
        -- go to page
        if fields.page ~= "" and (fields.go or fields.page ~= current_page) then
            show_page(fields.page)
        -- enter edit mode
        elseif fields.edit and not editing then
            show_page(fields.page, "edit")
        -- exit edit mode
        elseif fields.edit and editing then
            editing = false
            pages[fields.page] = fields.article
            save()
            show_page(fields.page)
        -- list pages
        elseif fields.pages then
            show_page(fields.page, "list")
        -- make sure to exit editing mode if exiting
        elseif fields.quit then
            editing = false
        -- process links for article and sidebar
        elseif linkfield(fields.article) then
        elseif linkfield(fields.sidebar) then
        -- list link clicking
        elseif startswith(fields.article, "CHG") then
            local target = fields.article:match("CHG:(.*)")
            show_page(getkeys(pages)[tonumber(target)])
        end
    end
end)

minetest.register_on_shutdown(save)

minetest.register_chatcommand("notes", {
    params = "<page/empty>",
    description = "Open Supernotes at the specified page or last opened page.",
    func = function(params)
        local page = string.split(params, " ")[1]
        show_page(page or current_page or "start")
    end
})
