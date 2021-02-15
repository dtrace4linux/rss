#! /usr/bin/perl

# $Header:$

use strict;
use warnings;

use File::Basename;
use FileHandle;
use Getopt::Long;
use IO::File;
use POSIX;

#######################################################################
#   Command line switches.					      #
#######################################################################
my %opts = (
	o => "/tmp/$ENV{USER}/stock.log",
	);

my $ofh;

my @lst = (
	".DJI:INDEXDJX",
	"AMZN:NASDAQ", 
	"GME:NYSE", 
	"MS:NYSE", 
	"NI225:INDEXNIKKEI",
	"OCDO:LON",
	"UKX:INDEXFTSE", 
	);

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'help',
		'o=s',
		);

	mkdir("/tmp/$ENV{USER}", 0700);

	@lst = sort(@lst);

	usage(0) if $opts{help};

	$ofh = new FileHandle(">>$opts{o}");

	print "\033[37;40m";

	foreach my $s (@lst) {
		get($s);
	}
}

sub get
{	my $stock = shift;

	my $fn = "/tmp/$ENV{USER}/$stock.log";
	my $mtime = (stat($fn))[9];

	my $do_store = 0;
	if (!defined($mtime) || $mtime + 15 * 60 < time()) {
		my $cmd = "wget -q -O $fn http://www.google.com/finance/quote/$stock";
		system($cmd);
		$do_store = 1;
	}

	my $fh = new FileHandle($fn);
	while (<$fh>) {
		chomp;
		if (/<h1 class/) {
			$_ =~ s/^.*<h1 class=//;

			my $ln = $_;
			my $q = $ln;
			$q = (split("<div class", $q))[3];
			$q = (split(/[<>]/, $q))[1];
			$q =~ s/\xc2\xa0/ /;

			my $pc = $ln;
			$pc =~ s/%.*$/%/;
			$pc =~ s/^.*>//;

			my $c1 = $pc =~ /-/ ? "\033[41m\033[33m" : "\033[30;42m";
			my $c2 = "\033[37;40m";
			printf "%-18s %14s $c1%10s$c2\n", $stock, $q, $pc;

			print $ofh strftime("%Y%m%d %H:%M:%S", localtime()), ",",
				time(), ",",
				"$stock,$q,$pc\n" if $do_store;
		}
	}
}
#######################################################################
#   Print out command line usage.				      #
#######################################################################
sub usage
{	my $ret = shift;
	my $msg = shift;

	print $msg if $msg;

	my $s = join("\n  ", @lst);

	print <<EOF;
stock.pl -- retrieve stock quotes
Usage: stock.pl symbol1 symbol2 ...

  This tool retrieves stock quotes periodically, to allow
  use by other tools for stock displays.

  If no stocks are specified, then the follow are used:

  $s

Switches:

  -o <filename>    Write (append) stock status to file in this format:

                   YYYYMMDD HH:MM:SS,unix_time,symbol,price,delta

		   Default: $opts{o}
EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

