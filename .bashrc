#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"

# ── completion and history ───────────────────────────────────────────────
# Programmable completion for arguments: git branches, pacman packages,
# systemctl units and so on. Guarded because the package is optional —
# install with:  sudo pacman -S bash-completion
if [ -r /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi

# Bigger history, shared across terminals, no duplicates or leading-space
# commands. histappend matters: without it the last shell to exit overwrites
# everything the others recorded.
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
HISTIGNORE="ls:ll:cd:pwd:exit:clear:history"
HISTTIMEFORMAT="%F %T  "
shopt -s histappend cmdhist

# Typo tolerance and quality-of-life.
shopt -s autocd        # "Projects" alone cds into it
shopt -s cdspell       # fixes minor typos in cd targets
shopt -s dirspell      # and in directory names during completion
shopt -s globstar      # ** matches across directories
shopt -s checkwinsize

# yazi wrapper: `y` leaves the shell in whatever directory you browsed to.
# Plain `yazi` always returns you to where you started.
y() {
    local tmp cwd
    tmp="$(mktemp -t yazi-cwd.XXXXXX)"
    yazi "$@" --cwd-file="$tmp"
    cwd="$(cat -- "$tmp")"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
}

# Greeting on new terminals.
#
# The interactive guard at the top of this file already blocks `bash -c`, but
# three more cases need excluding or the banner turns into noise:
#   SHLVL -eq 1   only the outermost shell, not subshells you spawn by hand
#   -t 1          a real tty, so piped or captured output stays clean
#   $-  vs vi/nvim's :terminal, git rebase editors, and similar embedded shells
if [[ $SHLVL -eq 1 && -t 1 && -z "$INSIDE_EMACS" && -z "$VIMRUNTIME" ]]; then
    command -v fastfetch >/dev/null 2>&1 && fastfetch
fi
