local helpers = require("tests.helpers")
local child = helpers.child
local contains = helpers.contains
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "tests/minimal-init.lua" })
      child.lua([[
        vim.g.mapleader = " "
        vim.g.maplocalleader = ","
        require("map-list").setup()
      ]])
    end,
    post_once = child.stop,
  },
})

T["telescope extension exports map_list picker"] = function()
  local result = child.lua([[
    package.loaded["telescope"] = nil
    package.preload["telescope"] = function()
      return {
        register_extension = function(spec)
          return spec
        end,
      }
    end

    local extension = require("telescope._extensions.map_list")

    return type(extension.exports.map_list)
  ]])

  eq(result, "function")
end

T["telescope extension delegates to map-list telescope picker"] = function()
  local result = child.lua([[
    package.loaded["telescope"] = nil
    package.loaded["map-list.telescope"] = nil

    local received_opts = nil

    package.preload["telescope"] = function()
      return {
        register_extension = function(spec)
          return spec
        end,
      }
    end

    package.preload["map-list.telescope"] = function()
      return {
        map_list = function(opts)
          received_opts = opts
          return "picker-result"
        end,
      }
    end

    local extension = require("telescope._extensions.map_list")
    local result = extension.exports.map_list({ filter = "<leader>" })

    return { result, received_opts.filter }
  ]])

  eq(result, { "picker-result", "<leader>" })
end

T["telescope picker builds entries from map-list rows"] = function()
  local result = child.lua([[
    package.loaded["telescope.pickers"] = nil
    package.loaded["telescope.finders"] = nil
    package.loaded["telescope.config"] = nil
    package.loaded["telescope.actions"] = nil
    package.loaded["telescope.actions.state"] = nil

    local picker = nil

    package.preload["telescope.pickers"] = function()
      return {
        new = function(opts, spec)
          picker = {
            opts = opts,
            spec = spec,
            find = function() end,
          }

          return picker
        end,
      }
    end

    package.preload["telescope.finders"] = function()
      return {
        new_table = function(spec)
          return spec
        end,
      }
    end

    package.preload["telescope.config"] = function()
      return {
        values = {
          generic_sorter = function()
            return "sorter"
          end,
        },
      }
    end

    package.preload["telescope.actions"] = function()
      return {
        close = function() end,
        select_default = {
          replace = function() end,
        },
      }
    end

    package.preload["telescope.actions.state"] = function()
      return {
        get_selected_entry = function() end,
      }
    end

    vim.o.columns = 120
    vim.keymap.set("n", "<leader>maplisttel", "<Cmd>echo 'tel'<CR>", {
      desc = "Map List Telescope Entry",
    })

    require("map-list.telescope").map_list({ filter = "<leader>maplisttel" })

    local entry = picker.spec.finder.entry_maker(
      picker.spec.finder.results[1]
    )

    return {
      picker.spec.prompt_title,
      picker.spec.sorter,
      #picker.spec.finder.results,
      entry.value.desc,
      entry.ordinal,
      entry.display,
    }
  ]])

  eq(result[1], "Keymaps")
  eq(result[2], "sorter")
  eq(result[3], 1)
  eq(result[4], "Map List Telescope Entry")
  contains({ result[5] }, "Map List Telescope Entry")
  contains({ result[5] }, "<leader>maplisttel")
  contains({ result[6] }, "Map List Telescope Entry")
end

return T
