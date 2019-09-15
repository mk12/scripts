#!/usr/bin/env python3

from datetime import datetime
import fileinput
import re
import sys

DIGITS = '0123456789'
DATE_FMT = '%Y/%m/%d'

DECIMAL = re.compile(r'[0-9]\.[0-9]')

COMMODITIES = [
    "USD", "EUR", "VMFXX", "VTSAX", "VTIAX", "VBTLX", "VTRTS"
]

DECIMAL_PLACES = {
    "$": 2,
    "USD": 2,
    "EUR": 2,
    "VMFXX": 2,
    "VTSAX": 4,
    "VTIAX": 4,
    "VBTLX": 4,
    "VTRTS": 4,
}


def error(msg):
    print("{}:{}: {}".format(
        fileinput.filename(),
        fileinput.filelineno(),
        msg),
        file=sys.stderr)


def check_amount(s, endcol):
    if '  $' in s:
        commodity = "$"
        i = s.rindex('  $')
        if not s[i+3] in DIGITS + '-':
            error("dollar sign not next to amount")
        amt = s[i+3:endcol]
    else:
        for c in COMMODITIES:
            needle = f"  {c}"
            if needle in s:
                commodity = c
                i = s.rindex(needle)
                if s[i+len(needle)] != ' ':
                    error(f"missing space after {c}")
                amt = s[i+len(needle)+1:endcol]
                break
        else:
            cs = ", ".join(COMMODITIES)
            error(f"expected one of the following commodities: $, {cs}")
            return
    p = DECIMAL_PLACES[commodity]
    if len(amt) < p + 1 or amt[-p-1] != ".":
        if "." in amt:
            got = len(amt) - amt.rindex(".") - 1
            error(f"expected {p} decimal places, only got {got}")
            return
        error(f"expected {p} decimal places, got none")
        return
    whole = amt[:-p-1]
    if whole[0] == '-':
        whole = whole[1:]
    commas = [c for i, c in enumerate(whole) if (len(whole) - i) % 4 == 0]
    if commas != [','] * len(commas):
        error("expected commas to separate thousands")


def get_desired_decimal_places(line):
    for commodity, places in DECIMAL_PLACES.items():
        if commodity in line:
            return places
    return 2


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
        p = get_desired_decimal_places(s[:60])
        if DECIMAL.match(s[:60]) or (len(s) >= 60 and s[59] in DIGITS):
            if len(s) < 58:
                error("misaligned #.# (assumed to be price)")
            if s[60-p-1] != '.':
                error("value has misaligned '.'")
            for i in range(p):
                if not s[60-i-1] in DIGITS:
                    error("expected decimal digit")
            check_amount(s[:60], 60)
        col = 60
        if '{' in s:
            # lot prices, too complicated to check for now
            col += 20
        if '@' in s:
            if len(s) < col + 20:
                error("commodity cost is not flush right")
                continue
            if s[col+1] != '@':
                error("commodity cost has misaligned '@")
            p = get_desired_decimal_places(s[col:col+20])
            if s[col+20-p-1] != '.':
                error("commodity cost has misaligned '.'")
            for i in range(p):
                if not s[col+20-i-1] in DIGITS:
                    error("expected decimal digit")
            check_amount(s[col-18:col+20], col + 20)
            col += 20
        if '=' in s:
            asserted = True
            if len(s) > col + 20 and not s[col:col+20].strip():
                col += 20
            if len(s) < col + 20:
                error("balance assertion is not flush right")
                continue
            if s[col+1] != '=':
                error("balance assertion has misaligned '='")
            p = get_desired_decimal_places(s[col:col+20])
            if s[col+20-p-1] != '.':
                error("balance assertion has misaligned '.'")
            for i in range(p):
                if not s[col+20-i-1] in DIGITS:
                    error("expected decimal digit")
            check_amount(s[col+2:col+20], col + 20)
        elif not asserted and not 'Assets:Cash' in s:
            if ('ATM' in payee or 'Transfer' in payee or 'Pay debt' in note or
                    'Collect debt' in note or 'Visa statement' in note or
                    'domain' in note or 'payroll' in note):
                error("expected balance assertion")
