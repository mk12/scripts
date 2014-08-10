#!/usr/bin/env python

# I wrote this for a lab report in SCH4U.

w = 120.0
d = 0.0
rf = 0.0
rr = 0.0

for i in range(15):
    print "|%2d|%5.1f|%4.1f|%4.1f|%3.1f|" %(i, w, d, rf, rr)
    rf = w * 0.3
    rr = d * 0.1
    w = w - rf + rr
    d = d + rf - rr
