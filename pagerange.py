#!/usr/bin/env python

import fileinput

for line in fileinput.input():
    date, pp = line.split(",", 1)
    first, last = pp.split("-", 1)
    print date + ",", int(last) - int(first) + 1
