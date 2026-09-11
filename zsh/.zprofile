source $HOME/.env

typeset -g COPY_FILE_CONTENTS_DIR="${${(%):-%N}:A:h}"
export PATH="$COPY_FILE_CONTENTS_DIR:$PATH"

copy-file-contents() {
	command "$COPY_FILE_CONTENTS_DIR/copy-file-contents" "$@"
}

autoload edit-command-line; zle -N edit-command-line
bindkey -M vicmd v edit-command-line

alias icat='kitten icat'
