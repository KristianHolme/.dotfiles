---
name: television
description: Uses Television (tv), a fast terminal fuzzy finder with channels, previews, and shell integration. Use when the user mentions Television, tv, fuzzy finding files or text, channel configuration, cable.toml channels, piping into a picker, or replacing fzf/telescope-style workflows in the shell.
---

# Television (`tv`)

[Television](https://github.com/alexpasmantier/television) is a Rust TUI fuzzy finder. The executable is **`tv`**. Official docs: [alexpasmantier.github.io/television](https://alexpasmantier.github.io/television/).

## Quick start

```sh
tv                    # default channel (usually files)
tv files              # browse files
tv text               # search file contents (ripgrep-backed)
tv git-repos          # find git repositories
tv env                # environment variables
tv list-channels      # discover channels
tv update-channels    # refresh channel prototypes from upstream
tv --help             # full CLI (see also [CLI reference](https://alexpasmantier.github.io/television/reference/cli/))
```

Optional positional args: `[CHANNEL] [PATH]` — `PATH` sets the starting working directory.

## Piping and scripts

Stdin becomes the source list; selected lines go to stdout.

```sh
git log --oneline | tv
ps aux | tv
cat /var/log/syslog | tv
nvim "$(tv files)"                    # pick one file
cd "$(tv dirs)"                       # if dirs channel exists / configured
```

Multi-select: **Tab** toggles entries; **Enter** prints all selected.

Automation flags (see `--help`): `--select-1`, `--take-1`, `--take-1-fast`, `--expect`, `-i` / `--input` to prefill the query.

## Search query syntax

| Pattern   | Meaning                          |
|-----------|----------------------------------|
| `foo`     | Fuzzy match                      |
| `'foo`    | Substring (exact contains)      |
| `^foo`    | Prefix                           |
| `foo$`    | Suffix                           |
| `!foo`    | Negate                           |

Space-separated tokens are **AND**. Example: `test ^src !.bak$`.

`--exact` switches to substring matching for the whole session.

## Default keybindings (in-app)

| Key        | Action              |
|------------|---------------------|
| ↑ ↓ / Ctrl+j k | Move selection  |
| Enter      | Confirm             |
| Tab        | Multi-select toggle |
| Ctrl+y     | Copy entry          |
| PageUp/Down| Scroll preview      |
| Ctrl+o     | Toggle preview      |
| Ctrl+t     | Remote control (channel picker) |
| Ctrl+h     | Help                |
| Esc / Ctrl+c | Quit            |

User overrides: config `[keybindings]` or `tv -k 'quit="esc";select_next_entry=["down","ctrl-j"]'`.

## Ad-hoc channel from CLI

Override or define a one-off source/preview without a cable file:

```sh
tv --source-command "find . -name '*.rs'"
tv --source-command "fd -t f" --preview-command "bat -n --color=always '{}'"
tv --source-command "ls -la" --preview-command "file '{}'" --preview-size 70
```

`{}` is the selected entry; `{0}` `{1}` split by `--source-entry-delimiter`. Use `--ansi` if the source emits color codes. `--no-sort` preserves source order.

## Configuration

| Location | Purpose |
|----------|---------|
| `$XDG_CONFIG_HOME/television/config.toml` or `~/.config/television/config.toml` | Main config |
| `TELEVISION_CONFIG` | If set, config dir is `$TELEVISION_CONFIG` (e.g. `$TELEVISION_CONFIG/config.toml`) |
| `~/.config/television/cable/*.toml` | Custom **channels** (“cables”) |
| `~/.config/television/themes/` | Custom themes |

Useful top-level options: `default_channel`, `history_size`, `global_history`, `[ui]` (theme, orientation, panel sizes). Full option list: [Configuration](https://alexpasmantier.github.io/television/user-guide/configuration/).

`tv --config-file <path>` and `tv --cable-dir <path>` override defaults.

## Custom channel (cable) sketch

```toml
# ~/.config/television/cable/example.toml
[metadata]
name = "example"
description = "Short description"

[source]
command = "your-listing-command"

[preview]
command = "preview '{}'"

# optional: [keybindings], [actions.*], etc.
```

Details: [First channel](https://alexpasmantier.github.io/television/getting-started/first-channel).

## Shell integration

```sh
# Zsh
eval "$(tv init zsh)"
# Bash
eval "$(tv init bash)"
# Fish
tv init fish | source
```

Enables **Ctrl+T** (smart completion) and **Ctrl+R** (history search). Tuning: `[shell_integration]` in `config.toml` — `channel_triggers`, `fallback_channel`, keybindings. Guide: [Shell integration](https://alexpasmantier.github.io/television/user-guide/shell-integration).

## Editor integrations

Neovim: [tv.nvim](https://github.com/alexpasmantier/tv.nvim). Vim: [tv.vim](https://github.com/prabirshrestha/tv.vim). VS Code: marketplace “Television”. See README [Editor Integration](https://github.com/alexpasmantier/television#editor-integration).

## Install (common)

Arch: `pacman -S television`. Homebrew: `brew install television`. Cargo: `cargo install television`. Install script and more: [Installation](https://alexpasmantier.github.io/television/getting-started/installation).

## When stuck

1. `tv list-channels` and `tv update-channels`
2. `tv --help` and [CLI reference](https://alexpasmantier.github.io/television/reference/cli/)
3. [Tips and tricks](https://alexpasmantier.github.io/television/advanced/tips-and-tricks)
