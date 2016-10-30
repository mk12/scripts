#!/usr/bin/env osascript

set journal to "~/ia/Journal/Journal.txt"
tell application "Terminal"
	set lineCount to (do shell script "wc -l < " & journal) as integer
	set randomLine to (random number from 1 to lineCount) as integer
	activate
	do script "vim -c ':Goyo | set bg=light | " & randomLine & "' " & journal
	set current settings of first window to settings set "Solarized Light"
	tell application "System Events" to keystroke "f" using {command down, control down}
end tell
