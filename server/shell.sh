#!/bin/bash
# Shell Config: Bash aliases, functions, inputrc, history + shell tools
[[ -z $OMARCHY_SERVER_HELPERS ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Setting up Shell Config..."

# Install shell tool dependencies
pkg_install bash-completion eza bat fzf zoxide

# Create directory structure
OMARCHY_SERVER="$HOME/.local/share/omarchy-server"
ensure_dir "$OMARCHY_SERVER/bash/fns"

# --- Environment variables ---
cat > "$OMARCHY_SERVER/bash/envs" << 'EOF'
export EDITOR="${EDITOR:-nvim}"
export SUDO_EDITOR="$EDITOR"
export BAT_THEME=ansi
export PATH=$HOME/.local/bin:$PATH
EOF

# --- History and completion ---
cat > "$OMARCHY_SERVER/bash/shell" << 'EOF'
# History control
shopt -s histappend
HISTCONTROL=ignoreboth
HISTSIZE=32768
HISTFILESIZE="${HISTSIZE}"

# Autocompletion
if [[ ! -v BASH_COMPLETION_VERSINFO && -f /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
fi

# Ensure command hashing is off for mise
set +h
EOF

# --- Shell tool initialization ---
cat > "$OMARCHY_SERVER/bash/init" << 'EOF'
if command -v mise &>/dev/null; then
  eval "$(mise activate bash)"
fi

if command -v starship &>/dev/null; then
  eval "$(starship init bash)"
fi

if command -v zoxide &>/dev/null; then
  eval "$(zoxide init bash)"
fi

if command -v fzf &>/dev/null; then
  [[ -f /usr/share/fzf/completion.bash ]] && source /usr/share/fzf/completion.bash
  [[ -f /usr/share/fzf/key-bindings.bash ]] && source /usr/share/fzf/key-bindings.bash
fi
EOF

# --- Aliases (adapted for server — no desktop/GUI tools) ---
cat > "$OMARCHY_SERVER/bash/aliases" << 'EOF'
# File system
if command -v eza &>/dev/null; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi

alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
alias eff='$EDITOR "$(ff)"'

if command -v zoxide &>/dev/null; then
  alias cd="zd"
  zd() {
    if [[ $# -eq 0 ]]; then
      builtin cd ~ && return
    elif [[ -d $1 ]]; then
      builtin cd "$1"
    else
      z "$@" && pwd || echo "Error: Directory not found"
    fi
  }
fi

# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Tools
alias d='docker'
alias t='tmux attach || tmux new -s Work'
n() { if [[ $# -eq 0 ]]; then command nvim .; else command nvim "$@"; fi; }

# Git
alias g='git'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'
EOF

# --- Functions loader ---
cat > "$OMARCHY_SERVER/bash/functions" << 'EOF'
for f in "$HOME/.local/share/omarchy-server/bash/fns"/*; do
  [[ -f $f ]] && source "$f"
done
EOF

# --- Function: compression ---
cat > "$OMARCHY_SERVER/bash/fns/compression" << 'EOF'
compress() { tar -czf "${1%/}.tar.gz" "${1%/}"; }
alias decompress="tar -xzf"
EOF

# --- Function: ssh-port-forwarding ---
cat > "$OMARCHY_SERVER/bash/fns/ssh-port-forwarding" << 'EOF'
# Forward local ports to a remote host
# Usage: fip <host> <port1> [port2] ...
fip() {
  (( $# < 2 )) && echo "Usage: fip <host> <port1> [port2] ..." && return 1
  local host="$1"
  shift
  for port in "$@"; do
    ssh -f -N -L "$port:localhost:$port" "$host" && echo "Forwarding localhost:$port -> $host:$port"
  done
}

# Disconnect forwarded ports
# Usage: dip <port1> [port2] ...
dip() {
  (( $# == 0 )) && echo "Usage: dip <port1> [port2] ..." && return 1
  for port in "$@"; do
    pkill -f "ssh.*-L $port:localhost:$port" && echo "Stopped forwarding port $port" || echo "No forwarding on port $port"
  done
}

# List active port forwards
lip() {
  pgrep -af "ssh.*-L [0-9]+:localhost:[0-9]+" || echo "No active forwards"
}
EOF

# --- Function: tmux dev layouts ---
cat > "$OMARCHY_SERVER/bash/fns/tmux" << 'EOF'
# Create a Tmux Dev Layout with editor + command + terminal
# Usage: tdl <command> [<second_command>]
tdl() {
  [[ -z $1 ]] && { echo "Usage: tdl <command> [<second_command>]"; return 1; }
  [[ -z $TMUX ]] && { echo "You must start tmux to use tdl."; return 1; }

  local current_dir="${PWD}"
  local editor_pane ai_pane ai2_pane
  local cmd1="$1"
  local cmd2="$2"

  editor_pane="$TMUX_PANE"
  tmux rename-window -t "$editor_pane" "$(basename "$current_dir")"
  tmux split-window -v -p 15 -t "$editor_pane" -c "$current_dir"
  ai_pane=$(tmux split-window -h -p 30 -t "$editor_pane" -c "$current_dir" -P -F '#{pane_id}')

  if [[ -n $cmd2 ]]; then
    ai2_pane=$(tmux split-window -v -t "$ai_pane" -c "$current_dir" -P -F '#{pane_id}')
    tmux send-keys -t "$ai2_pane" "$cmd2" C-m
  fi

  tmux send-keys -t "$ai_pane" "$cmd1" C-m
  tmux send-keys -t "$editor_pane" "$EDITOR ." C-m
  tmux select-pane -t "$editor_pane"
}

# Create a multi-pane swarm layout with the same command in each pane
# Usage: tsl <pane_count> <command>
tsl() {
  [[ -z $1 || -z $2 ]] && { echo "Usage: tsl <pane_count> <command>"; return 1; }
  [[ -z $TMUX ]] && { echo "You must start tmux to use tsl."; return 1; }

  local count="$1"
  local cmd="$2"
  local current_dir="${PWD}"
  local -a panes

  tmux rename-window -t "$TMUX_PANE" "$(basename "$current_dir")"
  panes+=("$TMUX_PANE")

  while (( ${#panes[@]} < count )); do
    local new_pane
    local split_target="${panes[-1]}"
    new_pane=$(tmux split-window -h -t "$split_target" -c "$current_dir" -P -F '#{pane_id}')
    panes+=("$new_pane")
    tmux select-layout -t "${panes[0]}" tiled
  done

  for pane in "${panes[@]}"; do
    tmux send-keys -t "$pane" "$cmd" C-m
  done

  tmux select-pane -t "${panes[0]}"
}
EOF

# --- Inputrc (readline config) ---
cat > "$OMARCHY_SERVER/bash/inputrc" << 'EOF'
set meta-flag on
set input-meta on
set output-meta on
set convert-meta off
set completion-ignore-case on
set completion-prefix-display-length 2
set show-all-if-ambiguous on
set show-all-if-unmodified on

# Arrow keys search history matching typed prefix
"\e[A": history-search-backward
"\e[B": history-search-forward
"\e[C": forward-char
"\e[D": backward-char

set mark-symlinked-directories on
set match-hidden-files off
set page-completions off
set completion-query-items 200
set visible-stats on
set skip-completed-text on
set colored-stats on

# Tab/Shift+Tab to cycle completions
TAB: menu-complete
"\e[Z": menu-complete-backward
set menu-complete-display-prefix on
EOF

# --- Main rc (sources everything) ---
cat > "$OMARCHY_SERVER/bash/rc" << 'EOF'
[[ $- != *i* ]] && return

source ~/.local/share/omarchy-server/bash/envs
source ~/.local/share/omarchy-server/bash/shell
source ~/.local/share/omarchy-server/bash/init
source ~/.local/share/omarchy-server/bash/aliases
source ~/.local/share/omarchy-server/bash/functions
[[ $- == *i* ]] && bind -f ~/.local/share/omarchy-server/bash/inputrc
EOF

# --- Add source line to .bashrc ---
if ! grep -qF "omarchy-server" "$HOME/.bashrc" 2>/dev/null; then
  echo "" >> "$HOME/.bashrc"
  echo "# Omarchy Server Shell Config" >> "$HOME/.bashrc"
  echo '[[ -f ~/.local/share/omarchy-server/bash/rc ]] && source ~/.local/share/omarchy-server/bash/rc' >> "$HOME/.bashrc"
  success "Added omarchy-server source to ~/.bashrc"
else
  success "~/.bashrc already configured"
fi

success "Shell config installed"
