# Ctrl+hjkl navigation with wrapping:
# - Left/Right: pane navigation, wraps to adjacent window at edges
# - Up/Down: pane navigation, wraps to adjacent session at edges
# When in vim: forward key to vim

bind-key -n C-h if-shell -F '#{@pane-is-vim}' 'send-keys C-h' 'if-shell -F "#{pane_at_left}" "previous-window" "select-pane -L"'
bind-key -n C-j if-shell -F '#{@pane-is-vim}' 'send-keys C-j' 'if-shell -F "#{pane_at_bottom}" "switch-client -n" "select-pane -D"'
bind-key -n C-k if-shell -F '#{@pane-is-vim}' 'send-keys C-k' 'if-shell -F "#{pane_at_top}" "switch-client -p" "select-pane -U"'
bind-key -n C-l if-shell -F '#{@pane-is-vim}' 'send-keys C-l' 'if-shell -F "#{pane_at_right}" "next-window" "select-pane -R"'

# Same bindings for copy-mode-vi
bind-key -T copy-mode-vi C-h if-shell -F '#{pane_at_left}' 'previous-window' 'select-pane -L'
bind-key -T copy-mode-vi C-j if-shell -F '#{pane_at_bottom}' 'switch-client -n' 'select-pane -D'
bind-key -T copy-mode-vi C-k if-shell -F '#{pane_at_top}' 'switch-client -p' 'select-pane -U'
bind-key -T copy-mode-vi C-l if-shell -F '#{pane_at_right}' 'next-window' 'select-pane -R'
