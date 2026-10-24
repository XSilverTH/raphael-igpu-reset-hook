#!/usr/bin/env bash

mode2_reset_cursor() {
  local output
  output=$(journalctl -k -b -n 0 --show-cursor --no-pager 2>/dev/null) || return 1
  [[ $output =~ --\ cursor:\ (.*)$ ]] || return 1
  [[ -n ${BASH_REMATCH[1]} ]] || return 1
  printf '%s\n' "${BASH_REMATCH[1]}"
}

mode2_reset_succeeded_since() {
  local cursor=$1 gpu_bdf=$2 line output saw_reset=0 reset_failed=0
  [[ -n $cursor ]] || return 1
  output=$(journalctl -k -b --after-cursor="$cursor" --no-pager 2>/dev/null) || return 1
  while IFS= read -r line; do
    if [[ $line == *"amdgpu $gpu_bdf:"* ]]; then
      [[ $line != *'MODE2 reset'* ]] || saw_reset=1
      [[ $line != *'GPU mode2 reset failed'* ]] || reset_failed=1
    fi
  done <<<"$output"
  [[ $saw_reset == 1 && $reset_failed == 0 ]]
}
