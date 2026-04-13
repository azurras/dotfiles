.PHONY: help bootstrap link link-backup unlink doctor brew-install brew-upgrade brew-sync brew-snapshot brew-prune brew-prune-zap test

help:
	@echo "Targets:"
	@echo "  make bootstrap        Install brew deps (no-upgrade) + link dotfiles"
	@echo "  make link             Link dotfiles into \$$HOME (stow)"
	@echo "  make link-backup      Link with automatic backup of conflicting files"
	@echo "  make unlink           Remove stow-managed symlinks"
	@echo "  make doctor           Non-destructive sanity checks"
	@echo "  make brew-install     Install from Brewfile (no-upgrade)"
	@echo "  make brew-upgrade     Install from Brewfile with upgrades"
	@echo "  make brew-sync        Merge installed brew items into Brewfile"
	@echo "  make brew-snapshot    Write Brewfile.versions"
	@echo "  make brew-prune       Remove brew items not in Brewfile (destructive)"
	@echo "  make brew-prune-zap   Like brew-prune, but zap casks (more destructive)"
	@echo "  make test             Run unit tests (bats)"

bootstrap:
	./bin/dotfiles bootstrap

link:
	./bin/dotfiles link

link-backup:
	./bin/dotfiles link --backup

unlink:
	./bin/dotfiles unlink

doctor:
	./bin/dotfiles doctor

brew-install:
	./bin/dotfiles brew install

brew-upgrade:
	./bin/dotfiles brew install --upgrade

brew-sync:
	./bin/dotfiles brew sync

brew-snapshot:
	./bin/dotfiles brew snapshot

brew-prune:
	./bin/dotfiles brew prune

brew-prune-zap:
	./bin/dotfiles brew prune --zap

test:
	bats tests

