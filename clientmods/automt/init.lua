minetest.register_chatcommand('mtq', {
    description = 'automt-quit',
    func = function(param)
      minetest.log("AUTOMT Actually Quit")
      minetest.disconnect()
    end
})
