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
use MIME::Base64;

#######################################################################
#   Command line switches.					      #
#######################################################################
my %opts;
my $api;

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'help',
		);

	usage(0) if $opts{help};

	my $fh = new FileHandle("$ENV{HOME}/.secure/pexels");
	die "File $ENV{HOME}/.secure/pexels does not exist - $!" if !$fh;
	$api = <$fh>;
	chomp($api);
	$api =~ s/^.*=//;

#	query("search?query=nature&per_page=1");
	query("curated?per_page=15"); # max 80, default 15
}

sub query
{	my $url = shift;

	my $cmd = "curl --silent -H \'Authorization: $api\' " .
		"'https://api.pexels.com/v1/$url'";
#	print $cmd, "\n";
	my $txt = `$cmd`;
	print "$txt\n" if $opts{v};
	my $json = JSON->new->allow_nonref;
	my $info = $json->decode($txt);

	my $dir = "$ENV{HOME}/pexels";

	foreach my $p (@{$info->{photos}}) {
		my $fn = "$p->{src}->{tiny}";
		$fn =~ s/\?.*//;
		$fn = basename($fn);

		print "$p->{src}->{tiny}\n";

		spawn("curl --silent -o $dir/$fn '$p->{src}->{tiny}'");
	}
}

sub spawn
{	my $cmd = shift;

	system($cmd);
}

#######################################################################
#   Print out command line usage.				      #
#######################################################################
sub usage
{	my $ret = shift;
	my $msg = shift;

	print $msg if $msg;

	print <<EOF;
pexels - download a selection of photos for displaying in the RSS screen
Usage: pexels <number>

Description:

  Tool to download a number of pictures, so we can cycle them in the
  RSS feed. You will need to register at http://pexels.com for your
  own API key, and place it in \$HOME/.secure/pexels, for this to
  be useful to you.

Switches:

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

