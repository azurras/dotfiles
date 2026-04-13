#!/usr/bin/env bats

setup() {
  REPO_SRC="${BATS_TEST_DIRNAME}/.."
  WORKDIR="$(mktemp -d)"
  REPO="${WORKDIR}/repo"
  HOME_DIR="${WORKDIR}/home"
  mkdir -p "${REPO}" "${HOME_DIR}"

  cp -R "${REPO_SRC}/bin" "${REPO}/"
  cp -R "${REPO_SRC}/git" "${REPO}/"
  cp -R "${REPO_SRC}/nvim" "${REPO}/"
  cp -R "${REPO_SRC}/zsh" "${REPO}/"
  cp -R "${REPO_SRC}/neofetch" "${REPO}/"
  cp -R "${REPO_SRC}/zed" "${REPO}/"

  chmod +x "${REPO}/bin/dotfiles"

  export HOME="${HOME_DIR}"
}

teardown() {
  rm -rf "${WORKDIR}"
}

realpath_or_readlink() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
  else
    readlink -f "$1"
  fi
}

@test "help prints usage" {
  run "${REPO}/bin/dotfiles" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"brew sync"* ]]
  [[ "$output" == *"doctor"* ]]
}

@test "link creates expected symlinks" {
  run "${REPO}/bin/dotfiles" link
  [ "$status" -eq 0 ]

  [ -L "${HOME}/.zshrc" ]
  [ -L "${HOME}/.zsh_aliases" ]
  [ -L "${HOME}/.gitconfig" ]
  [ -L "${HOME}/.config/nvim/init.lua" ]
  [ -L "${HOME}/.config/neofetch/config.conf" ]
  [ -L "${HOME}/.config/zed/settings.json" ]

  [ "$(realpath_or_readlink "${HOME}/.zshrc")" = "$(realpath_or_readlink "${REPO}/zsh/.zshrc")" ]
  [ "$(realpath_or_readlink "${HOME}/.gitconfig")" = "$(realpath_or_readlink "${REPO}/git/.gitconfig")" ]
  [ "$(realpath_or_readlink "${HOME}/.config/nvim/init.lua")" = "$(realpath_or_readlink "${REPO}/nvim/.config/nvim/init.lua")" ]
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
  run "${REPO}/bin/dotfiles" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stow packages:"* ]]
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

