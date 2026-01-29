#!/bin/bash
# Updates tmux window name with work summary (only for cc windows)

[ -z "$TMUX" ] && exit 0

# Get current window name
current=$(tmux display-message -p '#{window_name}')

# Only update windows that start with "cc " (Claude Code windows)
[[ "$current" != cc\ * ]] && exit 0

# Read hook input JSON
input=$(cat)
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# Extract first user message from transcript
user_msg=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    # Find first user message and extract text content
    user_msg=$(grep '"type":"user"' "$transcript_path" 2>/dev/null | head -1 | \
        jq -r '.message.content | if type == "array" then map(select(.type == "text") | .text) | join(" ") else . end // empty' 2>/dev/null)
fi

# Extract ~3 keywords (skip stop words)
if [ -n "$user_msg" ]; then
    short=$(echo "$user_msg" | tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-z0-9 ]//g' | \
        tr -s ' ' | \
        awk '{
            split("the a an to for of in on with and or is it be this that i you me my please can could would should want need help do does did have has had hey what how why when where which who whom whose im am are was were been being get got lets let make made", sw)
            for (i in sw) stop[sw[i]] = 1
            n = 0
            for (i = 1; i <= NF && n < 3; i++) {
                if (!($i in stop) && length($i) > 1) {
                    printf "%s ", $i
                    n++
                }
            }
        }' | sed 's/ $//')

    # Get base (cc <dir>) by stripping old summary
    base=$(echo "$current" | sed 's/ - .*//')

    # Update window with summary
    [ -n "$short" ] && tmux rename-window "${base} - ${short}" 2>/dev/null
fi

exit 0
