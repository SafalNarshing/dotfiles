#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"

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
