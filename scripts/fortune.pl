#! /usr/bin/perl

# $Header:$

use strict;
use warnings;

use File::Basename;
use FileHandle;
use Getopt::Long;
use IO::File;
use POSIX;
use FindBin;

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

	my @lst;
	my $fh = new FileHandle("$FindBin::Bin/../data/fortunes");
	my $hdr = <$fh>;
	my $txt = '';
	while (<$fh>) {
		if (/^%/) {
			push @lst, $txt if $txt;
			$txt = '';
			next;
		}
		$txt .= $_;
	}
	print $lst[rand(@lst)];
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

