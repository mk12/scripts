#!/usr/bin/env perl

# This script changes the date format in a Markdown journal file from
# nested year/month/day headings to flat dates before each entry. I really
# should have used this format from the beginning -- it makes it much easier to
# search for a particular day.

use v5.10;
use strict;
use warnings;

my ($year, $month, $day, $weekday);
my $seek = "year";
my $lastempty = "no";

my $yp = qr/^\# (\d+)$/;
my $mp = qr/^\#\# (\w+)$/;
my $dp = qr/^\#\#\# (\w+) the (\d+)(st|nd|rd|th)$/;

while (<>) {
	if ($seek eq "year" || $seek eq "any" and /$yp/) {
		$year = $1;
		$seek = "month";
	} elsif ($seek eq "month" || $seek eq "any" and /$mp/) {
		$month = $1;
		$seek = "day";
	} elsif ($seek eq "day" || $seek eq "any" and /$dp/) {
		$weekday = $1;
		$day = $2;
		$seek = "any";
		say "\# $weekday, $day $month $year";
	} elsif (/$yp/ or /$mp/ or /$dp/) {
		die "Not expecting header.";
	} elsif ($seek eq "any") {
		print;
	}
	if (/^$/) {
		if ($lastempty eq "yes") {
			die "Two blanks in a row.";
		} else {
			$lastempty = "yes";
		}
	} else {
		$lastempty = "no";
	}
}
