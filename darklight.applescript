#!/usr/bin/env osascript

tell application "Terminal"
	set profile to "Solarized Light"
	if (name of current settings of first window) is "Solarized Light" then
		set profile to "Solarized Dark"
	end if
	set current settings of first window to settings set profile
end tell
