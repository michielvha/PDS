#!/bin/bash
# shellcheck disable=SC2016,SC2154
# PDS Bash prompt: two-line prompt with git, AWS and exit-code awareness.
# This is a standalone, sourceable snippet - it does NOT touch the rest of your
# shell config. Drop it anywhere and `source` it (the installer wires it into
# ~/.bashrc via a single guarded source line, see set_bash_prompt.sh).
# Usage: source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/prompt.bash)

# git branch (or short SHA when detached) + status markers: * unstaged, + staged, ? untracked
__git_info() {
  local b
  b=$(git symbolic-ref --short HEAD 2>/dev/null) \
    || b=$(git rev-parse --short HEAD 2>/dev/null) || return
  local s=""
  git diff --cached --quiet 2>/dev/null || s+="+"
  git diff --quiet 2>/dev/null || s+="*"
  [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ] && s+="?"
  printf ' (%s%s)' "$b" "${s:+ $s}"
}

# active AWS profile/region, when set
__aws_info() {
  local p="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE}}"
  local r="${AWS_REGION:-${AWS_DEFAULT_REGION}}"
  [ -z "$p" ] && [ -z "$r" ] && return
  printf ' [aws:%s%s]' "${p:-default}" "${r:+@$r}"
}

# red ✗<code> when the last command failed
__exit_marker() {
  [ "${__exit:-0}" -eq 0 ] && return
  printf '\001\033[01;31m\002✗%s\001\033[00m\002 ' "$__exit"
}

# capture last exit status before anything else clobbers $? (idempotent)
case "${PROMPT_COMMAND:-}" in
  *__exit=*) ;;
  *) PROMPT_COMMAND='__exit=$?'"${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac

# two-line prompt: info line + command line
PS1='\[\e]0;\u@\h: \w\a\]\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\[\033[01;33m\]$(__git_info)\[\033[00m\]\[\033[01;36m\]$(__aws_info)\[\033[00m\]\n$(__exit_marker)\$ '
