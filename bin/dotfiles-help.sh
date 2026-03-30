#!/bin/bash
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	cat <<EOF
Usage: $0

Open ~/dotfiles/README.md in bat (pager).
EOF
	exit 0
fi
bat ~/dotfiles/README.md
