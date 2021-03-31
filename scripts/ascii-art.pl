#! /usr/bin/perl

# $Header:$

use strict;
use warnings;

use File::Basename;
use FileHandle;
use Getopt::Long;
use IO::File;
use FindBin;
use POSIX;
use Socket;

#######################################################################
#   Command line switches.					      #
#######################################################################
my %opts;

my $rows;
my $columns;

sub do_graphic1
{
	for (my $i = 0; $i < 1000; $i++) {
		for (my $j = 0; $j < 5; $j++) {
			my $r = rand($rows);
			my $c = rand($columns);
			my $color = 40 + int(rand(8));
			printf "\033[%d;%dH\033[${color}m ", $r, $c;
		}
		select(undef, undef, undef, 0.005);
	}
}

sub do_graphic2
{	my $r = rand($rows);
	my $c = rand($columns);
	my $dr = 1;
	my $dc = 1;
	my $color = 40 + int(rand(8));

	for (my $i = 0; $i < 2000; $i++) {
		printf "\033[%d;%dH\033[${color}m ", $r, $c;
#		$r += $dr;
		$c += $dc;

		if ($r >= $rows) {
			$r = rand(int($rows));
			$color = 40 + int(rand(8));
		}
		if ($c >= $columns) {
			$r = rand(int($rows));
			$c = rand(int($columns));
			$color = 40 + int(rand(8));
		}

		select(undef, undef, undef, 0.005);
	}
}
sub get_tty_size
{
	my $s = `stty -a | grep columns`;
	chomp($s);
	$s =~ m/rows (\d+); columns (\d+)/;
	($rows, $columns) = ($1, $2);
}

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'help',
		);

	usage(0) if $opts{help};
	my $n = shift @ARGV;

	$| = 1;

	get_tty_size();

	my $game = defined($n) ? $n : int(rand(2));

	if ($game == 0) {
		system("$FindBin::RealBin/maze2.pl | $FindBin::RealBin/snake.pl");
		exit(0);
	}

	if ($game == 1) {
		do_graphic1();
		exit(0);
	}

	if ($game == 2) {
		do_graphic2();
		exit(0);
	}
}
#######################################################################
#   Print out command line usage.				      #
#######################################################################
sub usage
{	my $ret = shift;
	my $msg = shift;

	print $msg if $msg;

	print <<EOF;
Some help...
Usage:

Switches:

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

