#!/usr/bin/env python3

import re, sys, subprocess
cmd = subprocess.run(
    ["osascript", "-e", "the clipboard as «class HTML»"],
    check=True, stdout=subprocess.PIPE, text=True)
clipboard = cmd.stdout
match = re.fullmatch(r"«data HTML(.*)»\s*", clipboard)
if not match: print(f"error: clipboard not HTML\n\n{clipboard}", file=sys.stderr); sys.exit(1)
html = bytes.fromhex(match[1]).decode()
strip_tags = ["meta", "div", "span"]
strip_atts = ["id", "class", "style"]
for tag in strip_tags: html = re.sub(f"</?{tag}.*?>", "", html)
for att in strip_atts: html = re.sub(f" {att}=\".*?\"", "", html)
print(html)
