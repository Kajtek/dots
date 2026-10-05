#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias ll='ls -la --color=auto'
alias grep='grep --color=auto'

# Starship prompt
eval "$(starship init bash)"

export PATH="$HOME/.local/bin:$PATH"
