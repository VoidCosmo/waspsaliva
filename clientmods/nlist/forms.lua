local selected_name = false
local formspec_list = {}
function ws.display_list_formspec(fname,list,funcs)
    funcs={}
    local formspec = 'size[6.25,9]' ..
                     'label[0,0;NodeLists]' ..
                     'button_exit[0,7.5;1,0.5;display;Show]' ..
                     'button[3.625,7.5;1.3,0.5;rename;Rename]' ..
                     'button[4.9375,7.5;1.3,0.5;delete;Delete]'
    local sp=0
    
    for k,v in pairs(funcs) do
        formspec=formspec..'button_exit['..sp..',8.5;1,0.5;'..v.name..';'..v.name..']'
        sp=sp+0.8
    end

    formspec=formspec..'textlist[0,0.75;6,6;marker;'
    local selected = 1
    formspec_list = {}
    if not list then list={} end
    for id, name in ipairs(list) do
        if id > 1 then
            formspec = formspec .. ','
        end
        if not selected_name then
            selected_name = name
        end
        if name == selected_name then
            selected = id
        end
        formspec_list[#formspec_list + 1] = name
        formspec = formspec .. '##' .. minetest.formspec_escape(name)
    end

    formspec = formspec .. ';' .. tostring(selected) .. ']'

    if selected_name then
        local val=list[selected]
        if val then
            formspec = formspec .. 'label[0,6.75;' .. selected_name .. ']'
        end
    else
        formspec = formspec .. 'button_exit[0,7.5;5.25,0.5;quit;Close dialog]' ..
            'label[0,6.75;No Entries.]'
    end

    return minetest.show_formspec(fname, formspec)
end

minetest.register_on_formspec_input(function(formname, fields)
    local fname="NodeLists"
    if formname == 'NodeLists-ignore' then
        return true
    elseif formname ~= "NodeLists" then
        return
    end
    local name = selected_name

    if name then
        for k,v in pairs(autofly.registered_transports) do
            if fields[v.name] then
                if not v.func(autofly.get_waypoint(name),name) then
                    minetest.display_chat_message('Error with '..v.name)
                end
            end
        end
        if fields.display then
            if not autofly.display_waypoint(name) then
                minetest.display_chat_message('Error displaying waypoint!')
            end
        elseif fields.rename then
            minetest.show_formspec(fname, 'size[6,3]' ..
                'label[0.35,0.2;Rename waypoint]' ..
                'field[0.3,1.3;6,1;new_name;New name;' ..
                minetest.formspec_escape(name) .. ']' ..
                'button[0,2;3,1;cancel;Cancel]' ..
                'button[3,2;3,1;rename_confirm;Rename]')
        elseif fields.rename_confirm then
            if fields.new_name and #fields.new_name > 0 then
                if nlist.rename(name, fields.new_name) then
                    selected_name = fields.new_name
                else
                    minetest.display_chat_message('Error renaming!')
                end
                ws.display_list_formspec()
            else
                minetest.display_chat_message('Please enter a new name for the entry.')
            end
        elseif fields.delete then
            minetest.show_formspec(fname, 'size[6,2]' ..
                'label[0.35,0.25;Are you sure you want to delete this waypoint?]' ..
                'button[0,1;3,1;cancel;Cancel]' ..
                'button[3,1;3,1;delete_confirm;Delete]')
        elseif fields.delete_confirm then
            autofly.delete_waypoint(name)
            selected_name = false
            ws.display_list_formspec()
        elseif fields.cancel then
            ws.display_list_formspec()
        elseif name ~= selected_name then
            selected_name = name
            ws.display_list_formspec()
        end
    elseif fields.display or fields.delete then
        minetest.display_chat_message('Please select a waypoint.')
    end
    return true
end)