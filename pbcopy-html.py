#!/usr/bin/env python3

import sys, subprocess
html = "<meta charset='utf-8'>" + sys.stdin.read()
hex = html.encode().hex()
clipboard = f"«data HTML{hex}»"
subprocess.run(["osascript", "-e", f"set the clipboard to {clipboard}"], check=True)
