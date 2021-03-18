#! /usr/bin/perl

# $Header:$

use strict;
use warnings;

use File::Basename;
use FileHandle;
use Getopt::Long;
use IO::File;
use POSIX;

my @pages = (
	"https://www.dailymail.co.uk/home/index.html",
	"https://www.bbc.co.uk/news",
	"http://wttr.in",
	"http://www.theguardian.com",
	"http://news.sky.com",
	"http://express.co.uk",
	"http://www.ft.com",
	"http://www.thetimes.co.uk",
	"http://huffingtonpost.co.uk",
	"http://www.cnn.com",
	"http://time.com",
	"http://abcnews.go.com",
	"http://www.thevergecom",
	"http://cbsnews.com",
	"http://variety.com",
	"http://digg.com",
	"http://arstechnica.com",
	"http://slate.com",
	);

#######################################################################
#   Command line switches.					      #
#######################################################################
my %opts = (
	dir => "$ENV{HOME}/images/news",
	once => 0,
	sleep => 1800,
	timeout => 20,
	w => 1024,
	h => 2000,
	);

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'dir=s',
		'help',
		'once',
		'ppid=s',
		'w=s',
		'h=s',
		);

	usage(0) if $opts{help};

	mkdir($opts{dir}, 0755);
	mkdir("/tmp/headless", 0755);

	while (1) {
		get_pages();
		last if $opts{once};

		print time_string() . "Sleeping for $opts{sleep}s...\n";

		for (my $i = 0; $i < $opts{sleep}; $i++) {
			exit(0) if $opts{ppid} && ! -d "/proc/$opts{ppid}";
			sleep(1);
		}
	}
}

sub get_pages
{
	foreach my $w (@pages) {
		my $fn = $w;
		$fn =~ s/^.*\/\///;
		$fn =~ s/\/.*//;
		$fn =~ s/^www\.//;

		my $ofn = "$opts{dir}/$fn";
		rename($ofn, "$ofn.old");

		$ENV{HOME} = "/tmp";
		my $cmd = "timeout $opts{timeout}s firefox --profile /tmp/headless " .
			"--window-size $opts{w},$opts{h} " .
			"-screenshot $ofn $w";
		print time_string() . "$cmd\n";
		system("$cmd ; ls -h $ofn");

	}
}

sub time_string
{
	return strftime("%Y%m%d %H:%M:%S ", localtime());
}

#######################################################################
#   Print out command line usage.				      #
#######################################################################
sub usage
{	my $ret = shift;
	my $msg = shift;

	print $msg if $msg;

	print <<EOF;
get-web.pl - use headless browser to capture certain web sites
Usage:

Switches:

  -timeout nn     Allow browser to take this long (in seconds)

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

