#!/bin/bash
# setup-shell.sh - Configure shell environment

# Create Starship config directory
mkdir -p ~/.config

# Configure Starship with a nice preset
cat << 'EOF' > ~/.config/starship.toml
# Starship configuration

[container]
format = "[$symbol]($style) "
style = "bold blue"

[directory]
truncation_length = 3
truncate_to_repo = true

[git_branch]
format = "[$symbol$branch]($style) "

[git_status]
format = "([$all_status$ahead_behind]($style) )"

[nodejs]
format = "[$symbol($version )]($style)"
symbol = "⬢ "

[python]
format = "[$symbol($version )]($style)"

[time]
disabled = false
format = "[$time]($style) "
time_format = "%H:%M"
style = "dimmed white"
EOF

# Configure tmux
cat << 'EOF' > ~/.tmux.conf
# Enable mouse support
set -g mouse on

# Set prefix to Ctrl-a (like screen)
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix

# Easy split pane commands
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Easy pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1

# Enable 256 colors
set -g default-terminal "screen-256color"

# Increase scrollback buffer size
set -g history-limit 10000

# Status bar customization
set -g status-bg black
set -g status-fg white
set -g status-left '#[fg=green]#S '
set -g status-right '#[fg=yellow]#(whoami)@#H'
EOF

# Add aliases and shell configuration
cat << 'EOF' >> ~/.zshrc

# Custom aliases
alias claude='claude --dangerously-skip-permissions'
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'
alias gco='git checkout'

# Better history
export HISTSIZE=10000
export SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS

# Editor
export EDITOR='vim'
export VISUAL='vim'

# Git delta for better diffs
export GIT_PAGER='delta'
EOF

echo "✅ Shell environment configured with Starship prompt"