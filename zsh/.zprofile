source $HOME/.env

autoload edit-command-line; zle -N edit-command-line
bindkey -M vicmd v edit-command-line
