#!/bin/bash
# Git Config: Smart defaults (rebase, rerere, aliases)
[[ -z $OMARCHY_SERVER_HELPERS ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Git Config..."

pkg_install git

ensure_dir "$HOME/.config/git"

# Only write config if it doesn't exist (don't overwrite user customizations)
if [[ ! -f "$HOME/.config/git/config" ]]; then
  cat > "$HOME/.config/git/config" << 'EOF'
[alias]
	co = checkout
	br = branch
	ci = commit
	st = status
[init]
	defaultBranch = main
[pull]
	rebase = true            # Rebase (instead of merge) on pull
[push]
	autoSetupRemote = true   # Automatically set upstream branch on push
[diff]
	algorithm = histogram    # Clearer diffs on moved/edited lines
	colorMoved = plain       # Highlight moved blocks in diffs
	mnemonicPrefix = true    # More intuitive refs in diff output
[commit]
	verbose = true           # Include diff comment in commit message template
[column]
	ui = auto                # Output in columns when possible
[branch]
	sort = -committerdate    # Sort branches by most recent commit first
[tag]
	sort = -version:refname  # Sort version numbers as you would expect
[rerere]
	enabled = true           # Record and reuse conflict resolutions
	autoupdate = true        # Apply stored conflict resolutions automatically
EOF
  success "Git config written to ~/.config/git/config"
else
  warn "~/.config/git/config already exists, skipping (won't overwrite)"
fi

# Prompt for name/email if not already set
if [[ -z $(git config --global user.name 2>/dev/null) ]]; then
  echo
  read -rp "  Git user name: " git_name
  if [[ -n $git_name ]]; then
    git config --global user.name "$git_name"
    success "Set git user.name to '$git_name'"
  fi
fi

if [[ -z $(git config --global user.email 2>/dev/null) ]]; then
  read -rp "  Git user email: " git_email
  if [[ -n $git_email ]]; then
    git config --global user.email "$git_email"
    success "Set git user.email to '$git_email'"
  fi
fi

success "Git config installed"
