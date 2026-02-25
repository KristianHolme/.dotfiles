# AGENTS.md

## Cursor Cloud specific instructions

This is a **dotfiles repository** (personal configuration management using GNU Stow), not a traditional application. There is no build step, no test suite, and no application server.

### Key tools

- **GNU Stow 2.4.x** is required (Ubuntu's default 2.3.1 has bugs with `--dotfiles` and nested directories). The update script installs 2.4.1 from source.
- **ShellCheck** is the linter for all Bash scripts in `bin/`.

### Linting

```bash
shellcheck bin/*.sh
```

All findings are info/warning level (SC1091 source-following, SC2034 unused vars in log strings, SC2088 tilde in display strings). No critical errors.

### Syntax check

```bash
for f in bin/*.sh; do bash -n "$f"; done
```

### Testing core functionality

The core operation is applying dotfiles via GNU Stow. Test with a dry-run:

```bash
stow -n -d /workspace -t ~ -S -v --dotfiles --override='.*' default
```

The `.bashrc` conflict warning is expected (the VM already has one). Use `--adopt` to resolve in real runs.

Profile overlays (e.g. `bengal`, `kaspi`, `sibir`, `sibir2`) can be dry-run tested similarly:

```bash
stow -n -d /workspace -t ~ -S -v --dotfiles --override='.*' bengal
```

### Library sourcing test

```bash
bash -c 'source bin/lib-dotfiles.sh && log_info "OK"'
```

### Symlink and PATH setup

Scripts hardcode `$HOME/.dotfiles` as the repo path. In the cloud VM the repo lives at `/workspace`, so a symlink is needed:

```bash
ln -sfn /workspace ~/.dotfiles
```

The VM's `~/.bashrc` should include these PATH entries (mirroring `dot-bashrc` lines 40-42):

```bash
export PATH="$HOME/.dotfiles/bin:$PATH"
export PATH="$HOME/.julia/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
```

Do **not** source the full `dot-bashrc` in the cloud VM — it depends on omarchy and starship which are not installed here.

### Notes

- The scripts are designed for Arch Linux (with `yay`/`pacman`) and RHEL servers. Many scripts (`dotfiles-setup-packages.sh`, `dotfiles-ssh-tmux.sh`, etc.) require their target environment to run fully.
- `gum` is needed for interactive conflict resolution in `dotfiles-apply-config.sh`. Install from GitHub releases if not present.
- See `README.md` for full documentation of all scripts and their usage.
