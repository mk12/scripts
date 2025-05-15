#!/usr/bin/env python3

import argparse
import hashlib
import random
import string
import subprocess
import sys
import time

def sha1(s):
    return hashlib.sha1(s.encode()).hexdigest()

parser = argparse.ArgumentParser(description="Makes a NearlyFreeSpeech API call")
parser.add_argument("-l", "--login", required=True)
parser.add_argument("-k", "--api-key", required=True)
parser.add_argument("-b", "--body")
parser.add_argument("uri")
args = parser.parse_args()

if not args.uri.startswith("/"):
    print("uri must start with /", file=sys.stderr)
    sys.exit(1)

timestamp = int(time.time())
alnum = [*string.ascii_letters, *string.digits]
salt = "".join(random.choice(alnum) for _ in range(16))
body_hash = sha1(args.body or "")

text = f"{args.login};{timestamp};{salt};{args.api_key};{args.uri};{body_hash}"
header = f"X-NFSN-Authentication: {args.login};{timestamp};{salt};{sha1(text)}"
full_uri = "https://api.nearlyfreespeech.net" + args.uri

print(f"URI: {full_uri}")
print(f"Deriving hash from: {text}")
print(f"Header: {header}")

curl_cmd = ["curl", full_uri, "--header", header]
if args.body:
    curl_cmd.extend(["--data-raw", args.body])
subprocess.run(curl_cmd, check=True)
