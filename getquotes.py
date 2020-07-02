#!/usr/bin/env python3

import argparse
import datetime
from lxml import html
from pathlib import Path
import requests

PRICE_DB_FILE = Path.home() / ".local/share/ledger/pricedb"

BASE = "USD"
CURRENCIES = ["CAD", "EUR"]
MUTUAL_FUNDS = {"VMFXX": "0033", "VTSAX": "0585", "VTIAX": "0569", "VBTLX": "0584"}


def fmt_currency(currency):
    return "$" if currency == "CAD" else currency


def get_business_day(date):
    days = {5: 1, 6: 2}.get(date.weekday(), 0)
    return date - datetime.timedelta(days=days)


def get_exchange_rates(date):
    date_str = date.strftime("%Y-%m-%d")
    params = {"base": BASE, "symbols": ",".join(CURRENCIES)}
    r = requests.get(f"https://api.exchangeratesapi.io/{date_str}", params=params)
    rates = r.json()["rates"]
    for currency in CURRENCIES:
        yield fmt_currency(BASE), fmt_currency(currency), str(rates[currency])


def get_fund_prices(date):
    date_str = get_business_day(date).strftime("%m/%d/%Y")
    for symbol, number in MUTUAL_FUNDS.items():
        params = {
            "radio": 1,
            "results": "get",
            "FundType": "VanguardFunds",
            "FundIntExt": "INT",
            "FundId": number,
            "fundName": number,
            "fundValue": number,
            "radiobutton2": 1,
            "beginDate": date_str,
            "endDate": date_str,
        }
        r = requests.get(
            "https://personal.vanguard.com/us/funds/tools/pricehistorysearch",
            params=params,
        )
        tree = html.fromstring(r.content)
        mode = 0
        price = None
        for cell in tree.xpath("//td/text()"):
            cell = cell.strip()
            if not cell:
                continue
            if mode == 0:
                if cell.startswith("Fund Inception Date"):
                    mode = 1
            elif mode == 1:
                if cell.startswith("$"):
                    price = cell[1:]
                    break
        if not price:
            raise Exception(f"Failed to find price for {symbol}")
        yield symbol, fmt_currency(BASE), price


def get_trust_select_prices(date):
    symbol = "VTRTS"
    r = requests.get(
        "https://institutional.vanguard.com/web/cf/product-details/model.json?paths=%5B%5B%5B%27allFundCharacteristicsName%27%2C%27allFundName%27%5D%5D%2C%5B%5B%27benchmarkAnalyticsLatestData%27%2C%27dailyNavPriceLatest%27%2C%27fundAnalyticsLatestRiskData%27%2C%27fundDailyYieldLatest%27%5D%2C%271685%27%5D%2C%5B%5B%27fiftyTwoWeekNavPrice%27%2C%27fundAnalyticsSpecialDateLatest%27%2C%27holdingDetailsDates%27%5D%2C%271685%2C%27%5D%2C%5B%27frapiBenchmarkContent%27%2C%271685%2C%27%2C%270031%27%5D%2C%5B%27frapiContentWithCodes%27%2C%271685%2C%27%2C%27N001%27%5D%2C%5B%27dailyNavHistory%27%2C%271685%2C%27%2C%5B%272015-06-30%27%2C%272018-03-15%27%5D%2C%272019-09-15%27%5D%5D&method=get"
    )
    price = r.json()["jsonGraph"]["dailyNavPriceLatest"]["value"][0]["priceItem"][0][
        "price"
    ]
    yield symbol, fmt_currency(BASE), str(price)


def main():
    parser = argparse.ArgumentParser(description="generate price data for ledger")
    parser.add_argument("-c", "--clear", action="store_true", help="clear file")
    args = parser.parse_args()

    parent = PRICE_DB_FILE.parent
    if not parent.exists():
        parent.mkdir(parents=True)

    date = datetime.date.today()
    date_str = date.strftime(r"%Y/%m/%d")
    with open(PRICE_DB_FILE, "r") as file:
        lines = file.readlines()
    lines.sort()
    with open(PRICE_DB_FILE, "w") as file:
        if not args.clear:
            for line in lines:
                line = line.strip()
                if not line:
                    continue
                if line.startswith(f"P {date_str} "):
                    break
                print(line, file=file)
        for get in [get_exchange_rates, get_fund_prices, get_trust_select_prices]:
            for price in get(date):
                line = f"P {date_str} 00:00:00 {' '.join(price)}"
                print(line)
                print(line, file=file)


if __name__ == "__main__":
    print("If it doesn't work, look at prices in the Holdings tab")
    print(f"and manually enter in {PRICE_DB_FILE}.\n")
    main()
