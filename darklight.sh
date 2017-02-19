#!/bin/bash

# This script toggles between solarized dark and solarized light. It updates the
# profiles of all open macOS terminals, and tmux color settings. When invoked
# with the -t option, it just updates tmux to match the terminal color.

light=~/.solarized_light

set_terminal() {
	osascript <<-EOS
	tell application "Terminal"
		set default settings to settings set "$1"
		repeat with n from 1 to (count windows)
			repeat with m from 1 to (count tabs in window n)
				set current settings of tab m of window n to settings set "$1"
			end repeat
		end repeat
	end tell
	EOS
}

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

# Update tmux settings on -t.
if [[ $1 == "-t" ]]; then
	if [[ -f $light ]]; then
		set_tmux "light"
	else
		set_tmux "dark"
	fi
	exit 0
fi

# Otherwise, toggle color scheme.
if [[ -f $light ]]; then
	rm $light
	set_terminal "Solarized Dark"
	set_tmux "dark"
else
	touch $light
	set_terminal "Solarized Light"
	set_tmux "light"
fi
