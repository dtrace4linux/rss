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

	my $fn = shift @ARGV;
	usage() if !$fn;

	my $fh = new FileHandle($fn);
	if (!$fh) {
		print "Cannot open $fn - $!\n";
		exit(0);
	}

	my @lst;

	my $d = strftime("%a", localtime());
	while (<$fh>) {
		next if /^#/;
		chomp;
		my ($cdate, $dow, $interval, $algo, $msg) = split(/,/);
		next if $dow !~ /$d/i;

		push @lst, $msg;
	}

	my $msg = $lst[rand(@lst)];
	exit(0) if !$msg;

	if (int(rand(3)) == 0) {
		system("figlet $msg");
	} else {
		system("toilet --gay $msg");
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
reminder.pl - simple reminder tool
Usage: reminder.pl <filename>

  Randomly print a reminder for today.

Switches:

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

