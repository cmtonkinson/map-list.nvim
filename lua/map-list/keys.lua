local M = {}

local function leader()
  return vim.g.mapleader or "\\"
end

local function localleader()
  return vim.g.maplocalleader or "\\"
end

local function replace_prefix(text, prefix, replacement)
  if prefix == nil or prefix == "" then
    return text
  end

  if text:sub(1, #prefix) == prefix then
    return replacement .. text:sub(#prefix + 1)
  end

  return text
end

function M.normalize_lhs(lhs)
  lhs = M.expand_lhs(lhs)

  return vim.api.nvim_replace_termcodes(lhs, true, true, true)
end

function M.expand_lhs(lhs)
  lhs = lhs:gsub("<[Ll]eader>", leader())
  lhs = lhs:gsub("<[Ll]ocal[Ll]eader>", localleader())
  lhs = lhs:gsub("<[Ss]pace>", " ")

  return lhs
end

function M.display_lhs(lhs)
  local leader_key = leader()
  local localleader_key = localleader()

  if #localleader_key > #leader_key then
    lhs = replace_prefix(lhs, localleader_key, "<localleader>")
    lhs = replace_prefix(lhs, leader_key, "<leader>")
  else
    lhs = replace_prefix(lhs, leader_key, "<leader>")
    lhs = replace_prefix(lhs, localleader_key, "<localleader>")
  end

  lhs = lhs:gsub(" ", "<Space>")

  return lhs
end

return M
