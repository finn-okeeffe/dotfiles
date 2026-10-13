#!/usr/bin/env bash
# Claude Code status line: model and effort, current directory, weekly limit, tokens in context.
input=$(cat)

model=$(jq -r '.model.display_name // "?"' <<<"$input")
effort=$(jq -r '.effort.level // empty' <<<"$input")
dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
week=$(jq -r '.rate_limits.seven_day.used_percentage // empty' <<<"$input")
tokens=$(jq -r '(.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)' <<<"$input")

dir=${dir/#$HOME/\~}
if (( tokens >= 1000 )); then
  tokens=$(awk -v t="$tokens" 'BEGIN { printf "%.1fk", t / 1000 }')
fi

cyan=$'\e[36m' blue=$'\e[34m' yellow=$'\e[33m' dim=$'\e[2m' reset=$'\e[0m'
sep="${dim} · ${reset}"

line="${cyan}${model}${effort:+ ${effort}}${reset}${sep}${blue}${dir}${reset}"
[[ -n $week ]] && line+="${sep}${yellow}week $(printf '%.0f' "$week")%${reset}"
line+="${sep}${tokens} tokens"
printf '%s\n' "$line"
