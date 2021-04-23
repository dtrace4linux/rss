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
my %opts = (
	dir => "$ENV{HOME}/images/xkcd",
	n => 999,
	);

my %images;

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'dir=s',
		'help',
		'n=s',
		'v',
		);

	usage(0) if $opts{help};

	mkdir($opts{dir}, 0755);

	read_index();

	my $num = get_image_count();
	print "num=$num\n";

	my $q = 0;
	for (my $i = 1; $i < $num; $i++) {
		next if defined($images{$i});
		query($i, "http://xkcd.com/$i/info.0.json");
		last if $q++ > $opts{n};
	}
}

sub get_json
{	my $fn = shift;

	my $fh = new FileHandle($fn);
	my $txt = '';
	while (<$fh>) {
		$txt .= $_;
	}

	if ($txt eq '') {
		print "$fn - empty text\n";
		exit(1);
	}

	print "$txt\n" if $opts{v};

	my $json = JSON->new->allow_nonref;
	return $json->decode($txt);
}

sub get_image_count
{
	my $url = "http://xkcd.com/info.0.json";
	my $fn = "/tmp/xkcd.json";
	my $mtime = (stat($fn))[9];
	if (! -f $fn || $mtime + 7200 < time()) {
		my $cmd = "wget -O $fn --quiet $url";
		spawn($cmd);
	}

	my $info = get_json($fn);
	return $info->{num};
}

sub query
{	my $num = shift;
	my $url = shift;

	my $fn = "/tmp/xkcd.$num.json";
	my $cmd = "wget -O $fn --quiet $url";
	print "$cmd\n";
	system($cmd);

	my $info = get_json($fn);

	my $img = $info->{img};
	print "img: $img\n";

	my $dir = "$ENV{HOME}/images/xkcd";
	mkdir($dir, 0755);
	my $title = basename($img);
	if (! -f "$dir/$title") {
		spawn("curl --silent -o '$dir/$title' '$img'");
	}

	$images{$num} = $title;
	save_index();
}

sub read_index
{
	my $fn = "$opts{dir}/xkcd.log";
	my $fh = new FileHandle($fn);
	return if !$fh;
	while (<$fh>) {
		chomp;
		my $idx = $_;
		my $fn = $_;
		$idx =~ s/,.*$//;
		$fn =~ s/^\d+,//;
		$images{$idx} = $fn;
	}
}

sub save_index
{
	my $fn = "$opts{dir}/xkcd.log";
	my $ofh = new FileHandle(">$fn");
	foreach my $n (sort { $a <=> $b } (keys(%images))) {
		print $ofh "$n,$images{$n}\n";
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
xkcd - grab some random xkcd images
Usage: xkcd.pl

Description:

  This tool uses xkcd.com to grab some random images for display
  on the main screen.

Switches:

   -dir <dir>     Place to store images. Default \$HOME/images/xkcd
   -n nn          How many images to fetch
EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

