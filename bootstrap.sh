#!/usr/bin/env bash

# =============================================================================
# Dotfiles Bootstrap Script
# Safe to run multiple times — skips what's already done.
#
# Run: curl -fsSL <your-raw-github-url>/bootstrap.sh | bash
# Or:  git clone <repo> ~/.dotfiles && cd ~/.dotfiles && ./bootstrap.sh
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { echo -e "\033[1;34m▸ $1\033[0m"; }
ok()    { echo -e "\033[1;32m✓ $1\033[0m"; }
warn()  { echo -e "\033[1;33m⚠ $1\033[0m"; }
err()   { echo -e "\033[1;31m✗ $1\033[0m"; }

step_failed=0
run_step() {
  local name="$1"
  shift
  info "$name"
  if "$@"; then
    ok "$name"
  else
    err "$name — failed (continuing...)"
    step_failed=$((step_failed + 1))
  fi
}

# =============================================================================
# 1. Xcode Command Line Tools
# =============================================================================
install_xcode_clt() {
  if xcode-select -p &>/dev/null; then
    ok "Xcode CLT already installed"
    return 0
  fi
  xcode-select --install
  echo "Press Enter once the installation dialog completes."
  read -r
}
run_step "Xcode Command Line Tools" install_xcode_clt

# =============================================================================
# 2. Homebrew
# =============================================================================
install_homebrew() {
  if command -v brew &>/dev/null; then
    ok "Homebrew already installed"
    return 0
  fi
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}
run_step "Homebrew" install_homebrew

# Ensure brew is on PATH (Apple Silicon)
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# =============================================================================
# 3. Brewfile
# =============================================================================
install_brewfile() {
  cat > "$DOTFILES_DIR/Brewfile" << 'BREWFILE'
# -- CLI tools --
brew "zoxide"
brew "jq"
brew "nvm"

# -- Cask apps --
cask "thebrowsercompany-dia"
cask "warp"
cask "zed"
cask "jetbrains-toolbox"
cask "elmedia-player"
cask "slack"
cask "docker"
cask "insomnia"
cask "raycast"
cask "sublime-merge"
BREWFILE

  brew bundle --file="$DOTFILES_DIR/Brewfile"
}
run_step "Brew packages" install_brewfile

# =============================================================================
# 4. NVM + Node.js
# =============================================================================
install_node() {
  export NVM_DIR="$HOME/.nvm"
  mkdir -p "$NVM_DIR"
  [ -s "$(brew --prefix nvm)/nvm.sh" ] && \. "$(brew --prefix nvm)/nvm.sh"

  if command -v node &>/dev/null; then
    ok "Node.js $(node -v) already installed"
    return 0
  fi
  nvm install --lts
  nvm alias default node
}
run_step "NVM + Node.js" install_node

# =============================================================================
# 5. Claude Code
# =============================================================================
install_claude_code() {
  export NVM_DIR="$HOME/.nvm"
  [ -s "$(brew --prefix nvm)/nvm.sh" ] && \. "$(brew --prefix nvm)/nvm.sh"

  if command -v claude &>/dev/null; then
    ok "Claude Code already installed"
    return 0
  fi
  npm install -g @anthropic-ai/claude-code
}
run_step "Claude Code" install_claude_code

# =============================================================================
# 6. SDKMAN + Java
# =============================================================================
install_java() {
  if [[ ! -d "$HOME/.sdkman" ]]; then
    curl -s "https://get.sdkman.io" | bash
  fi
  source "$HOME/.sdkman/bin/sdkman-init.sh"

  if command -v java &>/dev/null; then
    ok "Java already installed: $(java -version 2>&1 | head -1)"
    return 0
  fi
  sdk install java
}
run_step "SDKMAN + Java" install_java

# =============================================================================
# 7. SSH key for GitHub
# =============================================================================
setup_ssh() {
  local SSH_KEY="$HOME/.ssh/id_ed25519"

  if [[ -f "$SSH_KEY" ]]; then
    ok "SSH key already exists"
    return 0
  fi

  ssh-keygen -t ed25519 -C "hrv.bernardic@gmail.com" -f "$SSH_KEY" -N ""
  eval "$(ssh-agent -s)"

  mkdir -p "$HOME/.ssh"
  cat > "$HOME/.ssh/config" << 'SSHCONFIG'
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
SSHCONFIG

  ssh-add --apple-use-keychain "$SSH_KEY"

  # Allowed signers for commit verification
  echo "hrv.bernardic@gmail.com $(cat ${SSH_KEY}.pub)" > "$HOME/.ssh/allowed_signers"

  echo ""
  warn "Add this key to GitHub TWICE:"
  echo ""
  cat "${SSH_KEY}.pub"
  echo ""
  echo "  1. As Authentication key: https://github.com/settings/ssh/new"
  echo "  2. As Signing key:        https://github.com/settings/ssh/new"
  echo ""
  echo "Press Enter once you've added both..."
  read -r
}
run_step "SSH key for GitHub" setup_ssh

# =============================================================================
# 8. .zshrc
# =============================================================================
setup_zshrc() {
  local ZSHRC="$HOME/.zshrc"
  local MARKER="# managed-by-dotfiles"

  if [[ -f "$ZSHRC" ]] && grep -q "$MARKER" "$ZSHRC"; then
    ok ".zshrc already managed by dotfiles — skipping"
    return 0
  fi

  # Backup existing .zshrc if it exists and isn't ours
  if [[ -f "$ZSHRC" ]]; then
    cp "$ZSHRC" "${ZSHRC}.backup.$(date +%s)"
    warn "Existing .zshrc backed up"
  fi

  cat > "$ZSHRC" << 'ZSHRC'
# managed-by-dotfiles
# =============================================================================
# .zshrc
# =============================================================================

# -- Homebrew --
eval "$(/opt/homebrew/bin/brew shellenv)"

# -- History --
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# -- NVM --
export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix nvm)/nvm.sh" ] && \. "$(brew --prefix nvm)/nvm.sh"
[ -s "$(brew --prefix nvm)/etc/bash_completion.d/nvm" ] && \. "$(brew --prefix nvm)/etc/bash_completion.d/nvm"

# -- SDKMAN --
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# -- Zoxide (smarter cd) --
eval "$(zoxide init zsh)"

# -- Aliases --
alias ll="ls -lah"
alias g="git"
alias gs="git status"
alias gc="git commit"
alias gp="git push"
alias gpl="git pull"
alias gd="git diff"
alias gco="git checkout"
alias gb="git branch"
alias gl="git log --oneline --graph --decorate -20"
alias cls="clear"
alias zed.="zed ."

# -- Custom (add your own below) --

ZSHRC
}
run_step ".zshrc" setup_zshrc

# =============================================================================
# 9. .gitconfig
# =============================================================================
setup_gitconfig() {
  local GITCONFIG="$HOME/.gitconfig"
  local MARKER="# managed-by-dotfiles"

  if [[ -f "$GITCONFIG" ]] && grep -q "$MARKER" "$GITCONFIG"; then
    ok ".gitconfig already managed by dotfiles — skipping"
    return 0
  fi

  if [[ -f "$GITCONFIG" ]]; then
    cp "$GITCONFIG" "${GITCONFIG}.backup.$(date +%s)"
    warn "Existing .gitconfig backed up"
  fi

  cat > "$GITCONFIG" << 'GITCONFIG'
# managed-by-dotfiles
[user]
    name = Hrvoje Bernardić
    email = hrv.bernardic@gmail.com
    signingkey = ~/.ssh/id_ed25519.pub

[core]
    editor = zed --wait
    excludesfile = ~/.gitignore_global

[init]
    defaultBranch = main

[pull]
    rebase = true

[push]
    autoSetupRemote = true

[gpg]
    format = ssh

[gpg "ssh"]
    allowedSignersFile = ~/.ssh/allowed_signers

[commit]
    gpgsign = true

[tag]
    gpgsign = true

[merge]
    tool = sublime_merge

[mergetool "sublime_merge"]
    cmd = smerge mergetool "$BASE" "$LOCAL" "$REMOTE" -o "$MERGED"
    trustExitCode = true

[diff]
    tool = sublime_merge

[difftool "sublime_merge"]
    cmd = smerge diff "$LOCAL" "$REMOTE"

[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    lg = log --oneline --graph --decorate -20
    undo = reset --soft HEAD~1
    amend = commit --amend --no-edit
GITCONFIG
}
run_step ".gitconfig" setup_gitconfig

# =============================================================================
# 10. Global .gitignore
# =============================================================================
setup_gitignore() {
  local GITIGNORE="$HOME/.gitignore_global"

  if [[ -f "$GITIGNORE" ]]; then
    ok ".gitignore_global already exists — skipping"
    return 0
  fi

  cat > "$GITIGNORE" << 'GITIGNORE'
.DS_Store
.idea/
*.iml
node_modules/
.env
.env.local
*.log
.vscode/
GITIGNORE
}
run_step "Global .gitignore" setup_gitignore

# =============================================================================
# 11. Project directory structure
# =============================================================================
setup_dirs() {
  mkdir -p "$HOME/dev/work"
  mkdir -p "$HOME/dev/personal"
}
run_step "Project directories" setup_dirs

# =============================================================================
# 12. macOS defaults
# =============================================================================
apply_macos_defaults() {
  # -- Keyboard --
  defaults write NSGlobalDomain KeyRepeat -int 2
  defaults write NSGlobalDomain InitialKeyRepeat -int 15
  defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

  # -- Trackpad --
  defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
  defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

  # -- Dock --
  defaults write com.apple.dock autohide -bool true

  # -- Finder --
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write com.apple.finder AppleShowAllFiles -bool true
  defaults write com.apple.finder ShowPathbar -bool true
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

  # -- Apply changes --
  killall Finder 2>/dev/null || true
  killall Dock 2>/dev/null || true
}
run_step "macOS preferences" apply_macos_defaults

# =============================================================================
# Done!
# =============================================================================
echo ""
echo "=========================================="
if [[ $step_failed -eq 0 ]]; then
  ok "All done! 🎉"
else
  warn "Done with $step_failed failed step(s) — re-run to retry."
fi
echo "=========================================="
echo ""
info "Next steps:"
echo "  1. Restart your terminal (or run: source ~/.zshrc)"
echo "  2. Open JetBrains Toolbox and install IntelliJ IDEA Ultimate"
echo "  3. Install MonoLisa font manually"
echo "  4. Configure Raycast (disable Spotlight: System Settings → Keyboard → Shortcuts)"
echo "  5. Sign into your apps (Slack, Docker, etc.)"
echo ""
