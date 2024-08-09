#!/usr/bin/env python3

import subprocess
import sys
import tempfile

BASE = "b"
CURRENT = "c"
INCOMING = "i"

d = []
s = ""
for line in subprocess.check_output(["pbpaste"]).decode().split("\n"):
    if line.startswith("<<<<<<<"):
        d.append({})
        s = ""
    elif line.startswith("|||||||"):
        d[len(d) - 1][CURRENT] = s
        s = ""
    elif line.startswith("======="):
        d[len(d) - 1][BASE] = s
        s = ""
    elif line.startswith(">>>>>>>"):
        d[len(d) - 1][INCOMING] = s
        s = ""
    else:
        s += line + "\n"

if not d:
    print("Could not find any conflicts", file=sys.stderr)
    sys.exit(1)


def write(f, str):
    f.seek(0)
    f.truncate()
    print(str, file=f)
    f.flush()
    return f.name


def getch():
    import termios
    import sys, tty

    def _getch():
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            ch = sys.stdin.read(1)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        return ch

    return _getch()


with tempfile.NamedTemporaryFile("w") as f0, tempfile.NamedTemporaryFile("w") as f1:
    i = 0 # hunk index
    k = 0 # index in 'comparisions'
    comparisons = [
        (BASE, CURRENT),
        (BASE, INCOMING),
        (INCOMING, CURRENT),
    ]
    paging = "never"
    while True:
        sys.stderr.write("\x1b[2J\x1b[H")
        src, dst = comparisons[k]
        msg = f"Hunk {i+1}/{len(d)} -- Comparing {src} -> {dst}"
        print(msg)
        f0.seek(0)
        f0.truncate()
        print(d[i][src], file=f0)
        f1.seek(0)
        f1.truncate()
        print(d[i][dst], file=f1)
        subprocess.run(
            [
                "delta",
                f"--paging={paging}",
                write(f0, d[i][src]),
                write(f1, d[i][dst]),
            ]
        )
        print("\n" + msg)
        paging = "never"
        while True:
            cmd = getch()
            if cmd == "q":
                sys.exit(0)
            elif cmd == "j":
                i = min(i + 1, len(d) - 1)
            elif cmd == "k":
                i = max(i - 1, 0)
            elif cmd == " ":
                k = (k + 1) % len(comparisons)
            elif cmd == "p":
                paging = "always"
            else:
                continue
            break
