if vim.g.loaded_map_list == 1 then
  return
end

vim.g.loaded_map_list = 1

require("map-list").setup()
