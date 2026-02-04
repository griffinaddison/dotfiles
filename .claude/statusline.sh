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
branch=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    if [[ -n "$branch" ]]; then
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            branch="${branch}${RED}[dirty]${WHITE}"
        else
            branch="${branch}${WHITE}[clean]${WHITE}"
        fi
    fi
fi

# Model ID
model="${CLAUDE_MODEL:-}"

# Context usage percentage
ctx=""
if [[ -n "$CLAUDE_CONTEXT_WINDOW_USED" && -n "$CLAUDE_CONTEXT_WINDOW_TOTAL" && "$CLAUDE_CONTEXT_WINDOW_TOTAL" -gt 0 ]]; then
    pct=$((CLAUDE_CONTEXT_WINDOW_USED * 100 / CLAUDE_CONTEXT_WINDOW_TOTAL))
    ctx="${pct}%"
fi

# Session cost
cost=""
if [[ -n "$CLAUDE_SESSION_COST_USD" ]]; then
    cost="\$${CLAUDE_SESSION_COST_USD}"
fi

# Build output (white base color, extra spacing after location)
output="${WHITE}${location}"
[[ -n "$branch" ]] && output+="   ${branch}"
[[ -n "$model" ]] && output+=" ${CYAN}[${model}]${WHITE}"
[[ -n "$ctx" ]] && output+=" ${YELLOW}${ctx}${WHITE}"
[[ -n "$cost" ]] && output+=" ${GREEN}${cost}${WHITE}"

printf '%b' "$output"
