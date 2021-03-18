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

my $EV_ABS = 0x03;

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

my %abs_codes = (
	0x00 => "ABS_X",
	0x01 => "ABS_Y",
	0x02 => "ABS_Z",
	0x03 => "ABS_RX",
	0x04 => "ABS_RY",
	0x05 => "ABS_RZ",
	0x06 => "ABS_THROTTLE",
	0x07 => "ABS_RUDDER",
	0x08 => "ABS_WHEEL",
	0x09 => "ABS_GAS",
	0x0a => "ABS_BRAKE",
	0x10 => "ABS_HAT0X",
	0x11 => "ABS_HAT0Y",
	0x12 => "ABS_HAT1X",
	0x13 => "ABS_HAT1Y",
	0x14 => "ABS_HAT2X",
	0x15 => "ABS_HAT2Y",
	0x16 => "ABS_HAT3X",
	0x17 => "ABS_HAT3Y",
	0x18 => "ABS_PRESSURE",
	0x19 => "ABS_DISTANCE",
	0x1a => "ABS_TILT_X",
	0x1b => "ABS_TILT_Y",
	0x1c => "ABS_TOOL_WIDTH",
	0x2f =>          "ABS_MT_SLOT",
	0x30 =>          "ABS_MT_TOUCH_MAJOR",
	0x31 =>          "ABS_MT_TOUCH_MINOR",
	0x32 =>          "ABS_MT_WIDTH_MAJOR",
	0x33 =>          "ABS_MT_WIDTH_MINOR",
	0x34 =>          "ABS_MT_ORIENTATION",
	0x35 =>          "ABS_MT_POSITION_X",
	0x36 =>          "ABS_MT_POSITION_Y",
	0x37 =>          "ABS_MT_TOOL_TYPE",
	0x38 =>          "ABS_MT_BLOB_ID",
	0x39 =>          "ABS_MT_TRACKING_ID",
	0x3a =>          "ABS_MT_PRESSURE",
	0x3b =>          "ABS_MT_DISTANCE",
	0x3c =>          "ABS_MT_TOOL_X",
	0x3d =>          "ABS_MT_TOOL_Y",
	);

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'all',
		'help',
		);

	usage(0) if $opts{help};

	my $dev = shift @ARGV || "/dev/input/event0";

	my $arch = `uname -m`;
	chomp($arch);
	my $is_64bit = $arch =~ /64/;

	my $fh = new FileHandle($dev);
	die "Cannot open $dev - $!" if !$fh;

	my $bits = '';
	vec($bits, $fh->fileno(), 1) = 1;

	while (1) {
		my $s;
		my $rbits;
		my $n = select($rbits = $bits, undef, undef, 1.0);
		next if !$n;

		last if !sysread($fh, $s, $is_64bit ? 24 : 16);
		my ($secs, $usecs, $type, $code, $value);

		if ($is_64bit) {
			($secs, $usecs, $type, $code, $value) = unpack("qqSSS", $s);
		} else {
			($secs, $usecs, $type, $code, $value) = unpack("LLSSS", $s);
		}

		if ($opts{all}) {
			print "$secs.$usecs event $type $types{$type} $code $value\n";
			next;
		}

		if ($type == $EV_ABS) {
			print "$secs.$usecs event $type $types{$type} $code $abs_codes{$code} $value\n";
		}
	}

	print "EOF detected\n";
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

  This is a test script to monitor touchpad controls.

Switches:

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

