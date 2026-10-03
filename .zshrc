## menu-style
zstyle ':completion:*' menu select
autoload -Uz compinit && compinit
zstyle ':completion:*' special-dirs true
# case insensitive
zstyle ':completion:*' matcher-list 'm:{a-zA-Z-_}={A-Za-z_-}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
# Tab completion colors
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
# add new installed packages into completions
zstyle ':completion:*' rehash true
# Use better completion for the kill command
#zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;34'
#zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
# use completion cache
zstyle ':completion::complete:*' use-cache true
bindkey -v

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt SHARE_HISTORY

for f in /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
	/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
	[ -f $f ] && source $f && break
done
ZSH_AUTOSUGGEST_STRATEGY='history'

# opencode
export PATH=$HOME/.opencode/bin:$PATH
export PATH=$HOME/go/bin:$PATH
export PATH="$HOME/.local/bin:$PATH"

alias vim="nvim"
export EDITOR=vim
export KUBE_EDITOR=vim
export TERM=xterm-256color

autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats '%b'

precmd() {
	vcs_info
	if [[ -n ${vcs_info_msg_0_} ]]; then
		PROMPT="%F{006}%n%f %F{004}at%f %F{001}%~%f %F{004}on%f %F{003}${vcs_info_msg_0_:0:20}%f "
	else
		PROMPT="%F{006}%n%f %F{004}at%f %F{001}%~%f "
	fi
}

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
[ -f "$HOME/.nvm/nvm.sh" ] && \. "$HOME/.nvm/nvm.sh"

# The next line updates PATH for Nebius CLI.
if [ -f "$HOME/.nebius/path.zsh.inc" ]; then source "$HOME/.nebius/path.zsh.inc"; fi
# The next line enables shell command completion for Nebius CLI.
if [ -f "$HOME/.nebius/completion.zsh.inc" ]; then source "$HOME/.nebius/completion.zsh.inc"; fi
