#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Dotfiles Bootstrap Script
# Run: curl -fsSL <your-raw-github-url>/bootstrap.sh | bash
# Or:  git clone <repo> ~/.dotfiles && cd ~/.dotfiles && ./bootstrap.sh
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$DOTFILES_DIR/bootstrap.log"

info()  { echo -e "\033[1;34m▸ $1\033[0m"; }
ok()    { echo -e "\033[1;32m✓ $1\033[0m"; }
warn()  { echo -e "\033[1;33m⚠ $1\033[0m"; }
err()   { echo -e "\033[1;31m✗ $1\033[0m"; }

# =============================================================================
# 1. Xcode Command Line Tools (needed for git & compilation)
# =============================================================================
info "Checking Xcode Command Line Tools..."
if ! xcode-select -p &>/dev/null; then
  info "Installing Xcode CLT (a dialog may pop up)..."
  xcode-select --install
  echo "Press Enter once the installation is complete."
  read -r
fi
ok "Xcode CLT installed"

# =============================================================================
# 2. Homebrew
# =============================================================================
info "Checking Homebrew..."
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi
ok "Homebrew installed"

# =============================================================================
# 3. Brewfile — install everything via brew bundle
# =============================================================================
info "Installing packages from Brewfile..."
cat > "$DOTFILES_DIR/Brewfile" << 'BREWFILE'
# -- CLI tools --
brew "zoxide"
brew "jq"
brew "nvm"

# -- Cask apps --
cask "dia"
cask "warp"
cask "zed"
cask "jetbrains-toolbox"    # Manages IntelliJ Ultimate (+ updates)
cask "elmedia-player"
cask "slack"
cask "docker"
cask "insomnia"
cask "raycast"
cask "sublime-merge"
BREWFILE

brew bundle --file="$DOTFILES_DIR/Brewfile" || warn "Some casks may need manual install — check output above"
ok "Brew packages installed"

# =============================================================================
# 4. NVM + Node.js
# =============================================================================
info "Setting up NVM + Node.js..."
export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"
# Homebrew nvm requires sourcing
[ -s "$(brew --prefix nvm)/nvm.sh" ] && \. "$(brew --prefix nvm)/nvm.sh"
nvm install --lts
nvm use --lts
nvm alias default node
ok "Node.js $(node -v) installed via NVM"

# =============================================================================
# 5. Claude Code (via npm)
# =============================================================================
info "Installing Claude Code..."
npm install -g @anthropic-ai/claude-code
ok "Claude Code installed"

# =============================================================================
# 6. SDKMAN + Java
# =============================================================================
info "Setting up SDKMAN..."
if [[ ! -d "$HOME/.sdkman" ]]; then
  curl -s "https://get.sdkman.io" | bash
fi
source "$HOME/.sdkman/bin/sdkman-init.sh"
info "Installing latest Java LTS..."
sdk install java
ok "Java installed via SDKMAN"

# =============================================================================
# 7. SSH key for GitHub
# =============================================================================
info "Setting up SSH key for GitHub..."
SSH_KEY="$HOME/.ssh/id_ed25519"
if [[ ! -f "$SSH_KEY" ]]; then
  ssh-keygen -t ed25519 -C "hrv.bernardic@gmail.com" -f "$SSH_KEY" -N ""
  eval "$(ssh-agent -s)"

  # Create/update SSH config
  mkdir -p "$HOME/.ssh"
  cat > "$HOME/.ssh/config" << 'SSHCONFIG'
Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
SSHCONFIG

  ssh-add --apple-use-keychain "$SSH_KEY"
  ok "SSH key generated"
  echo ""
  warn "Add this public key to GitHub → Settings → SSH Keys:"
  echo ""
  cat "${SSH_KEY}.pub"
  echo ""
  echo "  https://github.com/settings/ssh/new"
  echo ""
  echo "Press Enter once you've added it..."
  read -r
else
  ok "SSH key already exists"
fi

# =============================================================================
# 8. Dotfiles — .zshrc
# =============================================================================
info "Setting up .zshrc..."
cat > "$HOME/.zshrc" << 'ZSHRC'
# =============================================================================
# .zshrc — managed by dotfiles
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
alias dc="docker compose"
alias cls="clear"
alias zed.="zed ."

# -- PATH additions --
# (add custom paths here)
ZSHRC
ok ".zshrc configured"

# =============================================================================
# 9. Dotfiles — .gitconfig
# =============================================================================
info "Setting up .gitconfig..."
cat > "$HOME/.gitconfig" << 'GITCONFIG'
[user]
    name = Hrvoje Bernardić
    email = hrv.bernardic@gmail.com

[core]
    editor = zed --wait
    excludesfile = ~/.gitignore_global

[init]
    defaultBranch = main

[pull]
    rebase = true

[push]
    autoSetupRemote = true

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
ok ".gitconfig configured"

# =============================================================================
# 10. Global .gitignore
# =============================================================================
info "Setting up global .gitignore..."
cat > "$HOME/.gitignore_global" << 'GITIGNORE'
.DS_Store
.idea/
*.iml
node_modules/
.env
.env.local
*.log
.vscode/
GITIGNORE
ok "Global .gitignore configured"

# =============================================================================
# Done!
# =============================================================================
echo ""
echo "=========================================="
ok "All done! 🎉"
echo "=========================================="
echo ""
info "Next steps:"
echo "  1. Restart your terminal (or run: source ~/.zshrc)"
echo "  2. Open JetBrains Toolbox and install IntelliJ IDEA Ultimate"
echo "  3. Install MonoLisa font manually"
echo "  4. Configure Raycast (disable Spotlight: System Settings → Keyboard → Shortcuts)"
echo "  5. Sign into your apps (Slack, Docker, etc.)"
echo ""
