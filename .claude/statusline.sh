#!/bin/bash
# Claude Code status line
# Shows: user@host:dir branch [dirty/clean] [Model] ctx% $cost

# Colors (ANSI)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
WHITE='\033[0;37m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# user@host:dir (user@host bold green, dir blue, ~ substitution)
BOLD_GREEN='\033[1;32m'
dir="$PWD"
[[ "$dir" == "$HOME"* ]] && dir="~${dir#$HOME}"
location="${BOLD_GREEN}${USER}@${HOSTNAME%%.*}${WHITE}:${BLUE}${dir}${WHITE}"

# Git branch with [dirty]/[clean]
if git rev-parse --is-inside-work-tree &>/dev/null; then
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    if [[ -n "$branch" ]]; then
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            branch="${branch}${RED}[dirty]${WHITE}"
        else
            branch="${branch}${WHITE}[clean]${WHITE}"
        fi
    fi
else
    branch="${WHITE}[not a repo]${WHITE}"
fi

# Read JSON from stdin
input=$(cat)

# Model ID (full model id, not display name)
model=$(echo "$input" | jq -r '.model.id // empty')

# Context usage percentage
ctx=""
pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [[ -n "$pct" ]]; then
    ctx="ctx:${pct%.*}%"
fi

# Build output
output="${WHITE}${location}"
output+="   ${branch}"
[[ -n "$model" ]] && output+="   ${CYAN}[${model}]${WHITE}"
[[ -n "$ctx" ]] && output+="   ${YELLOW}${ctx}${WHITE}"

printf '%b' "$output"
