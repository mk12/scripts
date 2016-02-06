#!/usr/bin/env osascript

set journal to "~/ia/Journal/Journal.md"
tell application "Terminal"
	set lineCount to (do shell script "wc -l < " & journal) as integer
	set randomLine to (random number from 1 to lineCount) as integer
	activate
	do script "vim -c ':call ToggleBackground()' -c ':Goyo' -c '" & randomLine & "' " & journal
	tell application "System Events" to keystroke "f" using {command down, control down}
end tell
