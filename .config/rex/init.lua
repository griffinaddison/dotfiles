-- Rex port of ~/.dotfiles/.config/tmux/tmux.conf. Goes in ~/.config/rex/init.lua.
-- ctrl+a is the prefix, as in tmux. Sequences use ghostty's ">" syntax.

-- Splits: prefix + hjkl (tmux: smart-split.sh -hb/-v/-vb/-h)
rex.bind("ctrl+a>h", "pane.split.left")
rex.bind("ctrl+a>j", "pane.split.down")
rex.bind("ctrl+a>k", "pane.split.up")
rex.bind("ctrl+a>l", "pane.split.right")
rex.bind("ctrl+a>shift+5", "pane.split.right")       -- %
rex.bind("ctrl+a>shift+'", "pane.split.down") -- "

-- Pane focus: ctrl+hjkl, wrapping at the edges.
-- No vim passthrough yet: this steals ctrl+hjkl from nvim splits.
rex.bind("ctrl+h", "pane.focus", { direction = "left", wrap = true })
rex.bind("ctrl+j", "pane.focus", { direction = "down", wrap = true })
rex.bind("ctrl+k", "pane.focus", { direction = "up", wrap = true })
rex.bind("ctrl+l", "pane.focus", { direction = "right", wrap = true })

-- Resize: prefix + HJKL
rex.bind("ctrl+a>shift+h", "pane.resize", { direction = "left", amount = 5 })
rex.bind("ctrl+a>shift+j", "pane.resize", { direction = "down", amount = 5 })
rex.bind("ctrl+a>shift+k", "pane.resize", { direction = "up", amount = 5 })
rex.bind("ctrl+a>shift+l", "pane.resize", { direction = "right", amount = 5 })
rex.bind("ctrl+a>enter", "pane.balance")

rex.bind("ctrl+a>z", "pane.zoom")
rex.bind("ctrl+a>x", "pane.close")

-- Tabs (tmux windows)
rex.bind("ctrl+a>c", "client.tab.new")
rex.bind("ctrl+a>n", "client.tab.next")
rex.bind("ctrl+a>p", "client.tab.previous")
rex.bind("ctrl+a>,", "client.tab.rename")
rex.bind("ctrl+alt+h", "client.tab.previous")
rex.bind("ctrl+alt+l", "client.tab.next")
for i = 1, 9 do
  rex.bind("alt+" .. i, "client.tab.goto", { index = i })
end

-- Sessions
rex.bind("ctrl+a>shift+n", "session.next")
rex.bind("ctrl+a>shift+p", "session.previous")
rex.bind("ctrl+alt+j", "session.next")
rex.bind("ctrl+alt+k", "session.previous")
rex.bind("ctrl+a>s", "session.switch")
rex.bind("ctrl+a>shift+4", "session.rename") -- $

-- Search and prompt jumps (replace copy-mode / and ?)
rex.bind("ctrl+a>/", "client.find.open")
rex.bind("ctrl+a>bracketright", "client.prompt.next")

-- Copy mode, like tmux prefix+[: Rex has no vi copy mode, so open the pane's
-- screen + scrollback in nvim, zoomed over the pane, cursor at the bottom.
-- Move and yank with normal vi keys. Yanks reach the Mac clipboard through
-- nvim's osc52 setup. q quits and the pane closes.
rex.action{
  name  = "copy_mode",
  title = "Copy Mode (scrollback in nvim)",
  run   = function(ctx)
    local r = rex.exec({ "rex", "capture", "-s", ctx.session_id, "-b", ctx.block_id, "--unwrap", "--trim" })
    if not r or not r.ok then error("rex capture failed: " .. tostring(r and r.stderr), 0) end
    local path = os.tmpname()
    local f = assert(io.open(path, "w"))
    f:write(r.stdout)
    f:close()
    -- Rex's PATH lacks ~/bin, where nvim lives on hub.
    local nvim = os.getenv("HOME") .. "/bin/nvim"
    if not io.open(nvim) then nvim = "nvim" end
    local _, err = rex.session.new_split{
      anchor_id = ctx.block_id,
      direction = "vertical",
      side      = "after",
      focus     = true,
      layout    = { block = {
        flavor  = "com.superlogical.terminal.shell",
        label   = "copy",
        options = { command = {
          nvim, "-R", "-n", "+normal G",
          "+setlocal nomodifiable nonumber norelativenumber",
          "+nnoremap <buffer> q <cmd>qa!<cr>",
          "+autocmd VimLeave * call delete('" .. path .. "')",
          path,
        } },
      } },
    }
    if err ~= nil then error(err, 0) end
    rex.invoke("pane.zoom")
  end,
}
rex.bind("ctrl+a>bracketleft", "copy_mode")
-- Prompt jumps moved off prefix+[ (now copy mode).
rex.bind("ctrl+a>shift+bracketleft", "client.prompt.previous")
