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
	headless => "/dev/shm/headless",
	once => 0,
	sleep => 2700,
	timeout => 20,
	w => 1024,
	h => 1600,
	);

sub check_parent
{
	if ($opts{ppid} && ! -d "/proc/$opts{ppid}") {
		print time_string() . "Parent died .. terminating\n";
		exit(0);
	}
}

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

	delete($ENV{DISPLAY});

	my $cmd = shift @ARGV || '';
	if ($cmd eq 'reap') {
		reap_orphans();
		exit(0);
	}

	if ($opts{clean}) {
		do_clean();
		exit(0);
	}

	mkdir($opts{dir}, 0755);
	mkdir($opts{headless}, 0755);

	reap_orphans();

	while (1) {
		get_pages();
		last if $opts{once};

		print time_string() . "[$$] Sleeping for $opts{sleep}s...\n";

		for (my $i = 0; $i < $opts{sleep}; $i++) {
			check_parent();
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
		$valid{ "$opts{dir}/$fn.png" } = 1;
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
		check_parent();

		my $fn = site_to_fn($w);

		my $ofn = "$opts{dir}/$fn.png";

		$ENV{HOME} = "/tmp";
		my $cmd = "timeout $opts{timeout}s firefox " .
			"--window-size $opts{w},$opts{h} " .
			"--screenshot $ofn.tmp $w";
		print time_string() . "$cmd\n";
		system($cmd);
		if (! -f "$ofn.tmp") {
			print time_string() . "Failed to get: $ofn.tmp\n";
			next;
		}

		my $d = strftime("%Y.%m", localtime());
		mkdir("$opts{dir}/$d", 0755);
		my $fn1 = strftime("%Y%m%d-%H-$fn", localtime());
		rename($ofn, "$opts{dir}/$d/$fn1.png");
		rename("$ofn.tmp", $ofn);
	}
}

sub reap_orphans
{
	foreach my $p (glob("/proc/[1-9]*/status")) {
		my $fh = new FileHandle("$p");
		next if !$fh;

		my $name = <$fh>;
		chomp($name);
		$name =~ s/^Name:\s*//;
		next if $name !~ /firefox/;

		while (<$fh>) {
			chomp;
			next if !/^PPid:\s*(\d+)/;
			my $ppid = $1;

			last if $ppid ne 1;

			my $pid = (split("/", $p))[2];
			print time_string() . "Killing orphan firefox: $pid ppid=$ppid\n";
			kill('KILL', $pid);
			last;
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

	my $p = "  " . join("\n    ", @pages);

	print <<EOF;
get-web.pl - use headless browser to capture web sites
Usage:

  The following web sites are screenshotted:

  $p

Switches:

  -timeout nn     Allow browser to take this long (in seconds)

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

