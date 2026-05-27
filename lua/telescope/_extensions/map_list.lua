return require("telescope").register_extension({
  exports = {
    map_list = require("map-list.telescope").map_list,
  },
})
