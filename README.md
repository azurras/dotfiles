# dotfiles

This repo is intended to let me bootstrap a new machine quickly:

1. Install apps and CLI tools (Homebrew Bundle on macOS; optional on Linux).
2. Symlink dotfiles into place (GNU Stow).

## Quick Start (macOS)

```bash
./install.sh
```

Or (Finder): double-click `bootstrap.command`.

That will:

- Install everything in `Brewfile` (`brew bundle`)
- Ensure `oh-my-zsh` is installed in `~/.oh-my-zsh`
- Link dotfiles into `$HOME` using `stow` (packages: `zsh/`, `git/`, `nvim/`)

If you already have dotfiles and want to move them aside automatically:

```bash
./bin/dotfiles link --backup
```

## Debian/Ubuntu (Best Effort)

```bash
./bin/dotfiles apt install
./bin/dotfiles link
```

If you install Linuxbrew separately, you can also run:

```bash
./bin/dotfiles brew install
```

## Updating The Brewfile

To merge what is currently installed via brew into `Brewfile` (without deleting existing entries):

```bash
./bin/dotfiles brew sync
```

## Repo Layout

- `Brewfile`: apps + CLI tools (source of truth for macOS installs)
- `zsh/`, `git/`, `nvim/`: GNU Stow packages that mirror the target paths under `$HOME`
