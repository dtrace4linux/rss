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
#	"http://wttr.in",
	"http://www.theguardian.com",
	"http://news.sky.com",
	"http://express.co.uk",
	"http://www.ft.com",
	"http://www.thetimes.co.uk",
	"http://huffingtonpost.co.uk",
	"http://www.cnn.com",
	"http://time.com",
	"http://abcnews.go.com",
	"http://www.theverge.com",
	"http://cbsnews.com",
	"http://variety.com",
	"http://digg.com",
	"http://arstechnica.com",
	"http://slate.com",
	"http://slashdot.org",
	"http://reddit.com",
	"https://en.wikipedia.org/wiki/Special:Random",
	"https://www.notebookcheck.net/",
	);

#######################################################################
#   Command line switches.					      #
#######################################################################
my %opts = (
	dir => "$ENV{HOME}/images/news",
	once => 0,
	sleep => 2700,
	timeout => 20,
	w => 1024,
	h => 2000,
	);

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'clean',
		'dir=s',
		'help',
		'once',
		'ppid=s',
		'w=s',
		'h=s',
		);

	usage(0) if $opts{help};

	if ($opts{clean}) {
		do_clean();
		exit(0);
	}

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

		do_clean();
	}
}

sub do_clean
{
	my %valid;
	foreach my $p (@pages) {
		my $fn = site_to_fn($p);
		$valid{ "$opts{dir}/$fn.jpg" } = 1;
	}

	foreach my $f (glob("$opts{dir}/*")) {
		next if -d $f;
		next if $f =~ /\.log$/;
		next if $valid{$f};

		print time_string() . "clean: $f\n";
		unlink($f);
	}
}

sub get_pages
{
	foreach my $w (@pages) {
		my $fn = site_to_fn($w);

		my $ofn = "$opts{dir}/$fn.jpg";

		$ENV{HOME} = "/tmp";
		my $cmd = "timeout $opts{timeout}s firefox --profile /tmp/headless " .
			"--window-size $opts{w},$opts{h} " .
			"-screenshot $ofn.tmp $w >/dev/null 2>&1";
		print time_string() . "$cmd\n";
		system($cmd);
		if (-f "$ofn.tmp") {
			my $d = strftime("%Y.%m", localtime());
			mkdir("$opts{dir}/$d", 0755);
			my $fn1 = strftime("$fn-%d.%H", localtime());
			rename($ofn, "$opts{dir}/$d/$fn1.jpg");
			rename("$ofn.tmp", $ofn);
		}


	}
}

sub site_to_fn
{	my $w = shift;

	my $fn = $w;
	$fn =~ s/^.*\/\///;
	$fn =~ s/\/.*//;
	$fn =~ s/^www\.//;

	return $fn;
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

