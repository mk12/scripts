#!/usr/bin/env python3

from datetime import datetime
import fileinput
import sys

DIGITS = '0123456789'
DATE_FMT = '%Y/%m/%d'

def error(msg):
    print("{}:{}: {}".format(
        fileinput.filename(),
        fileinput.filelineno(),
        msg),
        file=sys.stderr)

def check_amount(s, endcol):
    if '  $' in s:
        i = s.rindex('  $')
        if not s[i+3] in DIGITS + '-':
            error("dollar sign not next to amount")
        amt = s[i+3:endcol]
    elif '  USD' in s:
        i = s.rindex('  USD')
        if s[i+5] != ' ':
            error("missing space after USD")
        amt = s[i+6:endcol]
    else:
        error("expected $ or USD")
        return
    whole = amt[:-3]
    if whole[0] == '-':
        whole = whole[1:]
    commas = [c for i, c in enumerate(whole) if (len(whole) - i) % 4 == 0]
    if commas != [','] * len(commas):
        error("expected commas to separate thousands")

mode = 0
note = ""
payee = ""
asserted = False
prev_dates = None
for line in fileinput.input():
    s = line.rstrip()
    if mode == 0:
        if s == ";;; Transactions":
            mode = 1
    elif mode == 1:
        xact = False
        if len(s) > 16 and s[4] == '/' and s[7] == '/' and s[10] == '=':
            xact = True
            d = datetime.strptime(s[:10], DATE_FMT)
            aux_str = s[11:s.index(' ')]
            try:
                aux = datetime.strptime(aux_str, DATE_FMT)
            except ValueError:
                error("can't parse aux date '{}'".format(aux_str))
                continue
            if aux == d:
                error("aux date is redundant")
            if aux > d:
                error("aux date is later, should be earlier")
            dates = d, aux
            if prev_dates and dates < prev_dates:
                error("Date {}={} is earlier than previous date {}={}"
                      .format(d, aux, prev_dates[0], prev_dates[1]))
            prev_dates = dates
        elif len(s) > 13 and s[4] == '/' and s[7] == '/':
            xact = True
            d = datetime.strptime(s[:10], DATE_FMT)
            dates = d, d
            if prev_dates and dates < prev_dates:
                error("Date {}={} is earlier than previous date {}={}"
                      .format(d, aux, prev_dates[0], prev_dates[1]))
            prev_dates = dates
        if xact:
            mode = 2
            if '!' in s:
                i = s.index('!')
            elif '*' in s:
                i = s.index('*')
            else:
                error("expected ! or *")
                continue
            if s[i-1] != ' ' or s[i+1] != ' ':
                error("expected space around ! or *")
                continue
            payee = s[i+2:]
    elif mode == 2:
        mode = 3
        if s[:6] == "    ; ":
            note = s[6:]
        else:
            error("missing note on transaction: '{}'".format(s[:6]))
    elif mode == 3:
        if s == "":
            mode = 1
            asserted = False
            continue
        if '.' in s[:60] or (len(s) >= 60 and s[59] in DIGITS):
            if s[57] != '.':
                error("value has misaligned '.'")
            if not s[58] in DIGITS:
                error("expected cent digit")
            if not s[59] in DIGITS:
                error("expected cent digit")
            check_amount(s[:60], 60)
        if '=' in s:
            asserted = True
            if s[61] != '=':
                error("balance assertion has misaligned '='")
            if s[77] != '.':
                error("balance assertion has misaligned '.'")
            if not s[78] in DIGITS:
                error("expected cent digit in balance assertion")
            if not s[79] in DIGITS:
                error("expected cent digit in balance assertion")
            check_amount(s[62:80], 80)
        elif not asserted and not 'Assets:Cash' in s:
            if ('ATM' in payee or 'Transfer' in payee or 'Pay debt' in note or
                    'Collect debt' in note or 'Visa statement' in note or
                    'domain' in note or 'payroll' in note):
                error("expected balance assertion")
