#!/bin/bash

# This script toggles between solarized dark and solarized light on tmux. It
# tracks the current setting in a dotfile.

light=~/.solarized_light

set_tmux() {
	if [[ -z $TMUX ]]; then
		return
	fi

	case "$1" in
		light) col="colour7" ;;
		dark) col="colour0" ;;
		*) return ;;
	esac

	tmux setw -g status-bg "$col" \; set -g status-left "#[fg=colour15,bg=colour4,bold] #S #[fg=colour4,bg=$col,nobold,nounderscore,noitalics]" \; set -g status-right "#[fg=colour10,bg=$col,nobold,nounderscore,noitalics]#[fg=colour7,bg=colour10] %I:%M %p  %d-%b-%Y " \; setw -g window-status-format "#[fg=colour10,bg=$col] #I #[fg=colour10,bg=$col] #W " \; setw -g window-status-current-format "#[fg=$col,bg=colour11,nobold,nounderscore,noitalics]#[fg=colour7,bg=colour11] #I #[fg=colour7,bg=colour11] #W #[fg=colour11,bg=$col,nobold,nounderscore,noitalics]"
}

if [[ -f $light ]]; then
	rm $light
	set_terminal "Solarized Dark"
	set_tmux "dark"
else
	touch $light
	set_terminal "Solarized Light"
	set_tmux "light"
fi
