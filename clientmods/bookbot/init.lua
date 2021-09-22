-- CC0/Unlicense Emilia 2020

-- TODO: API
-- TODO: all count should be changed to support using a bookbot as a rolling writer
--        an alternate solution is to just have an inventory manager bot that intermittently swaps the inventory and activates bookbot
-- TODO: local formspec stuff

--[[
COMMANDS

write <book> <times>        Writes the book named <book>, <times> times
randwrite <times>           Writes randomized books
bookadd_form                Opens a book formspec for adding a book to the library
bookadd_this <shortname>    Adds the currently selected book to the library
bookdel <shortname>         Removes a book from the library
bookpeek <book>             Peeks at a book in the library
booklist                    Lists all books
--]]

bookbot = {}

local book_length_max = 4500

local write = 0
local books = {
    example = {
        title = "Autobook",
        author = "Emilia",
        text = "This is an automatically written book."
    }
}

local book
local book_iterator

local read_form = [[
size[9,8]
label[0,0;N]
label[0,1;A]
textlist[0,2;9,5;;T]
]]

local edit_form = [[
size[9,8]
field[0,0;9,1;title;;N]
field[0,1;9,1;author;;A]
textarea[0,2;9,5;text;;T]
]]

local storage = minetest.get_mod_storage()

local function storage_save()
    storage:set_string("books", minetest.write_json(books))
end

local function storage_load()
    local sbooks = storage:get("books")
    if sbooks then
        books = minetest.parse_json(sbooks)
    end
end

storage_load()

local function open_book()
    if minetest.switch_to_item("mcl_books:writable_book") then
        minetest.interact("place")
        book = book_iterator()
    else
        write = 0
        book = nil
        book_iterator = nil
    end
end

local function count_books()
    local lpmain = minetest.get_inventory("current_player").main
    local count = 0

    for i, v in ipairs(lpmain) do
        if v:get_name() == "mcl_books:writable_book" then
            count = count + 1
        end
    end

    return count
end

minetest.register_on_receiving_inventory_form(function(formname, formspec)
    if formname == "mcl_books:writable_book" and write ~= 0 then
        minetest.send_inventory_fields("mcl_books:writable_book", {
            text = book.text,
            sign = "true",
        })
        minetest.close_formspec("")
    elseif formname == "mcl_books:signing" and write ~= 0 then
        minetest.send_inventory_fields("mcl_books:signing", {
            title = book.title,
            sign = "true"
        })
        minetest.close_formspec("")

        write = write - 1
        if write > 0 then
            -- this should take lag into consideration
            minetest.after(0.5, open_book)
        end
    end
end)

local function timesparse(times)
    local count = 1

    if times then
        if times == "all" then
            count = count_books()
        elseif type(times) == "number" or times:match("^[0-9]+$") then
            count = tonumber(times)
        end
    end

    return count
end

function bookbot.write_iterator(iterator, write_no)
    book_iterator = iterator

    write = timesparse(write_no)

    open_book()
end

function bookbot.write_simple(book, write_no)
    local book_iterator = function()
        return book
    end

    bookbot.write_iterator(book_iterator, write_no)
end

function bookbot.write(bookname, write_no)
    local book = "example"
    if bookname and books[bookname] then
        book = books[bookname]
    end

    bookbot.write_simple(book, write_no)
end

function bookbot.add(bookname, title, author, text)
    books[bookname] = {
        title = title,
        author = author,
        text = text
    }

    storage_save()
end

minetest.register_chatcommand("write", {
    description = "Write a book.",
    params = "<book> <?ntimes/all>",
    func = function(params)
        local p = string.split(params, " ")

        if #p == 0 then
            minetest.display_chat_message("Error: book short name required")
            return
        end

        bookbot.write(p[1], p[2])
    end
})

minetest.register_chatcommand("bookadd_this", {
    description = "Add the currently wielded book to the library, <name> is for the name in the library.",
    params = "<name>",
    func = function(params)
        if params == "" then
            minetest.display_chat_message("Error: no short name given")
            return
        end

        local wielded = minetest.localplayer:get_wielded_item()
        if wielded:get_name() == "mcl_books:written_book" then
            local meta = wielded:get_meta():to_table()
            bookbot.add(params,
                meta.fields.title,
                meta.fields.author,
                meta.fields.text)
        end
    end
})

minetest.register_chatcommand("booklist", {
    description = "List all saved books.",
    func = function()
        local out = ""
        local first = true
        for k, v in pairs(books) do
            if not first then
                out = out .. ", "
            end
            out = out .. k
            first = false
        end
        minetest.display_chat_message("Saved books:")
        minetest.display_chat_message(out)
    end
})

minetest.register_chatcommand("randwrite", {
    description = "Write random books.",
    params = "<?times/all>",
    func = function(params)
        local p = string.split(params, " ")

        book_iterator = function()
            local out = {}
            for i = 1, book_length_max do
                table.insert(out, string.char(math.random(0x20, 0xFF)))
            end
            return {
                title = "Random book",
                author = "The computer",
                text = table.concat(out)
            }
        end

        bookbot.write_iterator(book_iterator, p[1])
    end
})
