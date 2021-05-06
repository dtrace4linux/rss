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
my %opts = (
	dir => "data",
	);
my @font;
my $swidth;
my $sheight;

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'help',
		'dir=s',
		'test=s',
		);

	usage(0) if $opts{help};
	if (! -d $opts{dir}) {
		print "error: '$opts{dir}' does not exist\n";
		exit(1);
	}
	$| = 1;

	###############################################
	#   Get  screen  dimensions  so we can scale  #
	#   the drawing.			      #
	###############################################
	my $s = `$FindBin::Bin/../bin/fb -info`;
	($swidth, $sheight) = split(/[x,]/, $s);

	if ($opts{test}) {
		test($opts{test});
		exit(0);
	}

	gen("draw0.txt", \&gen0);
	gen("draw1.txt", \&gen1);
	gen("draw2.txt", \&gen2);

	# Bogus - we need to find a better way to get pixel fonts
	my $ffile = "/home/fox/3rd/linux/linux-4.9.9/lib/fonts/font_pearl_8x8.c";
	if (-f $ffile) {
		read_font($ffile);
		gen("draw3.txt", \&gen3);
	}
	gen("draw4.txt", \&gen4);
	gen("draw5.txt", \&gen5);
}

sub gen
{	my $fname = shift;
	my $func = shift;

	$fname = "$opts{dir}/$fname" if $opts{dir};
	print "Creating: $fname\n";

	my $fh = new FileHandle(">$fname");
	die "Cannot create $fname - $!" if !$fh;

	print $fh "delay 0\n";
	print $fh "clear\n";

	$func->($fh);
}

sub gen0
{	my $fh = shift;

	for (my $sz = 100; $sz < 400; $sz += 50) {
		print $fh "clear\n";
		for (my $y = 0; $y < $sheight; $y += $sz + 10) {
			for (my $x = 0; $x < $swidth; $x += $sz + 10) {
				print $fh "draw $x $y $sz $sz\n";
			}
		}
		print $fh "sleep 5\n";
	}
}

sub gen1
{	my $fh = shift;

	for (my $sz = 10; $sz < 400; $sz += 10) {
		print $fh "clear\n";
		my $n = 0;
		for (my $x = 0; $x < $swidth; $x += $sz + 10) {
			my $fx = ($x / $swidth) * 3.14 * 8;
			my $y = $sheight/2 + int($sheight/2 * sin($fx));
			print $fh "draw $x $y $sz $sz\n";
			$n++;
		}
		last if $n++ < 4;
		print $fh "sleep 5\n";
	}
}

sub gen2
{	my $fh = shift;

	for (my $sz = 20; $sz < 400; $sz += 20) {
		my $n = $sz < 200 ? 16 : 8;
		print $fh "clear\n";
		my $th = (3.14159 * 2) / $n;
		for (my $i = 0; $i < $n; $i++) {
			my $x1 = int($sheight/3 * cos($i * $th)) + $swidth/2 - $sz/2;
			my $y1 = int($sheight/3 * sin($i * $th)) + $sheight/2 - $sz/2;
			print $fh "draw $x1 $y1 $sz $sz\n";
		}
		printf $fh "draw %d %d %d %d\n",
			($swidth-250) / 2,
			($sheight-250) / 2,
			250, 250;
		print $fh "sleep 5\n";
	}
}

sub gen3
{	my $fh = shift;

	my $txt = "12:34";
	my $x = 100;
	my $y = 100;

	foreach my $ch (split(//, $txt)) {
		my $f = $font[ord($ch)];
		for (my $y1 = 0; $y1 < @{$f}; $y1++) {
			my $row = $f->[$y1];
			for (my $x1 = 0; $x1 < 8; $x1++) {
				my $b = $row & (1 << (8-$x1));
				if ($b) {
					printf $fh "draw %d %d 20 20\n",
						$x + $x1 * 12,
						$y + $y1 * 30;
				}
			}
#			$y += 30;
		}

		$x += 8 * 15;
	}
}

sub gen4
{	my $fh = shift;

	my $right;

	for (my $x = 0; $x < $swidth-100; $x += 100) {
		print $fh "draw $x 50 50 50\n";
		$right = $x;
	}
	for (my $y = 150; $y < $sheight-120; $y += 120) {
		print $fh "draw 0 $y 50 50\n";
	}

	for (my $y = 125; $y < $sheight-250; $y += 300) {
		for (my $x = 125; $x +250 < $right; $x += 300) {
			print $fh "draw $x $y 250 250\n";
		}
	}

	for (my $x = 0; $x < $swidth-100; $x += 100) {
		printf $fh "draw $x %d 50 50\n", $sheight - 120;
	}
	for (my $y = 150; $y < $sheight-120; $y += 120) {
		print $fh "draw $right $y 50 50\n";
	}

}

sub gen5
{	my $fh = shift;

	for (my $inc = 0; $inc < $swidth - 300; $inc += 300) {
		for (my $sz = 50, my $x = 0; $x + $sz < $sheight; $x += 30, $sz += 20) {
			printf $fh "draw %d $x $sz $sz\n", $x + $inc;
		}
	}
}
sub read_font
{	my $fn = shift;

	my @ch_list;
	my $fh = new FileHandle($fn);
	die "Cannot read $fn - $!" if !$fh;
	while (<$fh>) {
		chomp;
		if (/^   \//) {
#print join("  ", @ch_list), "\n";
			push @font, [@ch_list] if @ch_list;
			@ch_list = ();
			next;
		}
		if (/^   (0x..)/) {
#print "hex $1=", hex($1), "\n" if @font == 49;
			push @ch_list, hex($1);
			next;
		}
	}
}

sub test
{	my $fn = shift;

	printf("\033[2J");
	my $fh = new FileHandle($fn);
	while (<$fh>) {
		chomp;
		if (/sleep (\d+)/) {
			sleep($1);
			next;
		}
		if (/draw (\d+) (\d+) (\d+) (\d+)/) {
			printf("\033[%d;%dHX",
				$2 / 8, $1 / 8);
			next;
		}
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
gendraw -- draw instructions for picture drawing
Usage:

Switches:

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

