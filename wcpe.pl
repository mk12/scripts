#!/usr/bin/env perl

# This script says what's currently playing on the classical radio station WCPE.

use strict;
use warnings;

use utf8;
use charnames ':full';
binmode(STDOUT, ":utf8");

use File::Basename qw(basename);
use Getopt::Long qw(GetOptions);
use HTML::Entities qw(decode_entities);
use LWP::Simple qw(get);
use DateTime;
use HTML::TableExtract;
use Text::Wrap;

my $name = basename($0);
my $usage = "usage: $name [-t HH:MM]\n";
my $time_re = qr/(\d\d?):(\d\d)/;

GetOptions('-t=s' => \(my $custom_time)) or die $usage;

my $dt = DateTime->now(time_zone => 'America/New_York');
if ($custom_time && $custom_time =~ $time_re) {
	$dt->set(hour => $1, minute => $2);
}

my @weekdays = qw(mon tue wed thu fri sat sun);
my $abbrev = $weekdays[$dt->day_of_week-1];
my $url = "http://theclassicalstation.org/playing_$abbrev.shtml";
my $html = get($url);
if (not defined $html) {
	die "error: GET $url failed\n";
}
$html =~ s/<P>//g;

my $headers = ['Start Time', 'Composer', 'Title', 'Performers'];
my $te = HTML::TableExtract->new(headers => $headers);
$te->parse($html);

my $i = 0;
foreach my $row ($te->rows) {
	my $time = @$row[0];
	if ($time =~ $time_re) {
		if ($1 > $dt->hour || ($1 == $dt->hour && $2 > $dt->minute)) {
			last;
		}
	}
	$i++;
}

$i = ($i == 0 ? 0 : $i - 1);
my $row = @{$te->rows}[$i];
my $next = @{$te->rows}[$i+1];

my ($h1, $m1) = (@$row[0] =~ $time_re);
my ($h2, $m2) = (@$next[0] =~ $time_re);
my $ap1 = 'AM';
my $ap2 = 'AM';
if ($h1 >= 12) { $ap1 = 'PM'; }
if ($h2 >= 12) { $ap2 = 'PM'; }
$h1 += ($h1 > 12 ? -12 : 0);
$h2 += ($h2 > 12 ? -12 : 0);

my $interval;
if ($ap1 eq $ap2) {
	$interval = "$h1:$m1 - $h2:$m2 $ap2";
} else {
	$interval = "$h1:$m1 $ap1 - $h2:$m2 $ap2";
}

if (length @$row[1]) {
	print "Time        $interval\n";
	print "Composer    @$row[1]\n";
	print "Title       @$row[2]\n";
	print "Performers  @$row[3]\n";
} else {
	print "$interval\n\n";
	$Text::Wrap::columns = 72;
	print wrap('', '', @$row[2] . "\n");
}
