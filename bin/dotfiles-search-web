#!/bin/bash
# Web search: select engine first, then type query

set -euo pipefail

engine=$(printf "%s\n" "GitHub" "Google" | walker --dmenu --placeholder "Search in")
[[ -z "$engine" ]] && exit 0

query=$(walker --dmenu --placeholder "Search $engine")
[[ -z "$query" ]] && exit 0

case "$engine" in
GitHub) url="https://www.google.com/search?q=site:github.com+$(printf %s "$query" | jq -sRr @uri)" ;;
Google) url="https://www.google.com/search?q=$(printf %s "$query" | jq -sRr @uri)" ;;
*) exit 0 ;;
esac

exec omarchy-launch-webapp "$url"
