local M = {}

M.child = MiniTest.new_child_neovim()

function M.map_lines(command)
  return M.child.lua(
    [[
    local command = ...

    vim.cmd(command)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    if vim.bo.buftype == "nofile" then
      vim.cmd("bwipeout!")
    end

    return lines
  ]],
    { command }
  )
end

function M.contains(lines, needle)
  for _, line in ipairs(lines) do
    if line:find(needle, 1, true) ~= nil then
      return line
    end
  end

  error(
    ("expected lines to contain %s\n%s"):format(
      vim.inspect(needle),
      table.concat(lines, "\n")
    )
  )
end

function M.rejects(lines, needle)
  for _, line in ipairs(lines) do
    if line:find(needle, 1, true) ~= nil then
      error(
        ("expected lines not to contain %s\n%s"):format(
          vim.inspect(needle),
          table.concat(lines, "\n")
        )
      )
    end
  end
end

function M.expect_match(value, pattern)
  if value:match(pattern) == nil then
    error(
      ("expected %s to match %s"):format(
        vim.inspect(value),
        vim.inspect(pattern)
      ),
      2
    )
  end
end

return M
