#!/usr/bin/env perl

# This scripts translates a word using WordReference or Wikipedia. Translating
# via Wikipedia is useful for technical words that don't appear in the
# dictionary but that have Wikipedia articles in the desired language.

use strict;
use warnings;

use utf8;
use charnames ':full';
binmode(STDOUT, ":utf8");

use Browser::Open qw(open_browser);
use File::Basename qw(basename);
use Getopt::Long qw(GetOptions);
use HTML::Entities qw(decode_entities);
use LWP::Simple qw(get);

sub show {
	my ($s, $g) = @_;
	$s =~ s/^\s+|\s+$//g;
	print decode_entities($s);
	if ($g) {
		print ' (' . $g . ')';
	}
	print "\n";
}

my $P = basename($0);

my $usage_ft = '[--from LANG] [--to LANG]';
my $usage_src = '[--src wr | --src wiki]';
my $usage = "usage: $P $usage_ft $usage_src [--browser] WORD\n";

GetOptions(
	'from|f=s' => \(my $from_lang = 'en'),
	'to|t=s' => \(my $to_lang = 'fr'),
	'src|s=s' => \(my $source = 'wr'),
	'browser|b' => \(my $browser)
) or die $usage;

if (scalar(@ARGV) <= 0) {
	die "$P: expecting word to translate\n";
}

if ($source eq 'wr') {
	my $name = join('%20', @ARGV);
	my $url = "http://wordreference.com/$from_lang$to_lang/$name";
	if ($browser) {
		open_browser($url);
		exit 0;
	}

	my $html = get($url);
	my $no_entry = 'No translation found for';
	if (not defined $html or index($html, $no_entry) != -1) {
		die "$P: $name: no such entry\n";
	}

	my $no_exact = "WordReference can't translate this exact phrase";
	if (index($html, $no_exact) != -1) {
		die "$P: $name: no exact entry\n";
	}

	if ($html =~ /< *td +class *= *["']ToWrd['"].*?>(.+?)<(?:.*?tooltip +POS2['"].*?>(.+?)<)?/) {
		show $1, $2;
	}
} elsif ($source eq 'wiki') {
	my $name = join('_', @ARGV);
	my $url = "http://$from_lang.wikipedia.org/wiki/$name";
	if ($browser) {
		open_browser($url);
		exit 0;
	}

	my $html = get($url);
	if (not defined $html) {
		die "$P: $name: no such article\n";
	}

	my $disambig = '/wiki/Help:Disambiguation';
	if (index($html, $disambig) != -1) {
		die "$P: $name: ambiguous\n";
	}

	if ($html =~ /<a href="\/\/$to_lang\.wikipedia\.org\/wiki\/.*?" title="(.+?) –.+?"/) {
		show $1;
	} else {
		die "$P: $name: no article for language '$to_lang'\n";
	}
} else {
	die "$P: $source: invalid source (try 'wr' or 'wiki')\n";
}
