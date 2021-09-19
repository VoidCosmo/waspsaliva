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


minetest.register_on_connect(function()  -- some functions don't work after startup. this tries to replace them

    minetest.get_mod_storage = function()
        return modstorage
    end
    
    core.get_mod_storage = function()
        return modstorage
    end
    
    -- show formspec
    
end)  -- add whatever functions don't work after startup to here (if possible)


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


--


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

