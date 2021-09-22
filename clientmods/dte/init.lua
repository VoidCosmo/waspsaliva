local data = {  -- window size
    width = 15,
    height = 10,

}
local form_esc = minetest.formspec_escape  -- shorten the function

local modstorage = core.get_mod_storage()


local function create_tabs(selected)
    return "tabheader[0,0;_option_tabs_;" ..
    "  LUA EDITOR   ,FORMSPEC EDITOR,  LUA CONSOLE  ,     FILES     ,    STARTUP    ,   FUNCTIONS   ,     HELP      ;"..selected..";;]"
end

local function copy_table(table)
    local new = {}
    for i, v in pairs(table) do
        if type(v) == "table" then
            v = copy_table(v)
        end
        new[i] = v
    end
    return new
end


----------
-- LOAD AND DEFINE STUFF  - global stuff is accissible from the UI
----------

local split = function (str, splitter)  -- a function to split a string into a list. "\" before the splitter makes it ignore it (usefull for minetests formspecs)
    local result = {""}
    for i=1, str:len() do
        char = string.sub(str, i, i)
        if char == splitter and string.sub(str, i-1, i-1) ~= "\\" then
            table.insert(result, "")
        else
            result[#result] = result[#result]..char
        end
    end
    return result
end


local output = {}  -- the output for errors, prints, etc

local saved_file = modstorage:get_string("_lua_saved")  -- remember what file is currently being edited
if saved_file == "" then
    saved_file = false  -- if the file had no save name (it was still saved)
end


local lua_startup = split(modstorage:get_string("_lua_startup"), ",")  -- the list of scripts to run at startup

local lua_files = split(modstorage:get_string("_lua_files_list"), ",")  -- the list of names of all saved files

local ui_files = split(modstorage:get_string("_UI_files_list"), ",")  -- UI files list

local reg_funcs = {formspec_input={}, chatcommands={}, on_connect={}, joinplayer={}, sending_chat_message={}, recieving_chat_message={}}


local selected_files = {0, 0}


--minetest.register_on_connect(function()  -- some functions don't work after startup. this tries to replace them

    minetest.get_mod_storage = function()
        return modstorage
    end

    core.get_mod_storage = function()
        return modstorage
    end

    -- show formspec

--end)  -- add whatever functions don't work after startup to here (if possible)


----------
-- FUNCTIONS FOR UI
----------

function print(...)  --  replace print to output into the UI. (doesn't refresh untill the script has ended)
    params = {...}
    if #params == 1 then
        local str = params[1]
        if type(str) ~= "string" then
            str = dump(str)
        end
        table.insert(output, "")
        for i=1, str:len() do
            char = string.sub(str, i, i)
            if char == "\n" then
                table.insert(output, "")  -- split multiple lines over multiple lines. without this, text with line breaks would not display properly
            else
                output[#output] = output[#output]..char
            end
        end
    else
        for i, v in pairs(params) do
            print(v)
        end
    end
end

function safe(func)  -- run a function without crashing the game. All errors are displayed in the UI.
    f = function(...)  -- This can be used for functions being registered with minetest, like "minetest.register_chat_command()"
        status, out = pcall(func, ...)
        if status then
            return out
        else
            table.insert(output, "#ff0000Error:  "..out)
            minetest.debug("Error (func):  "..out)
            return nil
        end
    end
    return f
end


----------
-- CODE EXECUTION
----------

local function run(code, name)  -- run a script
    if name == nil then
        name = saved_file
    end
    status, err = pcall(loadstring(code))  -- run
    if status then
        if saved_file == false then
            table.insert(output, "#00ff00finished")  -- display that the script ran without errors
        else
            table.insert(output, "#00ff00"..name..":  finished")  -- display which script, if it was saved
        end
    else
        if err == "attempt to call a nil value" then
            err = "Syntax Error"
        end
        if saved_file == false then
            table.insert(output, "#ff0000Error:  "..err)  -- display errors
            minetest.log("Error (unsaved):  "..err)
        else
            table.insert(output, "#ff0000"..name..": Error:  "..err)
            minetest.log("Error ("..name.."):  "..err)
        end
    end
end

local function on_startup()  -- ran on startup. Runs all scripts registered for startup
    for i, v in pairs(lua_startup) do
        if v ~= "" then
            run(modstorage:get_string("_lua_file_"..v, v), v)  -- errors still get displayed in the UI
        end
    end
end

on_startup()


----------
-- FILE READING AND SAVING
----------

local function load_lua()  -- returns the contents of the file currently being edited
    if saved_file == false then
        return modstorage:get_string("_lua_temp")  -- unsaved files are remembered  (get saved on UI reloads - when clicking on buttons)
    else
        return modstorage:get_string("_lua_file_"..saved_file)
    end
end

local function save_lua(code)  -- save a file
    if saved_file == false then
        modstorage:set_string("_lua_temp", code)
    else
        modstorage:set_string("_lua_file_"..saved_file, code)
    end
end


----------
-- FORM DEFINITIONS
----------


local function startup_form()  -- the formspec for adding or removing files for startup
    local startup_str = ""
    for i, v in pairs(lua_startup) do
        if i ~= 1 then startup_str = startup_str.."," end
        startup_str = startup_str .. form_esc(v)
    end
    local files_str = ""
    for i, v in pairs(lua_files) do
        if i ~= 1 then files_str = files_str.."," end
        files_str = files_str .. form_esc(v)
    end

    local form = ""..
    "size["..data.width..","..data.height.."]" ..
    "label[0,0.1;Startup Items:]"..
    "label["..data.width/2 ..",0.1;File List:]"..
    "textlist[0,0.5;"..data.width/2-0.1 ..","..data.height-1 ..";starts;"..startup_str.."]"..
    "textlist["..data.width/2 ..",0.5;"..data.width/2-0.1 ..","..data.height-1 ..";chooser;"..files_str.."]"..
    "label[0," .. data.height-0.3 .. ";double click items to add or remove from startup]"..

    "" .. create_tabs(5)
    return form
end


local function lua_editor()  -- the main formspec for editing

    local output_str = ""  --  convert the output to a string
    for i, v in pairs(output) do
        if output_str:len() > 0 then output_str = output_str .. "," end
        output_str = output_str .. form_esc(v)
    end

    local code = form_esc(load_lua())

    -- create the form
    local form = ""..
    "size["..data.width..","..data.height.."]" ..
    "textarea[0.3,0.1;"..data.width ..","..data.height-3 ..";editor;Lua editor;"..code.."]"..
    "button[0," .. data.height-3.5 .. ";1,0;run;RUN]"..
    "button[1," .. data.height-3.5 .. ";1,0;clear;CLEAR]"..
    "button[2," .. data.height-3.5 .. ";1,0;save;SAVE]"..
    "textlist[0,"..data.height-3 ..";"..data.width-0.2 ..","..data.height-7 ..";output;"..output_str..";".. #output .."]"..

    "" .. create_tabs(1)
    return form
end


local function file_viewer()  -- created with the formspec editor!
    local lua_files_item_str = ""
    for i, item in pairs(lua_files) do
        if i ~= 1 then lua_files_item_str = lua_files_item_str.."," end
        lua_files_item_str = lua_files_item_str .. form_esc(item)
    end

    local ui_select_item_str = ""
    for i, item in pairs(ui_files) do
        if i ~= 1 then ui_select_item_str = ui_select_item_str.."," end
        ui_select_item_str = ui_select_item_str .. form_esc(item)
    end

    local form = "" ..
    "size["..data.width..","..data.height.."]" ..
    "textlist[-0.2,0.2;"..data.width/2.02- -0.2 ..","..data.height- 1 ..";lua_select;"..lua_files_item_str.."]" ..
    "label[-0.2,-0.2;LUA FILES]" ..
    "field[0.1,"..data.height- 0.2 ..";3,1;new_lua;NEW;]" ..
    "field_close_on_enter[new_lua;false]" ..
    "button[2.6,"..data.height- 0.5 ..";0.5,1;add_lua;+]" ..
    "textlist["..data.width/1.97 ..",0.2;"..data.width- 0-(data.width/1.97) ..","..data.height- 1 ..";ui_select;"..ui_select_item_str.."]" ..
    "label["..data.width/1.96 ..",-0.2;FORMSPEC FILES]" ..
    "field["..data.width- 2.8 ..","..data.height- 0.2 ..";3,1;new_ui;NEW;]" ..
    "field_close_on_enter[new_ui;false]" ..
    "button["..data.width- 0.3 ..","..data.height- 0.5 ..";0.5,1;add_ui;+]" ..
    "label["..data.width/2.4 ..","..data.height- 0.8 ..";Double click a file to open it]" ..
    "button[3.1,"..data.height- 0.5 ..";1.1,1;del_lua;DELETE]" ..
    "button["..data.width- 4.2 ..","..data.height- 0.5 ..";1.1,1;del_ui;DELETE]" ..
    "" .. create_tabs(4)

    return form
end


----------
-- FUNCTIONALITY
----------

minetest.register_on_formspec_input(function(formname, fields)

    -- EDITING PAGE
    ----------
    if formname == "lua:editor" then
        if fields.run then  --[RUN] button
            save_lua(fields.editor)
            run(fields.editor)

            minetest.show_formspec("lua:editor", lua_editor())

        elseif fields.save then  --[SAVE] button
            if saved_file == false then
                modstorage:set_string("_lua_temp", fields.editor)
            else
                modstorage:set_string("_lua_file_"..saved_file, fields.editor)
            end

        elseif fields.clear then  --[CLEAR] button
            output = {}
            save_lua(fields.editor)
            minetest.show_formspec("lua:editor", lua_editor())
        end

    -- STARTUP EDITOR
    ----------
    elseif formname == "lua:startup" then  -- double click a file to remove it from the list
        if fields.starts then
            local select = {["type"] = string.sub(fields.starts, 1, 3), ["row"] = tonumber(string.sub(fields.starts, 5, 5))}
            if select.type == "DCL" then
                table.remove(lua_startup, select.row)
                local startup_str = ""
                for i, v in pairs(lua_startup) do
                    if v ~= "" then
                        startup_str = startup_str..v..","
                    end
                end
                modstorage:set_string("_lua_startup", startup_str)
                minetest.show_formspec("lua:startup", startup_form())
            end

        elseif fields.chooser then  -- double click a file to add it to the list
            local select = {["type"] = string.sub(fields.chooser, 1, 3), ["row"] = tonumber(string.sub(fields.chooser, 5, 5))}
            if select.type == "DCL" then
                table.insert(lua_startup, lua_files[select.row])
                local startup_str = ""
                for i, v in pairs(lua_startup) do
                    if v ~= "" then
                        startup_str = startup_str..v..","
                    end
                end
                modstorage:set_string("_lua_startup", startup_str)
                minetest.show_formspec("lua:startup", startup_form())
            end
        end
    end
end)




----------            ----------
-- PASTE FORMSPEC EDITOR HERE --
----------            ----------



---------- ----------
-- FORMSPEC EDITOR START --
---------- ----------

local widg_list = {"Button", "DropDown", "CheckBox", "Slider", "Tabs", "TextList", "Table", "Field", "TextArea", "InvList", "Label", "Image", "Box", "Tooltip", "Container"}  -- all widget options

local widgets = nil  -- stores all widget data for the current file

local selected_widget = 1  -- the widget/tab currently being edited

local new_widg_tab = false  -- so the new widget tab can be displayed without moving the selection

local main_ui_form  -- make this function global to the rest of the program


local current_ui_file = modstorage:get_string("_GUI_editor_selected_file")  -- file name of last edited file
if current_ui_file == "" then  -- for first ever load
    current_ui_file = "new"
    modstorage:set_string("_GUI_editor_selected_file", current_ui_file)
    modstorage:set_string("_GUI_editor_file_"..current_ui_file, dump({{type="Display", name="", width=5, height=5, width_param=false, height_param=false, left=0.5, top=0.5,
        position=false, background=false, colour="#000000aa", fullscreen=false, colour_tab=false,
        col={col=false, bg_normal="#f0fa", bg_hover="#f0fa", set_border=false, border="#f0fa", set_tool=false, tool_bg="#f0fa", tool_font="#f0fa"}}}))
end

local function reload_ui()  -- update the display, and save the file
    modstorage:set_string("_GUI_editor_file_"..current_ui_file, dump(widgets))
    minetest.show_formspec("ui_editor:main", main_ui_form())
end

local function load_UI(name)  -- open/create a ui file
    current_ui_file = name
    modstorage:set_string("_GUI_editor_selected_file", current_ui_file)
    _, widgets = pcall(loadstring("return "..modstorage:get_string("_GUI_editor_file_"..current_ui_file)))
    if widgets == nil then
        widgets = {{type="Display", name="", width=5, height=5, width_param=false, height_param=false, left=0.5, top=0.5,
        position=false, background=false, colour="#000000aa", fullscreen=false, colour_tab=false,
        col={col=false, bg_normal="#f0fa", bg_hover="#f0fa", set_border=false, border="#f0fa", set_tool=false, tool_bg="#f0fa", tool_font="#f0fa"}}}
    end
end
load_UI(current_ui_file)

--widgets = {{type="Display", name="", width=5, height=5, width_param=false, height_param=false, left=0.5, top=0.5, position=false, background=false, colour="#000000aa", fullscreen=false, colour_tab=false, col={col=false, bg_normal="#f0fa", bg_hover="#f0fa", set_border=false, border="#f0fa", set_tool=false, tool_bg="#f0fa", tool_font="#f0fa"}} }

----------
-- UI DISPLAY
----------

-- generates the preview of the UI being edited
local function generate_ui()
    local width = data.width-5  -- the size that is needed for the final formspec size, so large formspecs can be previewed
    local height = data.height

    -- data for calculating positions
    local left = {0.1}
    local top = {0.1}
    local fwidth = {1}
    local fheight = {1}

    local form = ""
    local boxes = ""  -- because I can't add to form in get_rect() function

    local depth = 1  -- container depth

    -- calculates the positions of widgets, and creates the position syntax from a widget def
    local function get_rect(widget, real, full)

        local wleft = 0  -- widget top (etc)
        if widget.left_type == "R-" then  -- right is value from right side
            wleft = left[depth]+fwidth[depth]-widget.left
        elseif widget.left_type == "W/" then  -- right is width/value from left side
            wleft = left[depth]+fwidth[depth]/widget.left
        else  -- right is value from left side
            wleft = left[depth]+widget.left
        end
        if full then  -- container only takes whole numbers as positions.
            wleft = math.floor(wleft-left[depth])+left[depth]
        end

        local wtop = 0
        if widget.top_type == "B-" then  -- value from bottom
            wtop = top[depth]+fheight[depth]-widget.top
        elseif widget.top_type == "H/" then  -- height/value from top
            wtop = top[depth]+(fheight[deformpth]/widget.top)
        else  -- value from top
            wtop = top[depth]+widget.top
        end
        if full then
            wtop = math.floor(wtop-top[depth])+top[depth]
        end

        if widget.right == nil then  -- for widgets with no size option
            return wleft..","..wtop..";"

        else
            local wright = 0
            if widget.right_type == "R-" then
                wright = left[depth]+fwidth[depth]-widget.right-wleft
            elseif widget.right_type == "W/" then
                wright = left[depth]+fwidth[depth]/widget.right-wleft
            elseif widget.right_type == "R" then  -- relative to left
                wright = widget.right
            else
                wright = left[depth]+widget.right-wleft
            end

            local wbottom = 0
            if widget.bottom_type == "B-" then
                wbottom = top[depth]+fheight[depth]-widget.bottom-wtop
            elseif widget.bottom_type == "H/" then
                wbottom = top[depth]+fheight[depth]/widget.bottom-wtop
            elseif widget.bottom_type == "R" then
                wbottom = widget.bottom
            else
                wbottom = top[depth]+widget.bottom-wtop
            end

            if wleft+wright > width then  -- stops widgets covering the controlls
                boxes = boxes.."box["..width ..","..wtop ..";"..wleft+wright-width..","..wbottom..";#ff0000]"  -- shows where it would go
                wright = width-wleft
            end

            if real then
                return {left=wleft, top=wtop, width=wright, height=wbottom}  -- table uses the calculated values for other things
            end
            return wleft..","..wtop..";"..wright..","..wbottom..";"
        end
    end

    -- iterate all widgets
    for i, v in pairs(widgets) do

        if v.type == "Display" then  -- defines the size
            if v.width < data.width-5.2 then
                left = {math.floor(((data.width-5)/2 - v.width/2)*10)/10}  -- place the form in the center
            else
                width = math.floor((v.width+0.2)*10)/10  -- resize for large forms
            end
            if v.height < data.height-0.2 then -- ^
                top = {data.height/2 - v.height/2}
            else
                height = v.height+0.2
            end
            fwidth = {v.width}
            fheight = {v.height}
            form = form ..
            -- "box["..left[1]..","..top[1]..";"..v.width..","..v.height..";#000000]"  -- this adds it to the form
            "box["..left[1]-0.28 ..","..top[1]-0.3 ..";"..v.width+0.38 ..",".. 0.32 ..";#000000]" ..
            "box["..left[1]-0.28 ..","..top[1]+v.height..";"..v.width+0.38 ..",".. 0.4 ..";#000000]" ..
            "box["..left[1]-0.28 ..","..top[1]..";".. 0.3 ..","..v.height..";#000000]" ..
            "box["..left[1]+v.width..","..top[1]..";".. 0.1 ..","..v.height..";#000000]"

            if v.background then
                form = form .. "bgcolor["..v.colour..";"..tostring(v.fullscreen).."]"
            end
            if v.col.col then
                form = form.."listcolors["..v.col.bg_normal..";"..v.col.bg_hover
                if v.col.set_border then
                    form = form..";"..v.col.border
                    if v.col.set_tool then
                        form = form..";"..v.col.tool_bg..";"..v.col.tool_font
                    end
                end
                form = form.."]"
            end


        elseif v.type == "Button" then
            if v.image then  -- image option
                if v.item and not v.exit then
                    form = form .. "item_image_button["..get_rect(v)..form_esc(v.texture)..";"..i.."_none;"..form_esc(v.label).."]"
                else
                    form = form .. "image_button["..get_rect(v)..form_esc(v.texture)..";"..i.."_none;"..form_esc(v.label).."]"
                end
            else
                form = form .. "button["..get_rect(v)..i.."_none;"..form_esc(v.label).."]"
            end

        elseif v.type == "Field" then
            if v.password then  -- password option
                form = form .. "pwdfield["..get_rect(v)..i.."_none;"..form_esc(v.label).."]"
            else
                form = form .. "field["..get_rect(v)..i.."_none;"..form_esc(v.label)..";"..form_esc(v.default).."]"
            end
            form = form .. "field_close_on_enter["..i.."_none;false]"

        elseif v.type == "TextArea" then
            form = form .. "textarea["..get_rect(v)..i.."_none;"..form_esc(v.label)..";"..form_esc(v.default).."]"

        elseif v.type == "Label" then
            if v.vertical then  -- vertical option
                form = form .. "vertlabel["..get_rect(v)..form_esc(v.label).."]"
            else
                form = form .. "label["..get_rect(v)..form_esc(v.label).."]"
            end

        elseif v.type == "TextList" then
            local item_str = ""  -- convert the list to a sting
            for i, item in pairs(v.items) do
                item_str = item_str .. form_esc(item)..","
            end
            if v.transparent then  -- transparent option
                form = form .. "textlist["..get_rect(v)..i.."_none;"..item_str..";1;True]"
            else
                form = form .. "textlist["..get_rect(v)..i.."_none;"..item_str.."]"
            end

        elseif v.type == "DropDown" then
            local item_str = ""  -- convert the list to a string
            for i, item in pairs(v.items) do
                item_str = item_str .. form_esc(item)..","
            end
            form = form .. "dropdown["..get_rect(v)..i.."_none;"..item_str..";"..v.select_id.."]"

        elseif v.type == "CheckBox" then
            form = form .. "checkbox["..get_rect(v)..i.."_none;"..v.label..";"..tostring(v.checked).."]"

        elseif v.type == "Box" then  -- a coloured square
            form = form .. "box["..get_rect(v)..form_esc(v.colour).."]"

        elseif v.type == "Image" then
            if v.item then
                form = form .. "item_image["..get_rect(v)..form_esc(v.image).."]"
            elseif v.background then
                if v.fill then
                    form = form .. "background["..left[1]-0.18 ..","..top[1]-0.22 ..";"..fwidth[1]+0.37 ..","..fheight[1]+0.7 ..";"..form_esc(v.image).."]"
                else
                    form = form .. "background["..get_rect(v)..form_esc(v.image).."]"
                end
            else
                form = form .. "image["..get_rect(v)..form_esc(v.image).."]"
            end

        elseif v.type == "Slider" then
            orientation = "horizontal"
            if v.vertical then
                orientation = "vertical"
            end
            form = form .. "scrollbar["..get_rect(v)..orientation..";"..i.."_none;"..v.value.."]"

        elseif v.type == "InvList" then
            local extras = {["player:"]=1, ["nodemeta:"]=1, ["detached:"]=1}  -- locations that need extra info (v.data)
            if extras[v.location] then
                form = form .. "list["..v.location..form_esc(v.data)..";"..form_esc(v.name)..";"..get_rect(v)..v.start.."]"
                if v.ring then  -- items can be shift clicked between ring items
                    form = form .. "listring["..v.location..form_esc(v.data)..";"..form_esc(v.name).."]"
                end
            else
                form = form .. "list["..v.location..";"..form_esc(v.name)..";"..get_rect(v)..v.start.."]"
                if v.ring then
                    form = form .. "listring["..v.location..";"..form_esc(v.name).."]"
                end
            end

        elseif v.type == "Table" then
            local cell_str = ""
            local column_str = ""

            local most_items = 0  -- the amount of rows needed = the most items in a column
            for i, c in pairs(v.columns) do
                if #c.items > most_items then  -- get max length
                    most_items = #c.items
                end

                if i > 1 then
                    column_str = column_str..";"
                end
                column_str = column_str .. c.type  -- add column types
                if c.type == "image" then  -- add list of available images
                    for n, t in pairs(c.images) do
                        column_str = column_str..","..n .."="..form_esc(t)
                    end
                elseif c.type == "color" and c.distance ~= "infinite" then  -- add distance that coloures affect
                    column_str = column_str..",span="..c.distance
                end
            end
            for i=1, most_items do  -- create a list from all column's lists
                for n, c in pairs(v.columns) do  -- create a row from column's items
                    if n > 1 or i > 1 then
                        cell_str = cell_str..","
                    end
                    local item = c.items[i]
                    if item == nil then  -- blank item if this column doesn't exend as far
                        item = ""
                    end
                    cell_str = cell_str..form_esc(item)
                end
            end
            if column_str:len() > 0 then
                form = form .. "tablecolumns["..column_str.."]"
            end
            form = form .. "table["..get_rect(v)..i.."_none;"..cell_str..";-1]"

        elseif v.type == "Tooltip" then
            for n, w in pairs(widgets) do
                if w.name == v.name and w.type ~= "Tooltip" then
                    if v.colours then
                        form = form .. "tooltip["..n.."_none;"..v.text..";"..v.bg..";"..v.fg.."]"
                    else
                        form = form .. "tooltip["..n.."_none;"..v.text.."]"
                    end
                end
            end

        elseif v.type == "Container - Start" then
            local rect = get_rect(v, true, true)
            left[depth+1] = rect.left  -- register the new area
            top[depth+1] = rect.top
            fwidth[depth+1] = rect.width
            fheight[depth+1] = rect.height
            depth = depth+1
        elseif v.type == "Container - End" then
            depth = depth-1  -- go back to the parent area

        elseif v.type == "Tabs" then
            local capt_str = ""
            for i, capt in pairs(v.captions) do
                if i > 1 then capt_str = capt_str.."," end
                capt_str = capt_str .. form_esc(capt)
            end
            form = form .. "tabheader["..get_rect(v)..i.."_none;"..capt_str..";"..v.tab..";"..tostring(v.transparent)..";"..tostring(v.border).."]"

        end
    end

    return form..boxes, width+5, height
end


----------
-- Compiling
----------

-- generates a function to create the UI, with parameters
local function generate_function()
    local form_esc = function(str)  -- escape symbols need to be escaped
        return string.gsub(minetest.formspec_escape(str), "\\", "\\\\")  -- which have to be escaped...
    end

    local parameters = {}  -- these store info which will be put together at the end
    local before_str = ""
    local display = {}
    local form = ""
    local table_items = false

    local function name(v)  -- converts the name into something that can be used in parameters
        n = v.name

        if v.type == "InvList" then  -- the name of inv lists is used differently
            n = v.location.."_"..v.name
        end

        local new = ""

        chars = "abcdefghijklmnopqrstuvwxyz"
        chars = chars..string.upper(chars)
        for i=1, #n do
            local c = n:sub(i,i)
            if string.find(chars, c, 1, true) or (string.find("1234567890", c, 1, true) and i ~= 1) then  -- numbers only allowed after first char
                new = new..c
            else
                new = new.."_"
            end
        end
        return new
    end

    local width = {widgets[1].width}
    if widgets[1].width_param then  -- if size defined from parameters
        width = {"width"}
    end
    local height = {widgets[1].height}
    if widgets[1].height_param then
        height = {"height"}
    end
    local dep = 1  -- depth into containers

    -- returns a string containing the position and size of a widget, or (hopefully) the most efficient calculation
    local function get_rect(widget, real, l, t)
        local fwidth = width[dep]
        local fheight = height[dep]

        local wleft = "0"
        if type(fwidth) == "string" or l then  -- if the area width (window or continer) will be changed with a parameter
            local l_ = l  -- if the left of the widget comes from a parameter
            if l_ == nil then
                l_ = widget.left
            end
            if widget.left_type == "R-" then  -- different position types
                wleft = fwidth..'- '..l_
            elseif widget.left_type == "W/" then
                wleft = fwidth..'/'..l_
            else
                wleft = l_
            end
            if type(wleft) == "string" and not real then
                wleft = '"..'..wleft..' .."'
            end
        else
            if widget.left_type == "R-" then  -- calculation made now if nothing comes from a parameter
                wleft = fwidth-widget.left
            elseif widget.left_type == "W/" then
                wleft = fwidth/widget.left
            else
                wleft = widget.left
            end
        end

        local wtop = "0"  --top
        if type(fheight) == "string" or t then
            local t_ = t
            if t_ == nil then
                t_ = widget.top
            end
            if widget.top_type == "B-" then
                wtop = fheight..'- '..t_
            elseif widget.left_type == "H/" then
                wtop = fheight..'/'..t_
            else
                wtop = t_
            end
            if type(wtop) == "string" and not real then
                wtop = '"..'..wtop..' .."'
            end
        else
            if widget.top_type == "B-" then
                wtop = fheight-widget.top
            elseif widget.left_type == "H/" then
                wtop = fheight/widget.top
            else
                wtop = widget.top
            end
        end

        if widget.right == nil then  -- for widgets with no size option
            return wleft..","..wtop

        else
            local wright = 0
            if type(fwidth) == "string" then  -- if the width is changed by a parameter
                local l_ = l
                if l_ == nil then
                    l_ = widget.left
                end
                -- goes through all right types, and for eacg, goes through all left types to get the best calculation.
                if widget.right_type == "R-" then  -- (I know there is a better way of doing this)
                    if widget.left_type == "R-" then
                        wright = fwidth..'- '..widget.right..'-('..fwidth..'- '..l_..')'
                    elseif widget.left_type == "W/" then
                        wright = fwidth..'- '..widget.right..'-('..fwidth..'/'..l_..')'
                    elseif type(l_) == "string" then
                        wright = fwidth..'- '..widget.right.."- "..l_
                    else
                        wright = fwidth..'- '..widget.right+l_
                    end
                elseif widget.right_type == "W/" then
                    if widget.left_type == "R-" then
                        wright = fwidth..'/'..widget.right..'-('..fwidth..'- '..l_..')'
                    elseif widget.left_type == "W/" then
                        wright = fwidth..'/'..widget.right..'-('..fwidth..'/'..l_..')'
                    else
                        wright = fwidth..'/'..widget.right.."- "..l_
                    end
                elseif widget.right_type == "R" then
                    wright = widget.right
                else
                    if widget.left_type == "R-" then
                        wright = widget.right..'-('..fwidth..'- '..l_..')'
                    elseif widget.left_type == "W/" then
                        wright = widget.right..'-('..fwidth..'/'..l_..')'
                    elseif type(l) == "string" then
                        wright = widget.right.."- "..l_
                    else
                        wright = widget.right-l_
                    end
                end
                if type(wright) == "string" and not real then
                    wright = '"..'..wright..' .."'
                end
            elseif l then  -- if there is a parameter for the left, but not the width
                if widget.right_type == "R-" then
                    if widget.left_type == "R-" then
                        wright = fwidth-widget.right..'-('..fwidth..'- '..l..')'
                    elseif widget.left_type == "W/" then
                        wright = fwidth-widget.right..'-('..fwidth..'/'..l..')'
                    else
                        wright = fwidth-widget.right.."- "..l
                    end
                elseif widget.right_type == "W/" then
                    if widget.left_type == "R-" then
                        wright = fwidth..'/'..widget.right..'-('..fwidth..'- '..l..')'
                    elseif widget.left_type == "W/" then
                        wright = fwidth..'/'..widget.right..'-('..fwidth..'/'..l..')'
                    else
                        wright = fwidth..'/'..widget.right.."- "..l
                    end
                elseif widget.right_type == "R" then
                    wright = widget.right
                else
                    if widget.left_type == "R-" then
                        wright = widget.right..'-('..fwidth..'- '..l..')'
                    elseif widget.left_type == "W/" then
                        wright = widget.right..'-('..fwidth..'/'..l..')'
                    else
                        wright = widget.right.."- "..l
                    end
                end
                if type(wright) == "string" and not real then
                    wright = '"..'..wright..' .."'
                end
            else  -- if all values are known now
                if widget.right_type == "R-" then
                    wright = fwidth-widget.right-wleft
                elseif widget.right_type == "W/" then
                    wright = fwidth/widget.right-wleft
                elseif widget.right_type == "R" then
                    wright = widget.right
                else
                    wright = widget.right-wleft
                end
            end

            local wbottom = 0  -- similar for bottom
            if type(fheight) == "string" then
                local t_ = t
                if t_ == nil then  -- if widget's top comes from a parameter (container)
                    t_ = widget.top
                end
                if widget.bottom_type == "B-" then
                    if widget.top_type == "B-" then
                        wbottom = fheight..'- '..widget.bottom..'-('..fheight..'- '..t_..')'
                    elseif widget.left_type == "W/" then
                        wbottom = fheight..'- '..widget.bottom..'-('..fheight..'/'..t_..')'
                    elseif type(t_) == "string" then
                        wbottom = fheight..'- '..widget.bottom.."- "..t_
                    else
                        wbottom = fheight..'- '..widget.bottom+t_
                    end
                elseif widget.bottom_type == "H/" then
                    if widget.top_type == "B-" then
                        wbottom = fheight..'/'..widget.bottom..'-('..fheight..'- '..t_..')'
                    elseif widget.left_type == "W/" then
                        wbottom = fheight..'/'..widget.bottom..'-('..fheight..'/'..t_..')'
                    else
                        wbottom = fheight..'/'..widget.bottom.."- "..t_
                    end
                elseif widget.bottom_type == "R" then
                    wbottom = widget.bottom
                else
                    if widget.top_type == "B-" then
                        wbottom = widget.bottom..'-('..fheight..'- '..t_..')'
                    elseif widget.left_type == "W/" then
                        wbottom = widget.bottom..'-('..fheight..'/'..t_..')'
                    elseif type(t_) == "string" then
                        wbottom = widget.bottom.."- "..t_
                    else
                        wbottom = widget.bottom-t_
                    end
                end
                if type(wbottom) == "string" and not real then
                    wbottom = '"..'..wbottom..' .."'
                end
            elseif t then
                if widget.bottom_type == "B-" then
                    if widget.top_type == "B-" then
                        wbottom = fheight-widget.bottom-fheight..'- '..t
                    elseif widget.left_type == "W/" then
                        wbottom = fheight-widget.bottom-fheight..'/'..t
                    else
                        wbottom = fheight-widget.bottom.."+"..t
                    end
                elseif widget.bottom_type == "H/" then
                    if widget.top_type == "B-" then
                        wbottom = fheight/widget.bottom-fheight..'- '..t
                    elseif widget.left_type == "W/" then
                        wbottom = fheight/widget.bottom-fheight..'/'..t
                    else
                        wbottom = fheight/widget.bottom.."- "..t
                    end
                elseif widget.bottom_type == "R" then
                    wbottom = widget.bottom
                else
                    if widget.top_type == "B-" then
                        wbottom = widget.bottom-fheight..'- '..t
                    elseif widget.left_type == "W/" then
                        wbottom = widget.bottom-fheight..'/'..t
                    elseif type(t) == "string" then
                        wbottom = widget.bottom.."- "..t
                    else
                        wbottom = widget.bottom-t
                    end
                end
                if type(wbottom) == "string" and not real then
                    wbottom = '"..'..wbottom..' .."'
                end
            else
                if widget.bottom_type == "B-" then
                    wbottom = fheight-widget.bottom-wtop
                elseif widget.bottom_type == "H/" then
                    wbottom = fheight/widget.bottom-wtop
                elseif widget.bottom_type == "R" then
                    wbottom = widget.bottom
                else
                    wbottom = widget.bottom-wtop
                end
            end

            if real then
                return {left=wleft, top=wtop, width=wright, height=wbottom}  -- container needs the values seperate
            end
            return wleft..","..wtop..";"..wright..","..wbottom
        end
    end


    local w, h = 0, 0

    -- go through all the widgets, and add their code
    for i, v in pairs(widgets) do

        if v.type == "Display" then
            local w, h
            if v.width_param then  -- things like this are for parameters
                table.insert(parameters, "width")
                w = '"..width.."'
            else
                w = tostring(v.width)
            end
            if v.height_param then
                table.insert(parameters, "height")
                h = '"..height.."'
            else
                h = tostring(v.height)
            end
            table.insert(display, '"size['..w..','..h..']"')
            if v.position then  -- for non-default position
                table.insert(display, '"position['..v.left..','..v.top..']"')
            end
            if v.background then
                table.insert(display, '"bgcolor['..v.colour..';'..tostring(v.fullscreen)..']"')
            end
            if v.col.col then
                local cols = '"listcolors['..v.col.bg_normal..";"..v.col.bg_hover
                if v.col.set_border then
                    cols = cols..";"..v.col.border
                    if v.col.set_tool then
                        cols = cols..";"..v.col.tool_bg..";"..v.col.tool_font
                    end
                end
                cols = cols..']"'
                table.insert(display, cols)
            end


        elseif v.type == "Button" then
            if v.image then
                local tex = ""
                if v.image_param then  -- image texture param
                    table.insert(parameters, name(v).."_image")
                    tex = '"..'..name(v)..'_image.."'
                else
                    tex = form_esc(v.texture)
                end
                if v.item and not v.exit then  -- quit on click
                    table.insert(display, '"item_image_button['..get_rect(v)..';'..tex..';'..form_esc(v.name)..';'..form_esc(v.label)..']"')
                else
                    if v.exit then  -- quit on click - image
                        table.insert(display, '"image_button_exit['..get_rect(v)..';'..tex..';'..form_esc(v.name)..';'..form_esc(v.label)..']"')
                    else  -- normal image
                        table.insert(display, '"image_button['..get_rect(v)..';'..tex..';'..form_esc(v.name)..';'..form_esc(v.label)..']"')
                    end
                end
            else
                if v.exit then  -- quit on click
                    table.insert(display, '"button_exit['..get_rect(v)..';'..form_esc(v.name)..';'..form_esc(v.label)..']"')
                else  -- basic button
                    table.insert(display, '"button['..get_rect(v)..';'..form_esc(v.name)..';'..form_esc(v.label)..']"')
                end
            end

        elseif v.type == "Field" then
            if v.password then  -- password field
                table.insert(display, '"pwdfield['..get_rect(v)..';'..form_esc(v.name)..';'..form_esc(v.label)..']"')
            else
                local default = ""
                if v.default_param then  -- default param
                    table.insert(parameters, name(v).."_default")
                    default = '"..minetest.formspec_escape('..name(v)..'_default).."'
                else
                    default = form_esc(v.default)
                end
                table.insert(display, '"field['..get_rect(v)..';'..form_esc(v.name)..';'..form_esc(v.label)..';'..default..']"')
            end
            if v.enter_close == false then
                table.insert(display, '"field_close_on_enter['..form_esc(v.name)..';false]"')
            end

        elseif v.type == "TextArea" then
            local default = ""
            if v.default_param then
                table.insert(parameters, name(v).."_default")
                default = '"..minetest.formspec_escape('..name(v)..'_default).."'
            else
                default = form_esc(v.default)
            end
            table.insert(display, '"textarea['..get_rect(v)..';'..form_esc(v.name)..';'..form_esc(v.label)..';'..form_esc(default)..']"')

        elseif v.type == "Label" then
            local label = form_esc(v.label)
            if v.label_param then
                table.insert(parameters, name(v).."_label")
                label = '"..minetest.formspec_escape('..name(v)..'_label).."'
            end
            if v.vertical then  -- vertical label
                table.insert(display, '"vertlabel['..get_rect(v)..';'..label..']"')
            else
                table.insert(display, '"label['..get_rect(v)..';'..label..']"')
            end

        elseif v.type == "TextList" then
            local items = ""
            if v.items_param then
                table.insert(parameters, name(v).."_items")
                before_str = before_str..   -- add code for converting the list from a parameter to a string
                '    local '..name(v)..'_item_str = ""\n' ..
                '    for i, item in pairs('..name(v)..'_items) do\n' ..
                '        if i ~= 1 then '..name(v)..'_item_str = '..name(v)..'_item_str.."," end\n' ..
                '        '..name(v)..'_item_str = '..name(v)..'_item_str .. minetest.formspec_escape(item)\n' ..
                '    end\n\n'
                items = '"..'..name(v)..'_item_str.."'
            else
                items = ""
                for i, item in pairs(v.items) do
                    if i ~= 1 then items = items.."," end
                    items = items .. form_esc(item)
                end
            end
            if v.item_id_param or v.transparent then
                if v.item_id_param then  -- selected item parameter
                    table.insert(parameters, name(v).."_selected_item")
                    table.insert(display, '"textlist['.. get_rect(v)..';'..form_esc(v.name)..';'..items..';"..'..name(v)..'_selected_item..";'..tostring(v.transparent)..']"')
                else
                    table.insert(display, '"textlist['..get_rect(v)..';'..form_esc(v.name)..';'..items..';1;'..tostring(v.transparent)..']"')
                end
            else
                table.insert(display, '"textlist['..get_rect(v)..';'..form_esc(v.name)..';'..items..']"')
            end

        elseif v.type == "DropDown" then
            local items = ""
            if v.items_param then
                table.insert(parameters, name(v).."_items")
                before_str = before_str..   -- add code for converting the list from a parameter to a string
                '    local '..name(v)..'_item_str = ""\n' ..
                '    for i, item in pairs('..name(v)..'_items) do\n' ..
                '        if i ~= 1 then '..name(v)..'_item_str = '..name(v)..'_item_str.."," end\n' ..
                '        '..name(v)..'_item_str = '..name(v)..'_item_str .. minetest.formspec_escape(item)\n' ..
                '    end\n\n'
                items = '"..'..name(v)..'_item_str.."'
            else
                items = ""
                for i, item in pairs(v.items) do
                    if i ~= 1 then items = items.."," end
                    items = items .. form_esc(item)
                end
            end
            local item_id = ""
            if v.item_id_param then  -- selected item parameter
                table.insert(parameters, name(v).."_selected_item")
                item_id = '"..'..name(v)..'_selected_item.."'
            else
                item_id = tostring(v.select_id)
            end
            table.insert(display, '"dropdown['..get_rect(v)..';'..form_esc(v.name)..';'..items..';'..item_id..']"')

        elseif v.type == "CheckBox" then
            local checked = tostring(v.checked)
            if v.checked_param then
                table.insert(parameters, name(v).."_checked")
                checked = '"..tostring('..name(v)..'_checked).."'
            end
            table.insert(display, '"checkbox['..get_rect(v)..';'..form_esc(v.name)..";"..form_esc(v.label)..';'..checked..']"')

        elseif v.type == "Box" then
            local colour = form_esc(v.colour)
            if v.colour_param then
                table.insert(parameters, name(v).."_colour")
                colour = '"..'..name(v)..'_colour.."'
            end
            table.insert(display, '"box['..get_rect(v)..';'..colour..']"')

        elseif v.type == "Image" then
            local image = form_esc(v.image)
            if v.image_param then  -- texture
                table.insert(parameters, name(v).."_image")
                image = '"..'..name(v)..'_image.."'
            end
            if v.item then
                table.insert(display, '"item_image['..get_rect(v)..';'..image..']"')
            elseif v.background then
                table.insert(display, '"background['..get_rect(v)..';'..image..';'..tostring(v.fill)..']"')
            else
                table.insert(display, '"image['..get_rect(v)..';'..image..']"')
            end

        elseif v.type == "Slider" then
            local value = form_esc(v.value)
            if v.value_param then
                table.insert(parameters, name(v).."_value")
                value = '"..'..name(v)..'_value.."'
            end
            local orientation = "horizontal"
            if v.vertical then
                orientation = "vertical"
            end
            table.insert(display, '"scrollbar['..get_rect(v)..';'..orientation..";"..form_esc(v.name)..";"..value..']"')

        elseif v.type == "InvList" then
            local extras = {["player:"]=1, ["nodemeta:"]=1, ["detached:"]=1}
            local data = ""
            if v.data_param then  -- extra location data needed in some locations
                table.insert(parameters, name(v).."_data")
                data = '"..minetest.formspec_escape('..name(v)..'_data).."'
            elseif extras[v.location] then
                data = form_esc(v.data)
            end
            local start = v.start
            if v.page_param then
                table.insert(parameters, name(v).."_start_idx")
                start = '"..'..name(v)..'_start_idx.."'
            end
            table.insert(display, '"list['..v.location..data..';'..form_esc(v.name)..';'..get_rect(v)..';'..start..']"')
            if v.ring then  -- shift clicking between item lists
                table.insert(display, '"listring['..v.location..data..';'..form_esc(v.name)..']"')
            end

        elseif v.type == "Table" then
            local cell_str = ""
            local column_str = ""

            local item_param = false
            local most_items = 0
            for i, c in pairs(v.columns) do
                if #c.items > most_items then  -- find how many columns are needed
                    most_items = #c.items
                end
                if c.items_param then  -- find out if any parameters are needed
                    item_param = true
                end

                if i > 1 then  -- create a column string
                    column_str = column_str..";"
                end
                column_str = column_str .. c.type
                if c.type == "image" then  -- add list of images
                    for n, t in pairs(c.images) do
                        column_str = column_str..","..n .."="..t
                    end
                elseif c.type == "color" and c.distance ~= "infinite" then  -- and distance affected by colour
                    column_str = column_str..",span="..c.distance
                end
            end

            if not item_param then  -- calculate item list if none come from parameters
                for i=1, most_items do
                    for n, c in pairs(v.columns) do
                        if n > 1 or i > 1 then
                            cell_str = cell_str..","
                        end
                        local item = c.items[i]
                        if item == nil then
                            item = ""
                        end
                        cell_str = cell_str..item
                    end
                end
            else  -- or add the code to convert the items from the parameters into a string
                local items = "    local "..name(v).."_cells = {"
                for i, c in pairs(v.columns) do
                    if c.items_param then
                        table.insert(parameters, name(v).."_col_"..i.."_items")
                        items = items.."\n        ["..i.."]="..name(v).."_col_"..i.."_items,"
                    else
                        local item_str = "{"  -- create a string table with the items
                        for n, item in pairs(c.items) do
                            item_str = item_str..'"'..item..'", '
                        end
                        item_str = item_str.."}"
                        items = items.."\n        ["..i.."]="..item_str..","
                    end
                end
                items = items.."\n    }\n"

                table_items = true  -- this makes it add the function onto the start of the function
                before_str = before_str..items ..
                '    local '..name(v)..'_cell_str = table_item_str('..name(v)..'_cells)\n\n'

                cell_str = '"..'..name(v)..'_cell_str.."'
            end

            if column_str:len() > 0 then  -- tablecolumns without columns gives an error
                table.insert(display, '"tablecolumns['..column_str..']"')
            end

            local selected = ""
            if v.select_param then  -- selected item parameter
                table.insert(parameters, name(v).."_selected_item")
                selected = '"..'..name(v)..'_selected_item.."'
            end
            table.insert(display, '"table['..get_rect(v)..";"..form_esc(v.name)..';'..cell_str..';'..selected..']"')

        elseif v.type == "Tooltip" then
            if v.colours then
                table.insert(display, '"tooltip['..form_esc(v.name)..';'..form_esc(v.text)..';'..form_esc(v.bg)..';'..form_esc(v.fg)..']"')
            else
                table.insert(display, '"tooltip['..form_esc(v.name)..';'..form_esc(v.text)..']"')
            end

        elseif v.type == "Container - Start" then  -- container has 2 sections
            local l = v.left
            if v.left_param then  -- the only widget which can hve position parameters
                table.insert(parameters, name(v).."_left")
                l = name(v)..'_left'
            end
            local t = v.top
            if v.top_param then
                table.insert(parameters, name(v).."_top")
                t = name(v)..'_top'
            end
            local rect = get_rect(v, true, l, t)  -- the area is returned as a table this time
            dep = dep+1
            if type(rect.width) == "string" then  -- if it is a calculation, and not the calculated value
                width[dep] = "("..rect.width..")"
            else
                width[dep] = rect.width
            end
            if type(rect.height) == "string" then
                height[dep] = "("..rect.height..")"
            else
                height[dep] = rect.height
            end
            if type(rect.left) == "string" then
                rect.left = '"..'..rect.left..' .."'
            end
            if type(rect.top) == "string" then
                rect.top = '"..'..rect.top..' .."'
            end
            table.insert(display, '"container['..rect.left..','..rect.top..']"')
        elseif v.type == "Container - End" then  -- only exits the table
            dep = dep-1
            table.insert(display, '"container_end[]"')

        elseif v.type == "Tabs" then
            local capt_str = ""
            for i, capt in pairs(v.captions) do
                if i > 1 then capt_str = capt_str.."," end
                capt_str = capt_str .. form_esc(capt)
            end
            table.insert(display, '"tabheader['..get_rect(v)..';'..form_esc(v.name)..';'..capt_str..';'..v.tab..';'.. tostring(v.transparent)..';'..tostring(v.border)..']"')

        end
    end

    if table_items then  -- the function generating a string from a list of column items
        before_str = '' ..  -- added if a table uses parameters
        '    local function table_item_str(cells)\n' ..
        '        local most_items = 0\n' ..
        '        for i, v in pairs(cells) do\n' ..
        '            if #v > most_items then\n' ..
        '                most_items = #v\n' ..
        '            end\n' ..
        '        end\n' ..
        '        local cell_str = ""\n' ..
        '        for i=1, most_items do\n' ..
        '            for n=1, #cells do\n' ..
        '                if n > 1 or i > 1 then ' ..
        'cell_str = cell_str.."," ' ..
        'end\n' ..
        '                local item = cells[n][i]\n' ..
        '                if item == nil then ' ..
        'item = "" ' ..
        'end\n' ..
        '                cell_str = cell_str..minetest.formspec_escape(item)\n' ..
        '            end\n' ..
        '        end\n' ..
        '        return cell_str\n' ..
        '    end\n\n' ..
        before_str
    end

    param_str = ""  -- creates the parameter string --> "param1, param2, paramN"
    for i, v in pairs(parameters) do
        if i ~= 1 then
            param_str = param_str .. ", "
        end
        param_str = param_str .. v
    end

    -- puts the first part of the function together
    form = form .. "function generate_form("..param_str..")\n" .. before_str .. '\n    local form = "" ..\n'

    for i, v in pairs(display) do  -- adds the widget strings
        form = form .. "    "..v.." ..\n"
    end

    form = form .. '    ""\n\n    return form\nend'  -- completes it

    return form
end

-- generates a string for a static UI
local function generate_string()
    local form_esc = function(str)  -- escape symbols need to be escaped with escaped escape symbols ;p
        return string.gsub(minetest.formspec_escape(str), "\\", "\\\\")
    end

    local fwidth = {0}
    local fheight = {0}
    local dep = 1

    local function get_rect(widget, real)  -- can't be bothered commenting this. see function on line 73, it is basically the same...
        local wleft = 0
        if widget.left_type == "R-" then
            wleft = fwidth[dep]-widget.left
        elseif widget.left_type == "W/" then
            wleft = fwidth[dep]/widget.left
        else
            wleft = widget.left
        end

        local wtop = 0
        if widget.top_type == "B-" then
            wtop = fheight[dep]-widget.top
        elseif widget.left_type == "H/" then
            wtop = fheight[dep]/widget.top
        else
            wtop = widget.top
        end

        if widget.right == nil then  -- for widgets with no size option
            return wleft..","..wtop..";"

        else
            local wright = 0
            if widget.right_type == "R-" then
                wright = fwidth[dep]-widget.right-wleft
            elseif widget.right_type == "W/" then
                wright = fwidth[dep]/widget.right-wleft
            elseif widget.right_type == "R" then
                wright = widget.right
            else
                wright = widget.right-wleft
            end

            local wbottom = 0
            if widget.bottom_type == "B-" then
                wbottom = fheight[dep]-widget.bottom-wtop
            elseif widget.bottom_type == "H/" then
                wbottom = fheight[dep]/widget.bottom-wtop
            elseif widget.bottom_type == "R" then
                wbottom = widget.bottom
            else
                wbottom = widget.bottom-wtop
            end

            if real then
                return {left=wleft, top=wtop, width=wright, height=wbottom}
            end
            return wleft..","..wtop..";"..wright..","..wbottom..";"
        end
    end

    local output = ""

    for i, v in pairs(widgets) do  -- go through all the widgets and create their strings

        if v.type == "Display" then
            fwidth = {v.width}
            fheight = {v.height}
            output = output .. "\"size["..v.width..","..v.height.."]\" ..\n"
            if v.position then
                output = output .. "\"position["..v.left..","..v.top.."]\" ..\n"
            end
            if v.background then
                output = output .. "\"bgcolor["..v.colour..";"..tostring(v.fullscreen).."]\" ..\n"
            end
            if v.col.col then
                output = output.."\"listcolors["..v.col.bg_normal..";"..v.col.bg_hover
                if v.col.set_border then
                    output = output..";"..v.col.border
                    if v.col.set_tool then
                        output = output..";"..v.col.tool_bg..";"..v.col.tool_font
                    end
                end
                output = output.."]\" ..\n"
            end

        elseif v.type == "Button" then
            if v.image then
                local ending = get_rect(v)..form_esc(v.texture)..";"..form_esc(v.name)..";"..form_esc(v.label).."]\" ..\n"
                if v.item and not v.exit then
                    output = output .. "\"item_image_button["..ending
                else
                    if v.exit then
                        output = output .. "\"image_button_exit["..ending
                    else
                        output = output .. "\"image_button["..ending
                    end
                end
            else
                if v.exit then
                    output = output .. "\"button_exit["..get_rect(v)..form_esc(v.name)..";"..form_esc(v.label).."]\" ..\n"
                else
                    output = output .. "\"button["..get_rect(v)..form_esc(v.name)..";"..form_esc(v.label).."]\" ..\n"
                end
            end

        elseif v.type == "Field" then
            if v.password then
                output = output .. "\"pwdfield["..get_rect(v)..form_esc(v.name)..";"..form_esc(v.label).."]\" ..\n"
            else
                output = output .. "\"field["..get_rect(v)..form_esc(v.name)..";"..form_esc(v.label)..";"..form_esc(v.default).."]\" ..\n"
            end
            if v.enter_close == false then
                output = output .. "\"field_close_on_enter["..form_esc(v.name)..";false]\" ..\n"
            end

        elseif v.type == "TextArea" then
            output = output .. "\"textarea["..get_rect(v)..form_esc(v.name)..";"..form_esc(v.label)..";"..form_esc(v.default).."]\" ..\n"

        elseif v.type == "Label" then
            if v.vertical then
                output = output .. "\"vertlabel["..get_rect(v)..form_esc(v.label).."]\" ..\n"
            else
                output = output .. "\"label["..get_rect(v)..form_esc(v.label).."]\" ..\n"
            end

        elseif v.type == "TextList" then
            local item_str = ""
            for i, item in pairs(v.items) do
                item_str = item_str .. form_esc(item)..","
            end
            if not v.transparent then
                output = output .. "\"textlist["..get_rect(v)..form_esc(v.name)..";"..item_str:sub(0,-2).."]\" ..\n"
            else
                output = output .. "\"textlist["..get_rect(v)..form_esc(v.name)..";"..item_str:sub(0,-2)..";1;true]\" ..\n"
            end

        elseif v.type == "DropDown" then
            local item_str = ""
            for i, item in pairs(v.items) do
                item_str = item_str .. form_esc(item)..","
            end
            output = output .. "\"dropdown["..get_rect(v)..form_esc(v.name)..";"..item_str:sub(0,-2)..";"..v.select_id.."]\" ..\n"

        elseif v.type == "CheckBox" then
            output = output .. "\"checkbox["..get_rect(v)..form_esc(v.name)..";"..form_esc(v.label)..";"..tostring(v.checked).."]\" ..\n"

        elseif v.type == "Box" then
            output = output .. "\"box["..get_rect(v)..form_esc(v.colour).."]\" ..\n"

        elseif v.type == "Image" then
            if v.item then
                output = output .. "\"item_image["..get_rect(v)..form_esc(v.image).."]\" ..\n"
            elseif v.background then
                output = output .. "\"background["..get_rect(v)..form_esc(v.image)..";"..tostring(v.fill).."]\" ..\n"
            else
                output = output .. "\"image["..get_rect(v)..form_esc(v.image).."]\" ..\n"
            end

        elseif v.type == "Slider" then
            orientation = "horizontal"
            if v.vertical then
                orientation = "vertical"
            end
            output = output .. "\"scrollbar["..get_rect(v)..orientation..";"..form_esc(v.name)..";"..v.value.."]\" ..\n"

        elseif v.type == "InvList" then
            local extras = {["player:"]=1, ["nodemeta:"]=1, ["detached:"]=1}
            if extras[v.location] then
                output = output .. "\"list["..v.location..form_esc(v.data)..";"..form_esc(v.name)..";"..get_rect(v)..v.start.."]\" ..\n"
                if v.ring then
                    output = output .. "\"listring["..v.location..form_esc(v.data)..";"..form_esc(v.name).."]\" ..\n"
                end
            else
                output = output .. "\"list["..v.location..";"..form_esc(v.name)..";"..get_rect(v)..v.start.."]\" ..\n"
                if v.ring then
                    output = output .. "\"listring["..v.location..";"..form_esc(v.name).."]\" ..\n"
                end
            end

        elseif v.type == "Table" then
            local cell_str = ""
            local column_str = ""

            -- this converts the column's individual item lists into a string
            local most_items = 0
            for i, c in pairs(v.columns) do
                if #c.items > most_items then
                    most_items = #c.items  -- gets the largest size
                end

                if i > 1 then
                    column_str = column_str..";"
                end
                column_str = column_str .. c.type  -- creates the column list
                -- adds column parameters \/
                if c.type == "image" then
                    for n, t in pairs(c.images) do
                        column_str = column_str..","..n .."="..t
                    end
                elseif c.type == "color" and c.distance ~= "infinite" then
                    column_str = column_str..",span="..c.distance
                end
            end
            for i=1, most_items do  -- adds all the items together
                for n, c in pairs(v.columns) do
                    if n > 1 or i > 1 then
                        cell_str = cell_str..","
                    end
                    local item = c.items[i]
                    if item == nil then  -- columns with less items get blank items to make them the same length
                        item = ""
                    end
                    cell_str = cell_str..item
                end
            end
            if column_str:len() > 0 then
                output = output .. "\"tablecolumns["..column_str.."]\" ..\n"
            end
            output = output .. "\"table["..get_rect(v)..form_esc(v.name)..";"..cell_str..";]\" ..\n"

        elseif v.type == "Tooltip" then
            if v.colours then
                output = output .. "\"tooltip["..form_esc(v.name)..";"..form_esc(v.text)..";"..form_esc(v.bg)..";"..form_esc(v.fg).."]\" ..\n"
            else
                output = output .. "\"tooltip["..form_esc(v.name)..";"..form_esc(v.text).."]\" ..\n"
            end


        elseif v.type == "Container - Start" then
            local rect = get_rect(v, true)
            fwidth[dep+1] = rect.width  -- set the width and height that widgets in the container use
            fheight[dep+1] = rect.height
            dep = dep+1
            output = output .. "\"container["..rect.left..","..rect.top.."]\" ..\n"
        elseif v.type == "Container - End" then
            dep = dep-1  -- close container
            output = output .. "\"container_end[]\" ..\n"

        elseif v.type == "Tabs" then
            local capt_str = ""
            for i, capt in pairs(v.captions) do
                if i > 1 then capt_str = capt_str.."," end
                capt_str = capt_str .. form_esc(capt)
            end
            output = output .. "\"tabheader["..get_rect(v)..form_esc(v.name)..";"..capt_str..";"..v.tab..";"..tostring(v.transparent)..";"..tostring(v.border).."]\" ..\n"
        end
    end
    return output .. '""'
end

----------
-- UI Editors
----------

-- creates a position chooser with << and >> buttons, text box, and position type (if needed)
local function ui_position(name, value, left, top, typ, typ_id)
    name = form_esc(name)
    local form = ""..
    "label["..left+0.1 ..","..top-0.3 ..";"..name.."]" ..
    "button["..left+0.1 ..","..top..";1,1;"..name.."_size_down;<<]" ..
    "field["..left+1.3 ..","..top+0.3 ..";1,1;"..name.."_size;;"..form_esc(value).."]" ..
    "field_close_on_enter["..name.."_size;false]" ..
    "button["..left+1.9 ..","..top..";1,1;"..name.."_size_up;>>]"
    local typ_ids = {["L+"]=1, ["T+"]=1, ["R-"]=2, ["B-"]=2, ["W/"]=3, ["H/"]=3, ["R"]=4}
    if typ == "LEFT" then  -- left and right sides use this type
        if name == "RIGHT" then  -- but right has a relative option (I should make it right type, but I decided much later to include it)
            form = form .."dropdown["..left+3 ..","..top+0.1 ..";1.1,1;"..name.."_type;LEFT +,RIGHT -,WIDTH /,RELATIVE;"..typ_ids[typ_id].."]"
        else
            form = form .. "dropdown["..left+3 ..","..top+0.1 ..";1.1,1;"..name.."_type;LEFT +,RIGHT -,WIDTH /;"..typ_ids[typ_id].."]"
        end
    elseif typ == "TOP" then
        if name == "BOTTOM" then
            form = form.."dropdown["..left+3 ..","..top+0.1 ..";1.1,1;"..name.."_type;TOP +,BOTTOM -,HEIGHT /,RELATIVE;"..typ_ids[typ_id].."]"
        else
            form = form .. "dropdown["..left+3 ..","..top+0.1 ..";1.1,1;"..name.."_type;TOP +,BOTTOM -,HEIGHT /;"..typ_ids[typ_id].."]"
        end
    end
    return form
end

-- handles position ui functionality
local function handle_position_changes(id, fields, range)
    local pos_names = {"width", "height", "left", "top", "right", "bottom", "value"}  -- the only names it will check
    for i, v in pairs(pos_names) do
        if fields[string.upper(v).."_size_down"] then  -- down button
            if range and range[v] then
                widgets[id][v] = widgets[id][v] - range[v]/10  -- slider uses a different step
            else
                widgets[id][v] = widgets[id][v] - 0.1
            end
            if widgets[id][v] < 0.0001 and widgets[id][v] > -0.0001 then widgets[id][v] = 0 end  -- weird number behaviour
        elseif fields[string.upper(v).."_size_up"] then  -- up button
            if range and range[v] then
                widgets[id][v] = widgets[id][v] + range[v]/10
            else
                widgets[id][v] = widgets[id][v] + 0.1
            end
            if widgets[id][v] < 0.0001 and widgets[id][v] > -0.0001 then widgets[id][v] = 0 end  -- weird number behaviour
        elseif fields.key_enter_field == string.upper(v).."_size" then  -- size edit box/displayer
            local value = tonumber(fields[string.upper(v).."_size"])
            if value ~= nil then
                widgets[id][v] = value
            end
        elseif fields[string.upper(v).."_type"] then  -- type selector
            local typ_trans = {["LEFT +"]="L+", ["RIGHT -"]="R-", ["WIDTH /"]="W/", ["TOP +"]="T+", ["BOTTOM -"]="B-", ["HEIGHT /"]="H/", ["RELATIVE"]="R"}
            widgets[id][v.."_type"] = typ_trans[fields[string.upper(v).."_type"]]
        end
        if range then  -- sometimes the number must be within a range
            if range[v] then
                if widgets[id][v] < 0 then
                    widgets[id][v] = 0
                elseif widgets[id][v] > range[v] then
                    widgets[id][v] = range[v]
                end
            end
        end
    end
end

-- creates a field to edit name or other attributes, and a parameter checkbox (if needed)
local function ui_field(name, value, left, top, param)
    name = form_esc(name)
    local field = "" ..
    "field["..left+0.2 ..","..top..";2.8,1;"..name.."_input_box;"..name..";"..form_esc(value).."]" ..
    "field_close_on_enter["..name.."_input_box;false]"
    if param ~= nil then
        field = field .. "checkbox["..left+2.8 ..","..top-0.3 ..";"..name.."_param_box;parameter;"..tostring(param).."]"
    end
    return field
end

-- handles field functionality
local function handle_field_changes(names, id, fields)
    for i, v in pairs(names) do  -- names are supplied this time, so only nececary ones are checked
        if fields.key_enter_field == string.upper(v).."_input_box" then
            widgets[id][v] = fields[string.upper(v).."_input_box"]
        elseif fields[string.upper(v).."_param_box"] then
            widgets[id][v.."_param"] = fields[string.upper(v).."_param_box"] == "true"
        end
    end
end

----------
-- individual widget definitions

-- functions for widget's custom editing UIs at the side
local widget_editor_uis = {
    Display = {  -- type can be seen here, etc, extra tabs (options, new widget) are at the end
        ui = function(id, left, top, width)  -- function for creating the form
            local form = "label["..left+1.7 ..","..top ..";-  DISPLAY  -]"

            if not widgets[id].colour_tab then
                form = form ..
                "button["..left+width-3 ..","..top+6.7 ..";3.1,1;col_page;INVENTORY COLOURS >]" ..
                ui_position("WIDTH", widgets[id].width, left, top+0.7) ..
                ui_position("HEIGHT", widgets[id].height, left, top+1.7) ..
                "checkbox["..left+3 ..","..top+0.7 ..";WIDTH_param_box;parameter;"..tostring(widgets[id].width_param).."]" ..
                "checkbox["..left+3 ..","..top+1.7 ..";HEIGHT_param_box;parameter;"..tostring(widgets[id].height_param).."]"

                if widgets[id].position then  -- this part only gets displayed if the position checkbox is checked
                    form = form ..
                    ui_position("LEFT", widgets[id].left, left, top+2.7) ..
                    ui_position("TOP", widgets[id].top, left, top+3.7) ..
                    "checkbox["..left+0.1 ..","..top+4.3 ..";pos_box;position;true]" ..
                    "checkbox["..left+2 ..","..top+4.3 ..";back_box;background;"..tostring(widgets[id].background).."]"
                    if widgets[id].background then
                        form = form..
                        ui_field("COLOUR", widgets[id].colour, left+0.2, top+5.5) ..
                        "checkbox["..left+3 ..","..top+5.2 ..";full;fullscreen;"..tostring(widgets[id].fullscreen).."]"
                    end
                else
                    form = form .. "checkbox["..left+0.1 ..","..top+2.3 ..";pos_box;position;false]"  ..
                    "checkbox["..left+2 ..","..top+2.3 ..";back_box;background;"..tostring(widgets[id].background).."]"
                    if widgets[id].background then
                        form = form..
                        ui_field("COLOUR", widgets[id].colour, left+0.2, top+3.5) ..
                        "checkbox["..left+3 ..","..top+3.2 ..";full;fullscreen;"..tostring(widgets[id].fullscreen).."]"
                    end
                end
            else
                form = form ..
                "checkbox["..left+0.1 ..","..top+0.3 ..";do_col;COLOURS;"..tostring(widgets[id].col.col).."]" ..
                "button["..left+width-1.2 ..","..top+6.7 ..";1.3,1;dat_page;BACK <]"

                if widgets[id].col.col then
                    form = form ..
                    "field["..left+0.4 ..","..top+1.5 ..";2.8,1;bg_main;BACKGROUND;"..widgets[id].col.bg_normal.."]" ..
                    "field_close_on_enter[bg_main;false]" ..
                    "field["..left+0.4 ..","..top+2.5 ..";2.8,1;bg_hover;HOVER BACKGROUND;"..widgets[id].col.bg_hover.."]" ..
                    "field_close_on_enter[bg_hover;false]" ..
                    "checkbox["..left+0.1 ..","..top+2.8 ..";do_border;BORDER;"..tostring(widgets[id].col.set_border).."]"

                    if widgets[id].col.set_border then
                        form = form ..
                        "field["..left+0.4 ..","..top+4 ..";2.8,1;border;BORDER;"..widgets[id].col.border.."]" ..
                        "field_close_on_enter[border;false]" ..
                        "checkbox["..left+0.1 ..","..top+4.3 ..";do_tool;TOOLTIP;"..tostring(widgets[id].col.set_tool).."]"
                        if widgets[id].col.set_tool then
                            form = form ..
                            "field["..left+0.4 ..","..top+5.5 ..";2.8,1;bg_tool;BACKGROUND;"..widgets[id].col.tool_bg.."]" ..
                            "field_close_on_enter[bg_tool;false]" ..
                            "field["..left+0.4 ..","..top+6.5 ..";2.8,1;tool_text;TEXT;"..widgets[id].col.tool_font.."]" ..
                            "field_close_on_enter[tool_text;false]"
                        end
                    end
                end
            end
            return form
        end,
        func = function(id, fields)  -- function for handling the form
            handle_position_changes(id, fields, {left=1, top=1})
            handle_field_changes({"colour"}, id, fields)
            if fields.WIDTH_param_box then
                widgets[id].width_param = fields.WIDTH_param_box == "true"
            elseif fields.HEIGHT_param_box then
                widgets[id].height_param = fields.HEIGHT_param_box == "true"

            elseif fields.pos_box then
                widgets[id].position = fields.pos_box == "true"
            elseif fields.back_box then
                widgets[id].background = fields.back_box == "true"
            elseif fields.full then
                widgets[id].fullscreen = fields.full == "true"

            elseif fields.col_page then  -- colour tab
                widgets[id].colour_tab = true
            elseif fields.dat_page then
                widgets[id].colour_tab = false

            elseif fields.do_col then
                widgets[id].col.col = fields.do_col == "true"
            elseif fields.do_border then
                widgets[id].col.set_border = fields.do_border == "true"
            elseif fields.do_tool then
                widgets[id].col.set_tool = fields.do_tool == "true"

            elseif fields.key_enter_field == "bg_main" then
                widgets[id].col.bg_normal = fields.bg_main
            elseif fields.key_enter_field == "bg_hover" then
                widgets[id].col.bg_hover = fields.bg_hover
            elseif fields.key_enter_field == "border" then
                widgets[id].col.border = fields.border
            elseif fields.key_enter_field == "bg_tool" then
                widgets[id].col.tool_bg = fields.bg_tool
            elseif fields.key_enter_field == "tool_text" then
                widgets[id].col.tool_font = fields.tool_text
            end

            reload_ui()  -- refresh the display and save the file
        end
    },

    Button = {
        ui = function(id, left, top, width)
            local form = "label["..left+1.8 ..","..top ..";-  BUTTON  -]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+0.7) ..  -- all have a name box
            ui_position("LEFT", widgets[id].left, left, top+1.4, "LEFT", widgets[id].left_type) ..  -- and an area or position
            ui_position("TOP", widgets[id].top, left, top+2.4, "TOP", widgets[id].top_type) ..
            ui_position("RIGHT", widgets[id].right, left, top+3.4, "LEFT", widgets[id].right_type) ..
            ui_position("BOTTOM", widgets[id].bottom, left, top+4.4, "TOP", widgets[id].bottom_type) ..
            ui_field("LABEL", widgets[id].label, left+0.2, top+5.7) ..  -- then extra things
            ""
            if widgets[id].image then
                form = form ..
                ui_field("TEXTURE", widgets[id].texture, left+0.2, top+6.7) ..
                "checkbox["..left+3 ..","..top+6.4 ..";image_param_box;parameter;"..tostring(widgets[id].image_param).."]" ..
                "checkbox["..left+1.8 ..","..top+7 ..";image_box;image;true]" ..
                "checkbox["..left+0.1 ..","..top+7 ..";close_box;exit form;"..tostring(widgets[id].exit).."]"
                if not widgets[id].exit then
                    form = form .. "checkbox["..left+3 ..","..top+7 ..";item_box;item;"..tostring(widgets[id].item).."]"
                end
            else
                form = form .. "checkbox["..left+1.8 ..","..top+6 ..";image_box;image;false]" ..
                "checkbox["..left+0.1 ..","..top+6 ..";close_box;exit form;"..tostring(widgets[id].exit).."]"
            end

            return form
        end,
        func = function(id, fields)
            handle_position_changes(id, fields)
            handle_field_changes({"name", "label", "texture"}, id, fields)
            if fields.image_box then
                widgets[id].image = fields.image_box == "true"

            elseif fields.image_param_box then
                widgets[id].image_param = fields.image_param_box == "true"

            elseif fields.item_box then
                widgets[id].item = fields.item_box == "true"

            elseif fields.close_box then
                widgets[id].exit = fields.close_box == "true"
            end
            reload_ui()
        end
    },

    Field = {
        ui = function(id, left, top, width)
            local form = "label["..left+1.8 ..","..top ..";-  FIELD  -]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+1) ..
            ui_position("LEFT", widgets[id].left, left, top+1.7, "LEFT", widgets[id].left_type) ..
            ui_position("TOP", widgets[id].top, left, top+2.7, "TOP", widgets[id].top_type) ..
            ui_position("RIGHT", widgets[id].right, left, top+3.7, "LEFT", widgets[id].right_type) ..
            ui_field("LABEL", widgets[id].label, left+0.2, top+5) ..
            ""
            if widgets[id].password then
                form = form.."checkbox["..left+0.1 ..","..top+5.3 ..";password_box;password;true]" ..
                "checkbox["..left+0.1 ..","..top+5.7 ..";enter_close_box;close form on enter;"..tostring(widgets[id].enter_close).."]"
            else
                form = form..
                ui_field("DEFAULT", widgets[id].default, left+0.2, top+6, widgets[id].default_param) ..
                "checkbox["..left+0.1 ..","..top+6.3 ..";password_box;password;false]" ..
                "checkbox["..left+0.1 ..","..top+6.7 ..";enter_close_box;close form on enter;"..tostring(widgets[id].enter_close).."]"
            end

            return form
        end,
        func = function(id, fields)
            handle_position_changes(id, fields)
            handle_field_changes({"name", "label", "default"}, id, fields)
            if fields.password_box then
                widgets[id].password = fields.password_box == "true"

            elseif fields.enter_close_box then
                widgets[id].enter_close = fields.enter_close_box == "true"
            end
            reload_ui()
        end
    },

    TextArea = {
        ui = function(id, left, top, width)
            local form = "label["..left+1.8 ..","..top ..";-  TextArea  -]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+1) ..
            ui_position("LEFT", widgets[id].left, left, top+1.7, "LEFT", widgets[id].left_type) ..
            ui_position("TOP", widgets[id].top, left, top+2.7, "TOP", widgets[id].top_type) ..
            ui_position("RIGHT", widgets[id].right, left, top+3.7, "LEFT", widgets[id].right_type) ..
            ui_position("BOTTOM", widgets[id].bottom, left, top+4.7, "TOP", widgets[id].bottom_type) ..
            ui_field("LABEL", widgets[id].label, left+0.2, top+6) ..
            ui_field("DEFAULT", widgets[id].default, left+0.2, top+7, widgets[id].default_param) ..
            ""

            return form
        end,
        func = function(id, fields)
            handle_position_changes(id, fields)
            handle_field_changes({"name", "label", "default"}, id, fields)
            reload_ui()
        end
    },

    Label = {
        ui = function(id, left, top, width)
            local form = "label["..left+2 ..","..top ..";-  Label  -]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+1) ..
            ui_position("LEFT", widgets[id].left, left, top+1.7, "LEFT", widgets[id].left_type) ..
            ui_position("TOP", widgets[id].top, left, top+2.7, "TOP", widgets[id].top_type) ..
            ui_field("LABEL", widgets[id].label, left+0.2, top+4, widgets[id].label_param) ..
            "checkbox["..left+0.1 ..","..top+4.3 ..";vert_box;vertical;"..tostring(widgets[id].vertical).."]"

            return form
        end,
        func = function(id, fields)
            handle_position_changes(id, fields)
            handle_field_changes({"name", "label"}, id, fields)
            if fields.vert_box then
                widgets[id].vertical = fields.vert_box == "true"
            end
            reload_ui()
        end
    },

    TextList = {
        ui = function(id, left, top, width)

            local item_str = ""
            for i, v in pairs(widgets[id].items) do
                item_str = item_str .. form_esc(v) .. ","
            end

            local form = "label["..left+1.8 ..","..top ..";-  TextList  -]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+1) ..
            ui_position("LEFT", widgets[id].left, left, top+1.7, "LEFT", widgets[id].left_type) ..
            ui_position("TOP", widgets[id].top, left, top+2.7, "TOP", widgets[id].top_type) ..
            ui_position("RIGHT", widgets[id].right, left, top+3.7, "LEFT", widgets[id].right_type) ..
            ui_position("BOTTOM", widgets[id].bottom, left, top+4.7, "TOP", widgets[id].bottom_type) ..
            "label["..left+0.1 ..","..top+5.4 ..";ITEMS]" ..
            "textlist["..left+0.1 ..","..top+5.75 ..";2.6,0.7;item_list;"..item_str.."]" ..
            "field["..left+3.3 ..","..top+6 ..";1.8,1;item_input;;]" ..
            "field_close_on_enter[item_input;false]" ..
            "checkbox["..left+0.1 ..","..top+6.3 ..";items_param_box;items parameter;"..tostring(widgets[id].items_param).."]" ..
            "checkbox["..left+0.1 ..","..top+6.7 ..";item_id_param_box;selected item id parameter;"..tostring(widgets[id].item_id_param).."]" ..
            "checkbox["..left+3 ..","..top+6.7 ..";transparent_box;transparent;"..tostring(widgets[id].transparent).."]" ..

            ""

            return form
        end,
        func = function(id, fields)
            handle_position_changes(id, fields)
            handle_field_changes({"name"}, id, fields)
            if fields.item_list then  -- common (lazy) way I make editable lists
                if string.sub(fields.item_list, 1, 3) == "DCL" then  -- remove
                    table.remove(widgets[id].items, tonumber(string.sub(fields.item_list, 5)))
                end
            elseif fields.key_enter_field == "item_input" then  -- add
                table.insert(widgets[id].items, fields.item_input)

            elseif fields.items_param_box then
                widgets[id].items_param = fields.items_param_box == "true"

            elseif fields.item_id_param_box then
                widgets[id].item_id_param = fields.item_id_param_box == "true"

            elseif fields.transparent_box then
                widgets[id].transparent = fields.transparent_box == "true"
            end
            reload_ui()
        end
    },

    DropDown = {
        ui = function(id, left, top, width)

            local item_str = ""
            for i, v in pairs(widgets[id].items) do
                item_str = item_str .. form_esc(v) .. ","
            end

            local form = "label["..left+1.8 ..","..top ..";-  DropDown  -]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+1) ..
            ui_position("LEFT", widgets[id].left, left, top+1.7, "LEFT", widgets[id].left_type) ..
            ui_position("TOP", widgets[id].top, left, top+2.7, "TOP", widgets[id].top_type) ..
            ui_position("RIGHT", widgets[id].right, left, top+3.7, "LEFT", widgets[id].right_type) ..
            "label["..left+0.1 ..","..top+4.4 ..";ITEMS]" ..
            "label["..left+1.8 ..","..top+4.4 ..";selected: "..widgets[id].select_id.."]" ..
            "textlist["..left+0.1 ..","..top+4.75 ..";2.6,0.7;item_list;"..item_str.."]" ..
            "field["..left+3.3 ..","..top+5 ..";1.8,1;item_input;;]" ..
            "field_close_on_enter[item_input;false]" ..
            "checkbox["..left+0.1 ..","..top+5.3 ..";items_param_box;items parameter;"..tostring(widgets[id].items_param).."]" ..
            "checkbox["..left+0.1 ..","..top+5.7 ..";item_id_param_box;selected item id parameter;"..tostring(widgets[id].item_id_param).."]" ..

            ""

            return form
        end,
        func = function(id, fields)
            handle_position_changes(id, fields)
            handle_field_changes({"name"}, id, fields)
            if fields.item_list then
                if string.sub(fields.item_list, 1, 3) == "DCL" then
                    table.remove(widgets[id].items, tonumber(string.sub(fields.item_list, 5)))
                else
                    widgets[id].select_id = tonumber(string.sub(fields.item_list, 5))
                end
            elseif fields.key_enter_field == "item_input" then
                table.insert(widgets[id].items, fields.item_input)

            elseif fields.items_param_box then
                widgets[id].items_param = fields.items_param_box == "true"

            elseif fields.item_id_param_box then
                widgets[id].item_id_param = fields.item_id_param_box == "true"
            end
            reload_ui()
        end
    },

    CheckBox = {
        ui = function(id, left, top, width)
            local form = "label["..left+2 ..","..top ..";-  Label  -]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+1) ..
            ui_position("LEFT", widgets[id].left, left, top+1.7, "LEFT", widgets[id].left_type) ..
            ui_position("TOP", widgets[id].top, left, top+2.7, "TOP", widgets[id].top_type) ..
            ui_field("LABEL", widgets[id].label, left+0.2, top+4) ..
            "checkbox["..left+0.1 ..","..top+4.3 ..";checked_box;checked;"..tostring(widgets[id].checked).."]" ..
            "checkbox["..left+0.1 ..","..top+4.7 ..";checked_param_box;checked parameter;"..tostring(widgets[id].checked_param).."]"

            return form
        end,
        func = function(id, fields)
            handle_position_changes(id, fields)
            handle_field_changes({"name", "label"}, id, fields)
            if fields.checked_box then
                widgets[id].checked = fields.checked_box == "true"

            elseif fields.checked_param_box then
                widgets[id].checked_param = fields.checked_param_box == "true"
            end
            reload_ui()
        end
    },

    Box = {
        ui = function(id, left, top, width)
            local form = "label["..left+1.8 ..","..top ..";-  Box  -]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+1) ..
            ui_position("LEFT", widgets[id].left, left, top+1.7, "LEFT", widgets[id].left_type) ..
            ui_position("TOP", widgets[id].top, left, top+2.7, "TOP", widgets[id].top_type) ..
            ui_position("RIGHT", widgets[id].right, left, top+3.7, "LEFT", widgets[id].right_type) ..
            ui_position("BOTTOM", widgets[id].bottom, left, top+4.7, "TOP", widgets[id].bottom_type) ..
            ui_field("COLOUR", widgets[id].colour, left+0.2, top+6, widgets[id].colour_param) ..
            ""

            return form
        end,
        func = function(id, fields)
            handle_position_changes(id, fields)
            handle_field_changes({"name", "colour"}, id, fields)
            reload_ui()
        end
    },

    Image = {
        ui = function(id, left, top, width)
            local form = "label["..left+1.8 ..","..top ..";-  Image  -]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+1) ..
            ui_position("LEFT", widgets[id].left, left, top+1.7, "LEFT", widgets[id].left_type) ..
            ui_position("TOP", widgets[id].top, left, top+2.7, "TOP", widgets[id].top_type) ..
            ui_position("RIGHT", widgets[id].right, left, top+3.7, "LEFT", widgets[id].right_type) ..
            ui_position("BOTTOM", widgets[id].bottom, left, top+4.7, "TOP", widgets[id].bottom_type) ..
            ui_field("IMAGE", widgets[id].image, left+0.2, top+6, widgets[id].image_param) ..
            "checkbox["..left+0.1 ..","..top+6.3 ..";item_box;item;"..tostring(widgets[id].item).."]" ..
            ""

            if not widgets[id].item then
                form = form .. "checkbox["..left+1.5 ..","..top+6.3 ..";back_box;background;"..tostring(widgets[id].background).."]"
                if widgets[id].background then
                    form = form .. "checkbox["..left+1.5 ..","..top+6.7 ..";fill_box;fill;"..tostring(widgets[id].fill).."]"
                end
            end

            return form
        end,
        func = function(id, fields)
            handle_position_changes(id, fields)
            handle_field_changes({"name", "image"}, id, fields)
            if fields.item_box then
                widgets[id].item = fields.item_box == "true"
            elseif fields.back_box then
                widgets[id].background = fields.back_box == "true"
            elseif fields.fill_box then
                widgets[id].fill = fields.fill_box == "true"
            end
            reload_ui()
        end
    },

    Slider = {
        ui = function(id, left, top, width)
            local form = "label["..left+1.8 ..","..top ..";-  Slider  -]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+1) ..
            ui_position("LEFT", widgets[id].left, left, top+1.7, "LEFT", widgets[id].left_type) ..
            ui_position("TOP", widgets[id].top, left, top+2.7, "TOP", widgets[id].top_type) ..
            ui_position("RIGHT", widgets[id].right, left, top+3.7, "LEFT", widgets[id].right_type) ..
            ui_position("BOTTOM", widgets[id].bottom, left, top+4.7, "TOP", widgets[id].bottom_type) ..
            ui_position("VALUE", widgets[id].value, left, top+5.7) ..
            "checkbox["..left+3 ..","..top+5.7 ..";value_param_box;parameter;"..tostring(widgets[id].value_param).."]" ..
            "dropdown["..left+0.1 ..","..top+6.7 ..";2,1;orientation;horizontal,vertical;"..(widgets[id].vertical and 2 or 1).."]" ..
            ""

            return form
        end,
        func = function(id, fields)
            handle_position_changes(id, fields, {value=1000})
            handle_field_changes({"name"}, id, fields)
            if fields.value_param_box then
                widgets[id].value_param = fields.value_param_box == "true"
            elseif fields.orientation then
                local new = fields.orientation == "vertical"
                if widgets[id].vertical ~= new then  -- swaps the width and height to make it nicer to edit
                    widgets[id].vertical = new
                    widgets[id].right, widgets[id].bottom = widgets[id].bottom, widgets[id].right
                end
            end
            reload_ui()
        end
    },

    InvList = {
        ui = function(id, left, top, width)
            local location_values = {context=1, current_player=2, ["player:"]=3, ["nodemeta:"]=4, ["detached:"]=5}
            local form = "label["..left+1.4 ..","..top ..";-  Inventory List  -]" ..
            ui_position("LEFT", widgets[id].left, left, top+0.7, "LEFT", widgets[id].left_type) ..
            ui_position("TOP", widgets[id].top, left, top+1.7, "TOP", widgets[id].top_type) ..
            ui_position("RIGHT", widgets[id].right, left, top+2.7, "LEFT", widgets[id].right_type) ..
            ui_position("BOTTOM", widgets[id].bottom, left, top+3.7, "TOP", widgets[id].bottom_type) ..
            "label["..left+0.1 ..","..top+4.4 ..";LOCATION]" ..
            "dropdown["..left+0.1 ..","..top+4.75 ..";2.8;location_select;context,current_player,player:,nodemeta:,detached:;" .. location_values[widgets[id].location].."]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+6) ..
            "field["..left+0.4 ..","..top+7 ..";1,1;start;START;"..widgets[id].start.."]" ..
            "field_close_on_enter[start;false]" ..
            "checkbox["..left+1.5 ..","..top+6.7 ..";start_box;param;"..tostring(widgets[id].start_param).."]" ..
            "checkbox["..left+3 ..","..top+5.9 ..";ring_box;ring;"..tostring(widgets[id].ring).."]"


            local extras = {["player:"]=1, ["nodemeta:"]=1, ["detached:"]=1}  -- these locations need extra data
            if extras[widgets[id].location] then
                form = form .. "field["..left+3.3 ..","..top+5 ..";1.7,1;data;DATA;"..form_esc(widgets[id].data).."]" ..
                "field_close_on_enter[data;false]" ..
                "checkbox["..left+3 ..","..top+5.5 ..";data_box;data param;"..tostring(widgets[id].data_param).."]"
            end
            return form
        end,
        func = function(id, fields)
            handle_position_changes(id, fields)
            handle_field_changes({"name"}, id, fields)
            if fields.ring_box then
                widgets[id].ring= fields.ring_box == "true"
            elseif fields.start_box then
                widgets[id].start_param = fields.start_box == "true"
            elseif fields.data_box then
                widgets[id].data_param = fields.data_box == "true"
            elseif fields.key_enter_field == "data" then
                widgets[id].data = fields.data
            elseif fields.key_enter_field == "start" then
                widgets[id].start = tonumber(fields.start)
                if widgets[id].start == nil then
                    widgets[id].start = 0
                end

            elseif fields.location_select then
                widgets[id].location = fields.location_select
            end
            reload_ui()
        end
    },

    Tooltip = {
        ui = function(id, left, top, width)
            local form = "label["..left+1.7 ..","..top ..";-  Tooltip  -]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+1) ..
            ui_field("TEXT", widgets[id].text, left+0.2, top+2) ..
            ""

            if widgets[id].colours then
                form = form .. "field["..left+0.4 ..","..top+3 ..";2.8,1;bg;BACKGROUND;"..form_esc(widgets[id].bg).."]" ..
                "field_close_on_enter[bg;false]" ..
                "field["..left+0.4 ..","..top+4 ..";2.8,1;fg;TEXT COLOUR;"..form_esc(widgets[id].fg).."]" ..
                "field_close_on_enter[fg;false]" ..
                "checkbox["..left+0.12 ..","..top+4.4 ..";col_box;colours;true]"
            else
                form = form .. "checkbox["..left+0.12 ..","..top+2.4 ..";col_box;colours;false]"
            end

            return form
        end,
        func = function(id, fields)
            handle_field_changes({"name", "text"}, id, fields)

            if fields.key_enter_field == "bg" then
                widgets[id].bg = fields.bg
            elseif fields.key_enter_field == "fg" then
                widgets[id].fg = fields.fg
            elseif fields.col_box then
                widgets[id].colours = fields.col_box == "true"
            end

            reload_ui()
        end
    },

    Table = {
        ui = function(id, left, top, width)
            local column_str = ""
            for i, v in pairs(widgets[id].columns) do
                column_str = column_str..","..i..": "..v.type
            end
            local form = "label["..left+1.8 ..","..top ..";-  Table  -]" ..
            "textlist["..left+0.1 ..","..top+0.4 ..";2.5,1.5;column_select;#ffff00DATA,#ffff00- columns: "..column_str..";"..widgets[id].selected_column+2 ..";]" ..
            "button["..left+2.7 ..","..top+0.3 ..";0.5,1;column_up;/\\\\]" ..
            "button["..left+2.7 ..","..top+1.15 ..";0.5,1;column_down;\\\\/]" ..
            "button["..left+3.1 ..","..top+0.3 ..";0.8,1;column_add;+]" ..
            "button["..left+3.1 ..","..top+1.15 ..";0.8,1;column_remove;-]"

            if widgets[id].selected_column == -1 then  -- the data tab (size, name, etc)
                form = form .. ui_field("NAME", widgets[id].name, left+0.2, top+2.5) ..
                ui_position("LEFT", widgets[id].left, left, top+3.2, "LEFT", widgets[id].left_type) ..
                ui_position("TOP", widgets[id].top, left, top+4.2, "TOP", widgets[id].top_type) ..
                ui_position("RIGHT", widgets[id].right, left, top+5.2, "LEFT", widgets[id].right_type) ..
                ui_position("BOTTOM", widgets[id].bottom, left, top+6.2, "TOP", widgets[id].bottom_type) ..
                "checkbox["..left+0.1 ..","..top+6.9 ..";select_param_box;selected item param;"..tostring(widgets[id].select_param).."]"

            elseif widgets[id].selected_column > 0 then  -- item controller
                local c = widgets[id].columns[widgets[id].selected_column]
                typ_convt = {text=1, image=2, color=3, indent=4, tree=5}
                local items_str = ""
                for i, v in pairs(c.items) do
                    items_str = items_str..i..": "..v..","
                end
                form = form .. "label["..left+0.1 ..","..top+1.9 ..";TYPE]" ..
                "dropdown["..left+0.1 ..","..top+2.3 ..";2.7,1;column_type;text,image,color,indent,tree;"..typ_convt[c.type].."]" ..
                "label["..left+0.1 ..","..top+2.9 ..";ITEMS]" ..
                "textlist["..left+0.1 ..","..top+3.3 ..";2.5,1.5;item_lst;"..items_str..";".. c.selected_item..";]" ..
                "button["..left+2.7 ..","..top+3.2 ..";0.5,1;item_up;/\\\\]" ..
                "button["..left+2.7 ..","..top+4.05 ..";0.5,1;item_down;\\\\/]" ..
                "button["..left+3.1 ..","..top+3.2 ..";0.8,1;item_add;+]" ..
                "button["..left+3.1 ..","..top+4.05 ..";0.8,1;item_remove;-]" ..
                "checkbox["..left+2.7 ..","..top+4.6 ..";item_param_box;items parameter;"..tostring(c.items_param).."]"

                if #c.items > 0 then  -- item editor
                    form = form .. "field["..left+0.4 ..","..top+5.4 ..";2.5,1;item_edit;ITEM;"..c.items[c.selected_item].."]" ..
                    "field_close_on_enter[item_edit;false]"

                    -- some column types need extra stuff
                    if c.type == "image" then  -- image
                        local img_str = ""
                        for i, v in pairs(c.images) do
                            img_str = img_str..i ..": "..v..","
                        end
                        form = form .. "label["..left+0.1 ..","..top+5.8 ..";IMAGES]" ..
                        "textlist["..left+0.1 ..","..top+6.2 ..";2.5,1.4;image_lst;"..img_str.."]" ..
                        "field["..left+3 ..","..top+6.4 ..";2,1;image_add;;]" ..
                        "field_close_on_enter[image_add;false]"
                    elseif c.type == "color" then  -- colour
                        form = form .. "field["..left+0.4 ..","..top+6.4 ..";2.5,1;colour_len;DISTANCE;"..c.distance.."]" ..
                        "field_close_on_enter[colour_len;false]"
                    end
                end
            end

            return form
        end,
        func = function(id, fields)
            -- basic stuff
            handle_position_changes(id, fields)
            handle_field_changes({"name"}, id, fields)
            local number_usrs = {indent=1, tree=1, image=1}
            local c = widgets[id].columns[widgets[id].selected_column]

            -- column selector and editor
            if fields.column_select then
                widgets[id].selected_column = tonumber(string.sub(fields.column_select, 5))-2
            elseif fields.column_add then  -- column def
                table.insert(widgets[id].columns, {type="text", items={}, images={}, selected_item=1, items_param=false, distance="infinite"})
                widgets[id].selected_column = #widgets[id].columns
            elseif fields.column_remove and widgets[id].selected_column > 0 then
                table.remove(widgets[id].columns, widgets[id].selected_column)
                widgets[id].selected_column = widgets[id].selected_column-1
            elseif fields.column_down and widgets[id].selected_column < #widgets[id].columns and widgets[id].selected_column > 0 then
                table.insert(widgets[id].columns, widgets[id].selected_column+1, table.remove(widgets[id].columns, widgets[id].selected_column))
                widgets[id].selected_column = widgets[id].selected_column+1
            elseif fields.column_up and widgets[id].selected_column > 1 then
                table.insert(widgets[id].columns, widgets[id].selected_column-1, table.remove(widgets[id].columns, widgets[id].selected_column))
                widgets[id].selected_column = widgets[id].selected_column-1

            elseif fields.select_param_box then
                widgets[id].select_param = fields.select_param_box == "true"

            -- item editor
            elseif fields.item_lst then
                c.selected_item = tonumber(string.sub(fields.item_lst, 5))
                if c.selected_item > #c.items then
                    c.selected_item = #c.items
                end
            elseif fields.item_add then
                if number_usrs[c.type] then
                    table.insert(c.items, 0)
                else
                    table.insert(c.items, "-")
                end
                c.selected_item = #c.items
            elseif fields.item_remove then
                table.remove(c.items, c.selected_item)
                if c.selected_item > 1 then
                    c.selected_item = c.selected_item-1
                end
            elseif fields.item_down and c.selected_item < #c.items then
                table.insert(c.items, c.selected_item+1, table.remove(c.items, c.selected_item))
                c.selected_item = c.selected_item+1
            elseif fields.item_up and c.selected_item > 1 then
                table.insert(c.items, c.selected_item-1, table.remove(c.items, c.selected_item))
                c.selected_item = c.selected_item-1

            elseif fields.item_param_box then
                c.items_param = fields.item_param_box == "true"

            elseif fields.key_enter_field == "item_edit" then
                c.items[c.selected_item] = fields.item_edit
                if number_usrs[c.type] then
                    c.items[c.selected_item] = tonumber(fields.item_edit)
                    if c.items[c.selected_item] == nil then
                        c.items[c.selected_item] = 0
                    end
                    c.items[c.selected_item] = math.floor(c.items[c.selected_item])
                end

            -- extra things for column types
            elseif fields.key_enter_field == "image_add" then
                table.insert(c.images, fields.image_add)
            elseif fields.image_lst and string.sub(fields.image_lst, 1, 3) == "DCL" then
                table.remove(c.images, tonumber(string.sub(fields.image_lst, 5)))

            elseif fields.colour_len then
                c.distance = tonumber(fields.colour_len)
                if c.distance == nil or c.distance <= 0 then
                    c.distance = "infinite"
                else
                    c.distance = math.floor(c.distance)
                end

            elseif fields.column_type then
                c.type = fields.column_type
                if number_usrs[c.type] then
                    for i, v in pairs(c.items) do
                        c.items[i] = tonumber(v)
                        if c.items[i] == nil then
                            c.items[i] = 0
                        end
                    end
                end
            end
            reload_ui()
        end
    },

    ["Container - Start"] = {
        ui = function(id, left, top, width)
            local form = "label["..left+1.8 ..","..top ..";-  Container  -]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+1) ..
            "label["..left+3.8 ..","..top+1.4 ..";parameter]" ..
            ui_position("LEFT", widgets[id].left, left, top+1.7, "LEFT", widgets[id].left_type) ..
            "checkbox["..left+4.2 ..","..top+1.7 ..";left_param_box;;"..tostring(widgets[id].left_param).."]" ..
            ui_position("TOP", widgets[id].top, left, top+2.7, "TOP", widgets[id].top_type) ..
            "checkbox["..left+4.2 ..","..top+2.7 ..";top_param_box;;"..tostring(widgets[id].top_param).."]" ..
            ui_position("RIGHT", widgets[id].right, left, top+3.7, "LEFT", widgets[id].right_type) ..
            ui_position("BOTTOM", widgets[id].bottom, left, top+4.7, "TOP", widgets[id].bottom_type) ..

            ""

            return form
        end,
        func = function(id, fields)
            handle_position_changes(id, fields)
            handle_field_changes({"name"}, id, fields)

            if fields.left_param_box then
                widgets[id].left_param = fields.left_param_box == "true"

            elseif fields.top_param_box then
                widgets[id].top_param = fields.top_param_box == "true"
            end

            reload_ui()
        end,
        del = function(id)
            table.remove(widgets, id)
            local depth = 0
            while id <= #widgets and depth > -1 do  -- find which container end belongs to this container and delete it too
                if widgets[id].type == "Container - Start" then
                    depth = depth+1
                elseif widgets[id].type == "Container - End" then
                    if depth == 0 then
                        table.remove(widgets, id)
                    end
                    depth = depth-1
                end
                id = id+1
            end
        end
    },

    ["Container - End"] = {
        ui = function(id, left, top, width)
            local name = ""
            local depth = 0
            local pos = id-1
            while pos > 0 and depth > -1 do  -- find which container start belongs to this container and display it's name
                if widgets[pos].type == "Container - Start" then
                    if depth == 0 then
                        name = widgets[pos].name
                    end
                    depth = depth-1
                elseif widgets[pos].type == "Container - End" then
                    depth = depth+1
                end
                pos = pos-1
            end
            local form = "label["..left+0.1 ..","..top+1 ..";-  End of Container \""..form_esc(name).."\"  -]" ..

            ""

            return form
        end,
        func = function(id, fields)
            -- ehem?
        end
    },

    Tabs = {
        ui =function(id, left, top, width)
            local item_str = ""
            for i, v in pairs(widgets[id].captions) do
                item_str = item_str .. form_esc(v) .. ","
            end

            local form = "label["..left+1.9 ..","..top ..";-  Tabs  -]" ..
            ui_field("NAME", widgets[id].name, left+0.2, top+1) ..
            ui_position("LEFT", widgets[id].left, left, top+1.7, "LEFT", widgets[id].left_type) ..
            ui_position("TOP", widgets[id].top, left, top+2.7, "TOP", widgets[id].top_type) ..
            "label["..left+0.1 ..","..top+3.4 ..";TABS]" ..
            "label["..left+1.8 ..","..top+3.4 ..";selected: "..widgets[id].tab.."]" ..
            "textlist["..left+0.1 ..","..top+3.75 ..";2.6,0.7;item_list;"..item_str.."]" ..
            "field["..left+3.3 ..","..top+4 ..";1.8,1;item_input;;]" ..
            "field_close_on_enter[item_input;false]" ..
            "checkbox["..left+0.1 ..","..top+4.3 ..";transparent_box;transparent;"..tostring(widgets[id].transparent).."]" ..
            "checkbox["..left+0.1 ..","..top+4.7 ..";border_box;border;"..tostring(widgets[id].border).."]" ..

            ""

            return form
        end,
        func = function(id, fields)
            handle_position_changes(id, fields)
            handle_field_changes({"name"}, id, fields)
            if fields.item_list then
                if string.sub(fields.item_list, 1, 3) == "DCL" then
                    table.remove(widgets[id].captions, tonumber(string.sub(fields.item_list, 5)))
                else
                    widgets[id].tab = tonumber(string.sub(fields.item_list, 5))
                end
            elseif fields.key_enter_field == "item_input" then
                table.insert(widgets[id].captions, fields.item_input)

            elseif fields.transparent_box then
                widgets[id].transparent = fields.transparent_box == "true"

            elseif fields.border_box then
                widgets[id].border = fields.border_box == "true"
            end
            reload_ui()
        end
    },

    Options = {
        ui = function(id, left, top, width)
            local form = "label["..left+1.8 ..","..top ..";-  Options  -]" ..
            "button["..left+0.1 ..","..top+1 ..";2,1;func_create;generate function]" ..
            "button["..left+2.1 ..","..top+1 ..";2,1;string_create;generate string]" ..
            ""

            return form
        end,
        func = function(id, fields)
            if fields.string_create then  -- display the formspec to output the generated string (and generate it)
                minetest.show_formspec("ui_editor:output",
                "size[10,8]" ..
                "textarea[1,1;9,7;_;Generated Code;"..form_esc(generate_string()).."]" ..
                "button[8.8,0;1,1;back;back]")
            elseif fields.func_create then  -- display the (same) formspec to output the generated function (and generate it)
                minetest.show_formspec("ui_editor:output",
                "size[10,8]" ..
                "textarea[1,1;9,7;_;Generated Code;"..form_esc(generate_function()).."]" ..
                "button[8.8,0;1,1;back;back]")
            end
        end
    },

    New = {
        ui = function(id, left, top, width)
            local widg_str = ""  -- convert the list of widget types to a string
            for i, v in pairs(widg_list) do
                widg_str = widg_str..v..","
            end
            local form = "label["..left+1.6 ..","..top ..";-  NEW WIDGET  -]" ..
            "textlist["..left+0.1 ..","..top+0.4 ..";"..width-0.2 ..",6;new_widg_selector;"..widg_str.."]"

            return form
        end,
        func = function(id, fields)
            if fields.new_widg_selector then
                if string.sub(fields.new_widg_selector, 1, 3) == "DCL" then
                    local name = widg_list[tonumber(string.sub(fields.new_widg_selector, 5))]
                    selected_widget = #widgets +1

                    -- widget defaults --
                    -- create widgets with the correct and default data
                    if name == "Button" then
                        table.insert(widgets, {type="Button", name="New Button", label="New", image=false, image_param=false, texture="default_cloud.png", item=false,
                        left=1, left_type="L+", top=1, top_type="T+", right=2, right_type="L+", bottom=1, bottom_type="R"})

                    elseif name == "Field" then
                        table.insert(widgets,
                        {type="Field", name="New Field", label="", default="", default_param=false, password=false, enter_close=true,
                        left=1, left_type="L+", top=1, top_type="T+", right=2, right_type="L+", bottom=1, bottom_type="R"})

                    elseif name == "TextArea" then
                        table.insert(widgets, {type="TextArea", name="New TextArea", label="", default="", default_param=false,
                        left=1, left_type="L+", top=1, top_type="T+", right=2, right_type="L+", bottom=2, bottom_type="T+"})

                    elseif name == "Label" then
                        table.insert(widgets, {type="Label", name="New Label", label="New Label", label_param=false, vertical=false,
                        left=1, left_type="L+", top=1, top_type="T+"})

                    elseif name == "TextList" then
                        table.insert(widgets,
                        {type="TextList", name="New TextList", items={}, items_param=false, item_id_param=false, transparent=false,
                        left=1, left_type="L+", top=1, top_type="T+", right=2, right_type="L+", bottom=2, bottom_type="T+"})

                    elseif name == "DropDown" then
                        table.insert(widgets,
                        {type="DropDown", name="New DropDown", items={}, items_param=false, item_id_param=false, select_id=1,
                        left=1, left_type="L+", top=1, top_type="T+", right=2, right_type="L+", bottom=1, bottom_type="R"})

                    elseif name == "CheckBox" then
                        table.insert(widgets, {type="CheckBox", name="New CheckBox", label="New CheckBox", checked=false, checked_param=false,
                        left=1, left_type="L+", top=1, top_type="T+"})

                    elseif name == "Box" then
                        table.insert(widgets, {type="Box", name="New Box", colour="#ffffff", colour_param=false,
                        left=1, left_type="L+", top=1, top_type="T+", right=2, right_type="L+", bottom=2, bottom_type="T+"})

                    elseif name == "Image" then
                        table.insert(widgets, {type="Image", name="New Image", image="default_cloud.png", image_param=false, item=false,
                        background=false, fill=false,
                        left=1, left_type="L+", top=1, top_type="T+", right=2, right_type="L+", bottom=2, bottom_type="T+"})

                    elseif name == "Slider" then
                        table.insert(widgets, {type="Slider", name="New Slider", vertical=false, value=0, value_param=false,
                        left=1, left_type="L+", top=1, top_type="T+", right=2, right_type="R", bottom=0.3, bottom_type="R"})

                    elseif name == "Table" then
                        table.insert(widgets, {selected_column=-1, type="Table", name="New Table", selected_param=false, columns = {},
                        select_param=false,
                        left=1, left_type="L+", top=1, top_type="T+", right=2, right_type="L+", bottom=2, bottom_type="T+"})

                    elseif name == "InvList" then
                        table.insert(widgets, {type="InvList", name="main", location="current_player", start_param=false, data="",
                        data_param=false, ring=false, colour_tab=false, start=0,
                        left=1, left_type="L+", top=1, top_type="T+", right=2, right_type="L+", bottom=2, bottom_type="T+"})

                    elseif name == "Tooltip" then
                        table.insert(widgets, {type="Tooltip", name="widget", text="New Tooltip", colours=false, bg="#00cc00", fg="#000000"})

                    elseif name == "Container" then
                        table.insert(widgets, {type="Container - Start", name="New container", left_param=false, top_param=false,
                        left=1, left_type="L+", top=1, top_type="T+", right=4, right_type="L+", bottom=4, bottom_type="T+"})
                        table.insert(widgets, {type="Container - End", name=""})

                    elseif name == "Tabs" then
                        table.insert(widgets, {type="Tabs", name="New Tabs", captions={}, tab=1, transparent=false, border=false,
                        left=0, left_type="L+", top=0, top_type="T+"})
                    end

                    new_widg_tab = false
                    reload_ui()
                end
            end
        end
    },

}


----------
-- GENERAL
----------

-- handles formspec input, or sends to correct places
minetest.register_on_formspec_input(function(formname, fields)
    if formname == "ui_editor:main" then
        if fields.widg_select then  -- select a widget
            selected_widget = tonumber(string.sub(fields.widg_select, 5))-4
            new_widg_tab = false
            minetest.show_formspec("ui_editor:main", main_ui_form())

        elseif fields.widg_mov_up then  -- move a widget up
            if selected_widget > 2 then
                if widgets[selected_widget].type == "Container - End" and widgets[selected_widget-1].type == "Container - Start" then
                    local pos = selected_widget-2  -- containers must always make sence. each start must have an end after it,
                    local count = 0  --            -- so they can't move past eachother in some cases
                    while pos > 0 do
                        if widgets[pos].type == "Container - End" then
                            count = count-1
                        elseif widgets[pos].type == "Container - Start" then
                            count = count+1
                        end
                        pos = pos-1
                    end
                    if count <= 0 then return true end
                end
                table.insert(widgets, selected_widget-1, table.remove(widgets, selected_widget))  -- move it
                selected_widget = selected_widget-1
                new_widg_tab = false
                reload_ui()
            end

        elseif fields.widg_mov_dwn then  --move a widget down
            if selected_widget < #widgets and selected_widget > 1 then
                if widgets[selected_widget].type == "Container - Start" and widgets[selected_widget+1].type == "Container - End" then
                    local pos = selected_widget+2  -- containers must have an end after them (and can't share an end)
                    local count = 0
                    while pos <= #widgets do
                        if widgets[pos].type == "Container - End" then
                            count = count+1
                        elseif widgets[pos].type == "Container - Start" then
                            count = count-1
                        end
                        pos = pos+1
                    end
                    if count <= 0 then return true end
                end
                table.insert(widgets, selected_widget+1, table.remove(widgets, selected_widget))
                selected_widget = selected_widget+1
                new_widg_tab = false
                reload_ui()
            end

        elseif fields.widg_duplicate then  -- duplicate a widget
            table.insert(widgets, copy_table(widgets[selected_widget]))
            new_widg_tab = false
            reload_ui()

        elseif fields.widg_new then  -- switch to the NEW WIDGET tab
            new_widg_tab = not new_widg_tab
            reload_ui()

        elseif fields.widg_delete then  -- delete a widget
            if widgets[selected_widget].type == "Container - Start" then
                widget_editor_uis["Container - Start"].del(selected_widget)
            else
                table.remove(widgets, selected_widget)
            end
            selected_widget = selected_widget-1
            new_widg_tab = false
            reload_ui()

        elseif fields.quit == nil then  -- send update to widget editors
            if selected_widget == -2 or new_widg_tab then
                widget_editor_uis["New"].func(selected_widget, fields)
            elseif selected_widget > 0 then
                widget_editor_uis[widgets[selected_widget].type].func(selected_widget, fields)
                new_widg_tab = false
            elseif selected_widget == -3 then
                widget_editor_uis["Options"].func(selected_widget, fields)
                new_widg_tab = false
            end
        end

    elseif formname == "ui_editor:output" then  -- the display for outputting generated code
        if fields.back then
            reload_ui()
        end
    end
end)

-- loads the correct widget editor
local function widget_editor(left, height)
    local form = "box["..left+0.1 ..",2.2;4.8,"..height-2.3 ..";#000000]"
    if selected_widget == -1 or selected_widget == 0 or (selected_widget > 1 and widgets[selected_widget] == nil) then
        selected_widget = -2  -- blank items in the list can be used for adding new widgets
    end
    if selected_widget == -2 or new_widg_tab then  -- the new widget tab can be displayed without moving the selection
        form = form .. widget_editor_uis["New"].ui(selected_widget, left+0.1, 2.2, 4.8)
    elseif selected_widget > 0 then  -- load correct editor for current selected widget
        form = form .. widget_editor_uis[widgets[selected_widget].type].ui(selected_widget, left+0.1, 2.2, 4.8)
    elseif selected_widget == -3 then
        form = form .. widget_editor_uis["Options"].ui(selected_widget, left+0.1, 2.2, 4.8)
    end
    return form
end

-- creates the widget selector
local function widget_chooser(left)
    local widget_str = "OPTIONS,NEW WIDGET,,.....,"  -- options at the top of the list
    local depth = 0
    for i, v in pairs(widgets) do
        if v.type == "Container - End" then  -- the order of end and start are because they do not need indenting
            depth = depth-1
        end
        widget_str = widget_str .. string.rep("- ", depth) .. form_esc(v.type .. ":    " .. v.name) .. ","
        if v.type == "Container - Start" then  -- container contents gets indented
            depth = depth+1
        end
    end

    local form = ""..

    "textlist["..left+0.1 ..",0.1;3.4,2;widg_select;"..widget_str..";"..selected_widget+4 .."]" ..
    "button["..left+3.6 ..",0.1;0.5,1;widg_mov_up;"..form_esc("/\\").."]" ..
    "button["..left+3.6 ..",1.2;0.5,1;widg_mov_dwn;"..form_esc("\\/").."]"

    if selected_widget > 1 and selected_widget <= #widgets and widgets[selected_widget].type ~= "Container - End" then
        form = form .. "button["..left+4 ..",0;1,1;widg_duplicate;DUPLICATE]" ..
        "button["..left+4 ..",0.7;1,1;widg_delete;DELETE]" ..
        "button["..left+4 ..",1.4;1,1;widg_new;NEW]"
    end

    return form
end

-- puts the whole formspec together
main_ui_form = function ()
    local ui, width, height = generate_ui()  -- the preview

    local w_selector = widget_chooser(width-5)  -- the widget selector

    local w_editor = widget_editor(width-5, height)  -- the widget editor

    local form = ""..  -- add everything together
    "size["..width..","..height.."]" ..
    "box["..width-5 ..",0;5,"..height..";#ffffff]" ..
    ui .. w_selector .. w_editor .. create_tabs(2)  -- add the global tabs

    return form
end


---------- ----------
-- END FORM EDITOR --
---------- ----------



----------            ----------
-- PASTE FORMSPEC EDITOR HERE --
----------            ----------




----------
-- UI FUNCTIONALITY
----------

minetest.register_on_formspec_input(function(formname, fields)
        -- FILE VIEWER
    ----------
    if formname == "files:viewer" then
        if fields.del_lua then
            name = lua_files[selected_files[1] ]
            table.remove(lua_files, selected_files[1])
            files_str = ""
            for i, v in pairs(lua_files) do
                if v ~= "" then
                    files_str = files_str..v..","  -- remove the file from the list
                end
            end

            if name == saved_file then  -- clear the editing area if the file was loaded
                saved_file = false
                modstorage:set_string("_lua_saved", "")
                save_lua("")
            end

            modstorage:set_string("_lua_files_list", files_str)
            minetest.show_formspec("files:viewer", file_viewer())

        elseif fields.del_ui then
            name = ui_files[selected_files[2] ]
            table.remove(ui_files, selected_files[2])
            files_str = ""
            for i, v in pairs(ui_files) do
                if v ~= "" then
                    files_str = files_str..v..","  -- remove the file from the list
                end
            end

            if name == current_ui_file then  -- clear the editing area if the file was loaded
                load_UI("new")
            end

            modstorage:set_string("_UI_files_list", files_str)
            minetest.show_formspec("files:viewer", file_viewer())

        elseif fields.lua_select then  -- click on a file to select it, double click to open it
            local index = tonumber(string.sub(fields.lua_select, 5))
            if string.sub(fields.lua_select, 1, 3) == "DCL" then
                saved_file = lua_files[index]

                modstorage:set_string("_lua_saved", saved_file)
                minetest.show_formspec("lua:editor", lua_editor())
            else
                selected_files[1] = index
                minetest.show_formspec("files:viewer", file_viewer())
            end

        elseif fields.ui_select then  -- click on a file to select it, double click to open it
            local index = tonumber(string.sub(fields.ui_select, 5))
            if string.sub(fields.ui_select, 1, 3) == "DCL" then
                load_UI(ui_files[index])
                reload_ui()
            else
                selected_files[2] = index
                minetest.show_formspec("files:viewer", file_viewer())
            end

        elseif fields.key_enter_field == "new_lua" or fields.add_lua then
            local exist = false
            for i, v in pairs(lua_files) do
                if v == fields.new_lua then
                    exist = true
                    selected_files[1] = i
                end
            end
            if not exist then
                table.insert(lua_files, fields.new_lua)
                selected_files[1] = #lua_files

                files_str = ""
                for i, v in pairs(lua_files) do
                    if v ~= "" then
                        files_str = files_str..v..","
                    end
                end
                modstorage:set_string("_lua_files_list", files_str)
                saved_file = fields.new_lua
                minetest.show_formspec("lua:editor", lua_editor())
            end

        elseif fields.key_enter_field == "new_ui" or fields.add_ui then
            local exist = false
            for i, v in pairs(ui_files) do
                if v == fields.new_ui then
                    exist = true
                    selected_files[2] = i
                end
            end
            if not exist then
                table.insert(ui_files, fields.new_ui)
                selected_files[2] = #ui_files

                files_str = ""
                for i, v in pairs(ui_files) do
                    if v ~= "" then
                        files_str = files_str..v..","
                    end
                end
                modstorage:set_string("_UI_files_list", files_str)
                load_UI(fields.new_ui)
                reload_ui()
            end
        end
    end

    if fields._option_tabs_ then
        if fields._option_tabs_ == "1" then
            minetest.show_formspec("lua:editor", lua_editor())
        elseif fields._option_tabs_ == "2" then
            reload_ui()
        elseif fields._option_tabs_ == "4" then
            minetest.show_formspec("files:viewer", file_viewer())
        elseif fields._option_tabs_ == "5" then
            minetest.show_formspec("lua:startup", startup_form())
        else
            minetest.show_formspec("lua:unknown",
            "size["..data.width..","..data.height.."]label[1,1;COMING SOON]"..create_tabs(fields._option_tabs_))
        end

    end

end)
----------
-- REGISTER COMMAND
----------
core.register_chatcommand("dte", {  -- register the chat command
    description = core.gettext("open a lua IDE"),
    func = function(parameter)
        minetest.show_formspec("lua:editor", lua_editor())
    end,
})
