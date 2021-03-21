#! /usr/bin/perl

# $Header:$

use strict;
use warnings;

use File::Basename;
use FileHandle;
use Getopt::Long;
use IO::File;
use POSIX;
use JSON;

#######################################################################
#   Command line switches.					      #
#######################################################################
my %opts = (
	key => "85a4e3c55b73909f42c6a23ec35b7147",
	location => "Camberley,GB",
	units => "metric",
	);

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'help',
		'forecast=s',
		'location|l=s',
		'key=s',
		'units=s',
		'v',
		);

	usage(0) if $opts{help};
	get();
}
sub get
{
	my $api_cmd = $opts{forecast} ? 'weather' : 'forecast/daily';

	my $cmd = "http://api.openweathermap.org/data/2.5/" .
		"$api_cmd?q=$opts{location}&units=$opts{units}&appid=$opts{key}";

	print $cmd, "\n" if $opts{v};

	my $fn = "/tmp/w.log";
	system("curl -s  -o $fn '$cmd'");

	my $fh = new FileHandle($fn);
	local $/ = undef;
	my $txt = <$fh>;

	my $json = JSON->new->allow_nonref;
	my $info = $json->decode($txt);

	print "Temperature: ", $info->{main}{temp}, "\n";
	print "Temp min   : ", $info->{main}{temp_min}, "\n";
	print "Temp max   : ", $info->{main}{temp_max}, "\n";
	print "Pressure   : ", $info->{main}{pressure}, "\n";
	print "Humidity   : ", $info->{main}{humidity}, "%\n";
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

