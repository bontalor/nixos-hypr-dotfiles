# History
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000

# Completion
zstyle :compinstall filename "$HOME/.zshrc"
autoload -Uz compinit
compinit

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'


# Prompt Colors
USER_BG=4
USER_FG=15

AT_BG=8
AT_FG=15

HOST_BG=5
HOST_FG=15

DIR_BG=8
DIR_FG=15

# Prompt character
if [[ $EUID -eq 0 ]]; then
    PROMPT_CHAR="#"
else
    PROMPT_CHAR="$"
fi

# Prompt
PROMPT="%K{$USER_BG}%F{$USER_FG} %n %f%k"\
"%K{$AT_BG}%F{$AT_FG} @ %f%k"\
"%K{$HOST_BG}%F{$HOST_FG} %m %f%k"\
"%K{$DIR_BG}%F{$DIR_FG} %1~ %f%k $PROMPT_CHAR "

# Colors
autoload -U colors && colors

# Keybindings
bindkey -e

# Ctrl + Arrow word movement (common sequences)
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[5D' backward-word
bindkey '^[[5C' forward-word

# Aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias open='xdg-open'
alias nrs='sudo nixos-rebuild switch'
alias gpp="git add . && git commit -m 'asdf' && git push"

# Fun
autoload -U tetriscurses
