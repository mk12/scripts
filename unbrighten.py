#!/usr/bin/env python3

import argparse
import os
import pty
import sys


HELP = """
Runs the given commnand, converting any bright ANSI colors to non-bright
versions. Specifically, it converts:

              foreground    background
              ----------    ----------
    black     90  ->  30    100  -> 40
    red       91  ->  31    101  -> 41
    green     92  ->  32    102  -> 42
    yellow    93  ->  33    103  -> 43
    blue      94  ->  34    104  -> 44
    magenta   95  ->  35    105  -> 45
    cyan      96  ->  36    106  -> 46
    white     97  ->  37    107  -> 47

This is useful when using base16 themes because the output can be unreadable for
programs that assume all bright colors are readable.

It only recognizes sequences like \\x1b[91m so it (1) might fail for more
complicated sequences, and (2) might incorrectly change values that were
actually escaped by some mechanism in the grammar that this program is unaware
of (because it does not properly parse it).
"""


def main():
    parser = argparse.ArgumentParser(
        epilog=HELP, formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    pty.spawn(args.command, master_read())


ESC = 0x1B
LSQUARE = ord("[")
M = ord("m")
ZERO = ord("0")
ONE = ord("1")
SEVEN = ord("7")
NINE = ord("9")


def master_read():
    """Transform the output of the command."""

    buf = bytearray()
    fg = False
    digit = b""

    def read(fd):
        data = os.read(fd, 1024)
        if len(data) == 0:
            raise OSError
        new_data = bytearray()
        for i, b in enumerate(data):
            if len(buf) == 0:
                if b == ESC:
                    buf.append(b)
                    continue
            elif len(buf) == 1:
                if b == LSQUARE:
                    buf.append(b)
                    continue
            elif len(buf) == 2:
                if b in (NINE, ONE):
                    fg = b == NINE
                    buf.append(b)
                    continue
            elif len(buf) == 3:
                if fg and b >= ZERO and b <= SEVEN:
                    buf.append(b)
                    digit = b
                    continue
                if not fg and b == ZERO:
                    buf.append(b)
                    continue
            elif len(buf) == 4:
                if fg and b == M:
                    new_data.extend(b"\x1b[3")
                    new_data.append(digit)
                    new_data.append(M)
                    buf.clear()
                    continue
                if not fg and b >= ZERO and b <= SEVEN:
                    buf.append(b)
                    digit = b
                    continue
            elif len(buf) == 5:
                if not fg and b == M:
                    new_data.extend(b"\x1b[4")
                    new_data.append(digit)
                    new_data.append(M)
                    buf.clear()
                    continue
            new_data.extend(buf)
            new_data.append(b)
            buf.clear()
        return bytes(new_data)

    return read


if __name__ == "__main__":
    main()
