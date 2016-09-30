#!/usr/bin/env python3

import pytz
import sys
from datetime import datetime
from icalendar import Calendar

START = datetime(2016, 8, 29, tzinfo=pytz.timezone("US/Pacific"))
END = datetime(2016, 12, 16, tzinfo=pytz.timezone("US/Pacific"))
# START = datetime(2016, 1, 1, tzinfo=pytz.timezone("US/Pacific"))
# END = datetime(2016, 5, 1, tzinfo=pytz.timezone("US/Pacific"))


def hours_per_day(cal, start, end):
    seconds = 0
    days = set()

    for w in cal.walk():
        if w.get("summary") == "Work":
            start = w.decoded("dtstart")
            if start < START:
                continue
            if start > END:
                break
            days.add(start.date())
            delta = w.decoded("dtend") - start
            seconds += delta.total_seconds()

    return seconds / 3600 / len(days)


def main():
    if len(sys.argv) != 2:
        print("usage: avgwork.py FILE.ics", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], "r") as f:
        cal = Calendar.from_ical(f.read())

    hours = hours_per_day(cal, START, END)

    print("From {} to {}".format(START, END))
    print("  Average hours/day: {}".format(hours))
    print("  Average hours/week: {}".format(hours * 5))


if __name__ == "__main__":
    main()
