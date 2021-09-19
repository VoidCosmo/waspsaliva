local last_count
local last_item

local icon_widget
local count_widget

local epoch = 0

local function display_widgets()
    if minetest.localplayer ~= nil then
        if icon_widget == nil then
            icon_widget = minetest.localplayer:hud_add({
                hud_elem_type   = "image",
                name            = "Item count icon",
                scale           = {x = 1, y = 1},
                alignment       = {x = 0.5, y = 1},
                position        = {x = 0.85, y = 0.5}
            })
        end
        if count_widget == nil then
            count_widget = minetest.localplayer:hud_add({
                hud_elem_tyoe   = "text",
                name            = "Item count",
                scale           = {x = 1, y = 1},
                alignment       = {x = 0.5, y = 0},
                position        = {x = 0.85, y = 0.5},
                text            = "0",
                number          = 0xFFFFFF
            })
        end
    end
end

local function update_count()
    if minetest.localplayer ~= nil then
        display_widgets()

        local wielded = minetest.localplayer:get_wielded_item()
        
        local texture = "" --wielded:get_definition().inventory_image

        local wear = wielded:get_wear()
        local count = 0

        local num = ""

        if wear == 0 then
            for k, v in ipairs(minetest.get_inventory("current_player").main) do
                if v:get_name() == wielded:get_name() then
                    count = count + v:get_count()
                end
            end
            num = tostring(count)
        else
            num = tostring(((65535 - wear) / 65535) * 100) .. "%"
        end

        last_count = count
        last_item = wielded.name


        minetest.localplayer:hud_change(icon_widget, "text", texture)
        minetest.localplayer:hud_change(count_widget, "text", num)
    end
end

minetest.register_on_placenode(function(item, pointed_thing)
    update_count()
end)

minetest.register_on_item_use(function(item, pointed_thing)
    update_count()
end)

minetest.register_globalstep(function()
    if os.time() > epoch then
        update_count()
        epoch = os.time()
    end
end)
