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

my %types = (
	0x00 => "EV_SYN",
	0x01 => "EV_KEY",
	0x02 => "EV_REL",
	0x03 => "EV_ABS",
	0x04 => "EV_MSC",
	0x05 => "EV_SW",
	0x11 => "EV_LED",
	0x12 => "EV_SND",
	0x14 => "EV_REP",
	0x15 => "EV_FF",
	0x16 => "EV_PWR",
	0x17 => "EV_FF_STATUS",
	);

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'help',
		);

	usage(0) if $opts{help};

	my $fh = new FileHandle("/dev/input/event0");
	die "Cannot open /dev/input/event0 - $!" if !$fh;
	while (1) {
		my $s;
		last if !sysread($fh, $s, 16);
		my ($secs, $usecs, $type, $code, $value) = unpack("LLSSS", $s);
		print "$secs.$usecs event $type $types{$type} $code $value\n";
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
event.pl - perl interface to the kernel /dev/input for touchscreens
Usage:

Switches:

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

