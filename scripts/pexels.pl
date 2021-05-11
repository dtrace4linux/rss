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
		'v',
		);

	usage(0) if $opts{help};

	my $fh = new FileHandle("$ENV{HOME}/.secure/pexels");
	die "File $ENV{HOME}/.secure/pexels does not exist - $!" if !$fh;
	$api = <$fh>;
	chomp($api);
	$api =~ s/^.*=//;

#	query("search?query=nature&per_page=1");
	query("curated?per_page=15"); # max 80, default 15
	query("search?query=nature&per_page=15"); # max 80, default 15
	query("search?query=art&per_page=15"); # max 80, default 15
	query("search?query=abstract&per_page=15"); # max 80, default 15
	query("search?query=sky&per_page=15"); # max 80, default 15

	query("search?query=beautiful%20scenery&per_page=80", "scenery"); # max 80, default 15
}

sub query
{	my $url = shift;
	my $subdir = shift || "images";

	my $cmd = "curl --silent -H \'Authorization: $api\' " .
		"'https://api.pexels.com/v1/$url'";
#	print $cmd, "\n";
	my $txt = `$cmd`;
	if ($opts{v}) {
		print "$txt\n";
	}
	my $json = JSON->new->allow_nonref;
	if ($txt eq '') {
		print $cmd, "\n";
		print "empty response to query\n";
		exit(1);
	}
	my $info = $json->decode($txt);

	my $dir = "$ENV{HOME}/images/$subdir";
	mkdir($dir, 0755);

	foreach my $p (@{$info->{photos}}) {
		# tiny
		# small
		foreach my $sz (qw/medium/) {
			my $fn = "$p->{src}->{$sz}";
			$fn =~ s/\?.*//;
			$fn = basename($fn);

			$fn =~ s/\.jpeg/-$sz.jpeg/;

			next if -f "$dir/$fn";

			print "$sz: $p->{src}->{$sz}\n";
			spawn("curl --silent -o $dir/$fn '$p->{src}->{$sz}'");
		}
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

