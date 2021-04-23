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
my %api_keys;

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'help',
		'v',
		);

	usage(0) if $opts{help};

	my $fh = new FileHandle("$ENV{HOME}/.secure/themoviedb.org");
	die "File $ENV{HOME}/.secure/themoviedb.org does not exist - $!" if !$fh;

	while (<$fh>) {
		chomp;
		next if /^#/;
		my ($lh, $rh) = split("=");
		next if !$rh;
		$api_keys{$lh} = $rh;
	}

	# https://www.themoviedb.org/documentation/api/discover

#	query("discover/movie?sort_by=popularity.desc");

	for (my $y = 1950; $y < 2021; $y++) {
#		query($y, "discover/movie?primary_release_year=$y&sort_by=vote_average.desc");
		query($y, "search/movie?primary_release_year=$y&region=US&query=a");
	}
}

sub query
{	my $year = shift;
	my $url = shift;

	my $cmd = "curl --silent  " .
		"'https://api.themoviedb.org/3/$url&api_key=$api_keys{key_v3}&language=en-US'";
#	print $cmd, "\n";
	my $txt = `$cmd`;

	my $ofh = new FileHandle(">/tmp/tmdb.json");
	print $ofh $txt if $ofh;

	print "$txt\n" if $opts{v};

	my $json = JSON->new->allow_nonref;
	my $info = $json->decode($txt);

	my $num = scalar(@{$info->{results}});
	print "results: $year $num\n";

	my $dir = "$ENV{HOME}/images/movie-posters";
	mkdir($dir, 0755);
	mkdir("$dir/$year", 0755);


	for (my $i = 0; $i < $num; $i++) {
#	my $p = rand($num);
		my $path = $info->{results}->[$i]->{poster_path};
		my $title = $info->{results}->[$i]->{original_title};
		$title =~ s/ /_/g;
		$title =~ s/'//g;
		next if !defined($path);
		my $img_url = "http://image.tmdb.org/t/p/w500$path";
		next if -f "$dir/$year/$title.jpg";

		print "Fetch: $title\n";

		spawn("curl --silent -o '$dir/$year/$title.jpg' '$img_url'");
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
themoviedb - download a selection of movie photos for display
Usage: pexels <number>

Description:

  This tool uses the themoviedb.org website to download a random
  selection of movie-posters. These are then randomly cycled on
  the display screen.

  To use this script will require your own API key.

Switches:

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

