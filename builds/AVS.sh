#!/bin/sh
printf '\033c\033]0;%s\a' AVS (4.5)
base_path="$(dirname "$(realpath "$0")")"
"$base_path/AVS.x86_64" "$@"
