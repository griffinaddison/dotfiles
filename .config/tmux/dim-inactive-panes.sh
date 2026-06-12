#!/bin/bash
# Dim explicitly-colored text in inactive panes.
#
# window-style only dims default-colored cells; apps that emit explicit palette
# colors (Claude Code, ls, git, ...) stay bright. This script overrides those
# palette indices per pane via pane-colours[]: inactive panes get ~55%-darkened
# values, the active pane gets its overrides cleared. Only palette-indexed
# colors can be dimmed — truecolor output (e.g. nvim with termguicolors) is
# unaffected.
#
# Driven by hooks in tmux.conf on every pane focus change. The @colors-dimmed
# pane option tracks state so steady-state runs are no-ops.

# "index dimmed-hex": ANSI 0-15 (ghostty Chalk values) + indices Claude Code uses
DIM_MAP="
0 #444c4e
1 #611f2d
2 #42553a
3 #655e28
4 #17455e
5 #672b31
6 #255b54
7 #737677
8 #4a4a4a
9 #852723
10 #466b3d
11 #8c8135
12 #23528c
13 #8a2d40
14 #2d7067
15 #737677
37 #006060
44 #007676
114 #4a764a
141 #604a8c
148 #607600
153 #60768c
174 #764a4a
186 #76764a
197 #8c0034
220 #8c7600
231 #8c8c8c
237 #1f1f1f
239 #2a2a2a
244 #464646
246 #515151
"

# One tmux call per pane that needs a change (a single batched call for all
# panes exceeds tmux's command length limit on the initial pass).
while read -r pane_id active dimmed; do
    args=()
    add_cmd() {
        [ ${#args[@]} -gt 0 ] && args+=(";")
        args+=("$@")
    }
    if [ "$active" = "1" ] && [ "$dimmed" = "1" ]; then
        add_cmd set -pu -t "$pane_id" pane-colours
        add_cmd set -pu -t "$pane_id" @colors-dimmed
    elif [ "$active" = "0" ] && [ "$dimmed" != "1" ]; then
        while read -r idx hex; do
            [ -n "$idx" ] && add_cmd set -p -t "$pane_id" "pane-colours[$idx]" "$hex"
        done <<< "$DIM_MAP"
        add_cmd set -p -t "$pane_id" @colors-dimmed 1
    fi
    [ ${#args[@]} -gt 0 ] && tmux "${args[@]}"
done < <(tmux list-panes -a -F '#{pane_id} #{pane_active} #{@colors-dimmed}')
exit 0
