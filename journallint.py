#!/usr/bin/env python3

import datetime
import fileinput
import string
import sys


def error(msg):
    print(
        "{}:{}: {}".format(fileinput.filename(), fileinput.filelineno(), msg),
        file=sys.stderr,
    )


FORMAT = "%A, %d %B %Y"
prev_date = None
prev_blank = True

for line in fileinput.input():
    if line != "":
        line = line[:-1]
    if line == "":
        if prev_blank:
            error("two blank lines in a row")
    elif line[-1] == " " or line[-1] == "\t":
        error("trailing whitespace")
    elif line.startswith("# "):
        date_str = line[2:].strip()
        try:
            date = datetime.datetime.strptime(date_str, FORMAT).date()
        except ValueError:
            error("invalid date '{}'".format(date_str))
            continue
        fmt = date.strftime(FORMAT).replace(", 0", ", ", 1)
        if date_str != fmt:
            error("date '{}' should be '{}'".format(date_str, fmt))
        if prev_date and date != prev_date + datetime.timedelta(days=1):
            error("dates '{}' and '{}' not consecutive".format(prev_date, date))
        prev_date = date

    prev_blank = line == ""
