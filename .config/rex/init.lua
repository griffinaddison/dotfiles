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
rex.bind("ctrl+a>bracketleft", "client.prompt.previous")
rex.bind("ctrl+a>bracketright", "client.prompt.next")
