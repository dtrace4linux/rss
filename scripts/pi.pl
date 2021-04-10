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
my %opts;

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'help',
		);

	usage(0) if $opts{help};

	$| = 1;

	my $n = shift @ARGV || 1500;

	pi($n);

}

sub pi
{	my $num = shift;

	my $a = 10000;
	my $b = 0;
	my $c = 0;
	my $d = 0;
	my $e = 0;
	my $g = 0;
	my $t = time();

	$c = ($num * 7) / 2;
	$c -= $c % 14;

	my @f;
	for (my $i = 0; $i < 4 * $c + 4; $i++) {
		$f[$i] = 0;
	}

	while ($b != $c) {
		$f[$b++] = $a / 5;
	}

	print "Pi to $num digits....\n";

	while (($g = $c * 2) != 0) {
		$d = 0;

		for ($b = $c; ; $d *= $b) {
			$d += $f[$b] * $a;
			$f[$b] = $d % --$g;
			$d /= $g--;
			last if (--$b == 0);
			}
		$c -= 14;
		printf("%04d", $e + $d / $a);
		$e = $d % $a;
		}
	print "\n";
	printf "Time: %d seconds\n", time() - $t;
}
#######################################################################
#   Print out command line usage.				      #
#######################################################################
sub usage
{	my $ret = shift;
	my $msg = shift;

	print $msg if $msg;

	print <<EOF;
pi.pl -- compute pi to arbitrary number of places
Usage: pi.pl <numbufer-of-digits>

Switches:

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

