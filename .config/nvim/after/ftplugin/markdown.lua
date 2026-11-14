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

-- bullets.vim only renumbers through its own keys (o, Enter, Tab, >>).
-- After any other edit next to a numbered item (dd, x, p, visual d...),
-- renumber the list. undojoin folds it into that edit, so one `u` undoes
-- both. Skip undo/redo, or `u` would renumber again and fight you.
vim.api.nvim_create_autocmd("TextChanged", {
  buffer = 0,
  callback = function()
    local ut = vim.fn.undotree()
    if ut.seq_cur ~= ut.seq_last then return end
    local l = vim.fn.line(".")
    local function numbered(n) return vim.fn.getline(n):match("^%s*%d+[.)] ") end
    if not (numbered(l) or numbered(l - 1) or numbered(l + 1)) then return end
    local view = vim.fn.winsaveview()
    pcall(vim.cmd, "undojoin")
    vim.cmd("silent! RenumberList")
    vim.fn.winrestview(view)
  end,
})

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
