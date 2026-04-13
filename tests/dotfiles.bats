#!/usr/bin/env bats

setup() {
  REPO_SRC="${BATS_TEST_DIRNAME}/.."
  WORKDIR="$(mktemp -d)"
  REPO="${WORKDIR}/repo"
  HOME_DIR="${WORKDIR}/home"
  mkdir -p "${REPO}" "${HOME_DIR}"

  # Use only tracked files (avoids sockets/root-owned dirs from local machines).
  git -C "${REPO_SRC}" archive --format=tar HEAD | tar -x -C "${REPO}"

  chmod +x "${REPO}/bin/dotfiles"

  export HOME="${HOME_DIR}"
}

teardown() {
  rm -rf "${WORKDIR}"
}

realpath_or_readlink() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
  elif readlink -f / >/dev/null 2>&1; then
    readlink -f "$1"
  else
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"
  fi
}

@test "help prints usage" {
  run "${REPO}/bin/dotfiles" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"brew sync"* ]]
  [[ "$output" == *"doctor"* ]]
}

@test "repo is stow-only (no legacy top-level dotfiles tracked)" {
  [ ! -e "${REPO}/.zshrc" ]
  [ ! -e "${REPO}/.zsh_aliases" ]
  [ ! -e "${REPO}/.gitconfig" ]
  [ ! -e "${REPO}/bin/install.sh" ]
  [ ! -e "${REPO}/.config/nvim/init.lua" ]
  [ ! -e "${REPO}/.config/nvim/init.vim" ]
  [ ! -e "${REPO}/.config/neofetch/config.conf" ]
}

@test "link creates expected symlinks" {
  run "${REPO}/bin/dotfiles" link
  [ "$status" -eq 0 ]

  [ -L "${HOME}/.zshrc" ]
  [ -L "${HOME}/.zsh_aliases" ]
  [ -L "${HOME}/.gitconfig" ]
  [ -d "${HOME}/.config" ]
  [ -L "${HOME}/.config/nvim" ]
  [ -L "${HOME}/.config/neofetch" ]
  [ -L "${HOME}/.config/zed" ]

  [ -f "${HOME}/.config/nvim/init.lua" ]
  [ -f "${HOME}/.config/neofetch/config.conf" ]
  [ -f "${HOME}/.config/zed/settings.json" ]

  [ "$(realpath_or_readlink "${HOME}/.zshrc")" = "$(realpath_or_readlink "${REPO}/zsh/.zshrc")" ]
  [ "$(realpath_or_readlink "${HOME}/.gitconfig")" = "$(realpath_or_readlink "${REPO}/git/.gitconfig")" ]
  [ "$(realpath_or_readlink "${HOME}/.config/nvim/init.lua")" = "$(realpath_or_readlink "${REPO}/nvim/.config/nvim/init.lua")" ]
  [ "$(realpath_or_readlink "${HOME}/.config/neofetch/config.conf")" = "$(realpath_or_readlink "${REPO}/neofetch/.config/neofetch/config.conf")" ]
  [ "$(realpath_or_readlink "${HOME}/.config/zed/settings.json")" = "$(realpath_or_readlink "${REPO}/zed/.config/zed/settings.json")" ]
}

@test "link --backup moves conflicting files aside" {
  mkdir -p "${HOME}/.config/nvim"
  echo "OLD_ZSHRC" > "${HOME}/.zshrc"

  run "${REPO}/bin/dotfiles" link --backup
  [ "$status" -eq 0 ]
  [[ "$output" == *"Backed up existing dotfiles to:"* ]]

  backup_dir="$(echo "$output" | sed -n 's/^Backed up existing dotfiles to: //p' | tail -n 1)"
  [ -n "$backup_dir" ]
  [ -f "${backup_dir}/.zshrc" ]
  run cat "${backup_dir}/.zshrc"
  [ "$status" -eq 0 ]
  [ "$output" = "OLD_ZSHRC" ]

  [ -L "${HOME}/.zshrc" ]
}

@test "unlink removes stow-managed symlinks" {
  run "${REPO}/bin/dotfiles" link
  [ "$status" -eq 0 ]

  run "${REPO}/bin/dotfiles" unlink
  [ "$status" -eq 0 ]

  [ ! -e "${HOME}/.zshrc" ]
  [ ! -e "${HOME}/.zsh_aliases" ]
  [ ! -e "${HOME}/.gitconfig" ]
}

@test "doctor runs non-destructively" {
  before_count="$(find "${HOME}" -mindepth 1 -print | wc -l | tr -d ' ')"
  run "${REPO}/bin/dotfiles" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stow packages:"* ]]
  after_count="$(find "${HOME}" -mindepth 1 -print | wc -l | tr -d ' ')"
  [ "$before_count" -eq "$after_count" ]
}

@test "brew sync merges brew bundle dump into Brewfile (stubbed brew)" {
  mkdir -p "${WORKDIR}/fakebin"
  export PATH="${WORKDIR}/fakebin:${PATH}"

  cat >"${WORKDIR}/fakebin/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "bundle" && "${2:-}" == "dump" ]]; then
  file=""
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--file" ]]; then
      file="$2"
      shift 2
      continue
    fi
    shift
  done
  : "${file:?missing --file}"
  cat >"$file" <<'EOT'
tap "foo/bar"
brew "ripgrep"
cask "zed"
EOT
  exit 0
fi
echo "unsupported brew invocation: $*" >&2
exit 1
EOF
  chmod +x "${WORKDIR}/fakebin/brew"

  cat >"${REPO}/Brewfile" <<'EOF'
brew "git"
cask "discord"
EOF

  run "${REPO}/bin/dotfiles" brew sync
  [ "$status" -eq 0 ]

  run cat "${REPO}/Brewfile"
  [ "$status" -eq 0 ]
  [[ "$output" == *'tap "foo/bar"'* ]]
  [[ "$output" == *'brew "git"'* ]]
  [[ "$output" == *'brew "ripgrep"'* ]]
  [[ "$output" == *'cask "discord"'* ]]
  [[ "$output" == *'cask "zed"'* ]]
}

@test "brew prune calls brew bundle cleanup (stubbed brew)" {
  mkdir -p "${WORKDIR}/fakebin"
  export PATH="${WORKDIR}/fakebin:${PATH}"
  export BREW_STUB_LOG="${WORKDIR}/brew.log"

  cat >"${WORKDIR}/fakebin/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${BREW_STUB_LOG:?missing BREW_STUB_LOG}"
if [[ "${1:-}" == "bundle" && "${2:-}" == "cleanup" ]]; then
  exit 0
fi
echo "unsupported brew invocation: $*" >&2
exit 1
EOF
  chmod +x "${WORKDIR}/fakebin/brew"

  cat >"${REPO}/Brewfile" <<'EOF'
brew "git"
EOF

  run "${REPO}/bin/dotfiles" brew prune
  [ "$status" -eq 0 ]

  run cat "${BREW_STUB_LOG}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bundle cleanup"* ]]
  [[ "$output" == *"--file"* ]]
  [[ "$output" == *"--force"* ]]
}

@test "brew prune --zap includes --zap flag (stubbed brew)" {
  mkdir -p "${WORKDIR}/fakebin"
  export PATH="${WORKDIR}/fakebin:${PATH}"
  export BREW_STUB_LOG="${WORKDIR}/brew.log"

  cat >"${WORKDIR}/fakebin/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${BREW_STUB_LOG:?missing BREW_STUB_LOG}"
if [[ "${1:-}" == "bundle" && "${2:-}" == "cleanup" ]]; then
  exit 0
fi
echo "unsupported brew invocation: $*" >&2
exit 1
EOF
  chmod +x "${WORKDIR}/fakebin/brew"

  cat >"${REPO}/Brewfile" <<'EOF'
brew "git"
EOF

  run "${REPO}/bin/dotfiles" brew prune --zap
  [ "$status" -eq 0 ]

  run cat "${BREW_STUB_LOG}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--zap"* ]]
}
