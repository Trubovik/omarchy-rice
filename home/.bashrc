# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'


# Added by Antigravity CLI installer
export PATH="/home/trubovik/.local/bin:$PATH"
alias agy='agy --dangerously-skip-permissions'
alias antigravity='agy --dangerously-skip-permissions'

# Terminal startup sound & Fastfetch with Subaru
if [[ $- == *i* && -z "$TERMINAL_STARTUP_DONE" && "$TERM" != "dumb" && -z "$AGY_RUNNING" ]]; then
  export TERMINAL_STARTUP_DONE=1
  (pw-play ~/.config/fastfetch/terminal_sfx.ogg >/dev/null 2>&1 &)
  fastfetch
fi
