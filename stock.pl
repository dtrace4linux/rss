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
	sleep => 600,
	);

my $ofh;

my @lst = (
	".DJI:INDEXDJX",
	"AAPL:NASDAQ",
	"AMZN:NASDAQ", 
	"GME:NYSE", 
	"MS:NYSE", 
	"NI225:INDEXNIKKEI",
	"OCDO:LON",
	"TSLA:NASDAQ",
	"UKX:INDEXFTSE", 
	);

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'help',
		'loop',
		'o=s',
		'parent',
		'random',
		'sleep=s',
		'update',
		);

	mkdir("/tmp/$ENV{USER}", 0700);

	@lst = @ARGV if @ARGV;
	@lst = sort(@lst);

	usage(0) if $opts{help};

	$| = 1;
	
	if ($opts{update}) {
		do_update();
	}

	if ($opts{random}) {
		do_random();
		exit(0);
	}

	$ofh = new FileHandle(">>$opts{o}");

	print "\033[37;40m";

	my $ppid = getppid();

	while (1) {
		foreach my $s (@lst) {
			get($s);
		}

		last if !$opts{loop};

		last if $opts{parent} && ! -d "/proc/$ppid";

		sleep($opts{sleep});

		print "\n";
	}
}

sub do_random
{
	my $fh = new FileHandle($opts{o});
	return if !$fh;

	my %info;
	while (<$fh>) {
		chomp;
		my ($date, $time, $stock, $price, $delta) = split(/,/);
		$info{$stock}{date} = $date;
		$info{$stock}{time} = $time;
		$info{$stock}{price} = $price;
		$info{$stock}{delta} = $delta;
	}

	my $s = '';
	my @k = keys(%info);
	for (my $i = 0; $i < @k; $i++) {
		my $j = rand(@k);
		($k[$i], $k[$j]) = ($k[$j], $k[$i]);
	}

	my $len = 0;
	for (my $i = 0; $i < @k; $i++) {
		my $k = $k[$i];
		my $k1 = $k[$i];
		$k1 =~ s/:.*//;
		my $s1 = "$k1:$info{$k}{price} $info{$k}{delta}  ";
		last if $len + length($s1) > 70;

		$len += length($s1);
		my $green = "\033[32m";
		my $red = "\033[31m";
		my $white = "\033[37m";
		my $c1 = $info{$k}{delta} =~ /-/ ? $red : $green;
		$s1 = "$k1:$c1$info{$k}{price}$white $info{$k}{delta}  ";
		$s .= $s1;
	}
	print "\033[40;37m$s\033[37;40m\n";
}

sub do_update
{
	foreach my $s (@lst) {
		get($s, 1);
	}
}

sub get
{	my $stock = shift;
	my $update = shift;

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
			$q =~ s/,//;

			my $pc = $ln;
			$pc =~ s/%.*$/%/;
			$pc =~ s/^.*>//;

			my $c1 = $pc =~ /-/ ? "\033[41m\033[33m" : "\033[30;42m";
			my $c2 = "\033[37;40m";
			my $c3 = $pc =~ /-/ ? "\033[31m" : "\033[32m";

			if (!$update) {
				printf strftime("%H:%M:%S", localtime()) .
					" %-18s $c3%14s $c1%10s$c2\n", 
					$stock, $q, $pc;
			}

			print $ofh strftime("%Y%m%d %H:%M:%S", localtime()), ",",
				time(), ",",
				"$stock,$q,$pc\n" if $do_store && $ofh;
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

  -loop            Run continuously, updating every 10m.

  -o <filename>    Write (append) stock status to file in this format:

                   YYYYMMDD HH:MM:SS,unix_time,symbol,price,delta

		   Default: $opts{o}
  -parent          Terminate (in loop mode) if parent process terminates.
  -random          Print a one line collection of stock updates.
EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

