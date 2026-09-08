-- Markdown list helpers. bullets.vim (configured in init.lua) already handles:
--   <Enter>/o  continue the list marker
--   <leader>x  toggle [ ] <-> [x]  (nested: checks children, updates parents)
--   <C-t>/<C-d> (and Tab/S-Tab in insert) indent/dedent
-- This file only adds what bullets.vim lacks: adding/removing the checkbox itself.

-- Neovim's built-in ftplugin/markdown.vim forces tabstop/shiftwidth to 4.
-- Markdown nests at 2 spaces per level, and 4 spaces under a non-list line is
-- an indented code block, so a 4-space list silently stops being a list.
-- This file loads after the built-in, so these win.
vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.expandtab = true

-- <leader>X: "- item" <-> "- [ ] item"  (removes [x] too)
local function checkbox_add_remove(lnum)
  local line = vim.fn.getline(lnum)
  local new
  if line:match("^%s*[-*+] %[.%] ") then
    new = line:gsub("%[.%] ", "", 1)
  elseif line:match("^%s*[-*+] ") then
    new = line:gsub("^(%s*[-*+] )", "%1[ ] ", 1)
  end
  if new then vim.fn.setline(lnum, new) end
end

vim.keymap.set("n", "<leader>X", function()
  checkbox_add_remove(vim.fn.line("."))
end, { buffer = true, desc = "add/remove checkbox" })

vim.keymap.set("x", "<leader>X", function()
  local first, last = vim.fn.line("v"), vim.fn.line(".")
  if first > last then first, last = last, first end
  for lnum = first, last do
    checkbox_add_remove(lnum)
  end
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end, { buffer = true, desc = "add/remove checkboxes" })
