#!/usr/bin/env osascript

tell application "Terminal"
	activate
	do script "ssh -t mkember.int.snowflakecomputing.com 'cd Snowflake/trunk && bash'"
	delay 0.1
	tell application "System Events" to keystroke "t" using {command down}
	tell application "System Events" to keystroke "t" using {command down}
	tell application "System Events" to keystroke "t" using {command down}
	tell application "System Events" to keystroke "t" using {command down}
	set selected of tab 1 of window 1 to true
	delay 0.2
	tell application "System Events" to keystroke "k" using {command down}
	set selected of tab 2 of window 1 to true
	delay 0.2
	tell application "System Events" to keystroke "k" using {command down}
	set selected of tab 3 of window 1 to true
	delay 0.2
	tell application "System Events" to keystroke "k" using {command down}
	set selected of tab 4 of window 1 to true
	delay 0.2
	tell application "System Events" to keystroke "k" using {command down}
	set selected of tab 5 of window 1 to true
	delay 0.2
	tell application "System Events" to keystroke "k" using {command down}
	tell application "System Events" to keystroke "f" using {command down, control down}
end tell
