#!/usr/bin/env python3

import pytz
import sys
from datetime import datetime
from icalendar import Calendar

if len(sys.argv) != 2:
    print("usage: avgwork.py FILE.ics", file=sys.stderr)
    sys.exit(1)

START = datetime(2016, 8, 29, tzinfo=pytz.timezone("US/Pacific"))

with open(sys.argv[1], "r") as f:
    cal = Calendar.from_ical(f.read())
    seconds = 0
    days = set()
    for w in cal.walk():
        if w.get("summary") == "Work":
            start = w.decoded("dtstart")
            if start < START:
                continue
            days.add(start.date())
            delta = w.decoded("dtend") - start
            seconds += delta.total_seconds()
            print(delta)

    hours = seconds / 3600
    count = len(days)
    print("\n---\n")
    print("Average hours per day: {}", hours / count)
    print("Average hours per week: {}", hours / (count / 5))


