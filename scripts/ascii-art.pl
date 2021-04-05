#! /usr/bin/perl

# $Header:$

use strict;
use warnings;

use File::Basename;
use FileHandle;
use Getopt::Long;
use IO::File;
use FindBin;
use POSIX;
use Socket;

#######################################################################
#   Command line switches.					      #
#######################################################################
my %opts;

my $rows;
my $columns;

sub do_graphic1
{
	for (my $i = 0; $i < 1000; $i++) {
		for (my $j = 0; $j < 5; $j++) {
			my $r = rand($rows);
			my $c = rand($columns);
			my $color = 40 + int(rand(8));
			printf "\033[%d;%dH\033[${color}m ", $r, $c;
		}
		select(undef, undef, undef, 0.005);
	}
}

sub do_graphic2
{	my $r = rand($rows);
	my $c = rand($columns);
	my $dr = 1;
	my $dc = 1;
	my $color = 40 + int(rand(8));

	for (my $i = 0; $i < 2000; $i++) {
		printf "\033[%d;%dH\033[${color}m ", $r, $c;
#		$r += $dr;
		$c += $dc;

		if ($r >= $rows) {
			$r = rand(int($rows));
			$color = 40 + int(rand(8));
		}
		if ($c >= $columns) {
			$r = rand(int($rows));
			$c = rand(int($columns));
			$color = 40 + int(rand(8));
		}

		select(undef, undef, undef, 0.005);
	}
}

sub do_graphic3
{
	for (my $i = 0; $i < 200; $i++) {
		my $r = rand($rows);
		my $c = rand($columns);
		draw_rect(40 + int(rand(8)), $r, $c,
			rand($columns - $c),
			rand($rows - $r));
		select(undef, undef, undef, 0.15);
	}
}

sub do_graphic4
{
	for (my $i = 0; $i < 100; $i++) {
		my $r = rand($rows);
		my $c = rand($columns);
		my $w = rand($columns - $c);
		my $h = rand($rows - $r);
		my $dir = int(rand(2)) ? 1 : -1;
		my $color = 40 + int(rand(8));

		while ($c > 0 && $w > 2) {
			draw_rect($color, $r, $c, $w, $h);

			select(undef, undef, undef, 0.04);
			if ($dir == 1) {
				draw_rect(40, $r, $c, 1, $h);
			} else {
				draw_rect(40, $r, $c+$w, 1, $h);
			}
			$c += $dir;
			if ($c + $w > $columns) {
				$w--;
			}
		}
		select(undef, undef, undef, 0.01);
	}
}

my $avail;
my @ver;
my @hor;

sub do_graphic5
{
	my $w = $columns / 3;
	my $h = $rows / 3;

	$avail = $w * $h;
	 
	# cell is padded by sentinel col and row, so I don't check array bounds
	my @cell = (map([(('1') x $w), 0], 1 .. $h), [('') x ($w + 1)]);
	@ver = map([("|  ") x $w], 1 .. $h);
	@hor = map([("+--") x $w], 0 .. $h);
	 
	walk(\@cell, int rand $w, int rand $h);	# generate
	 
	for (0 .. $h) {			# display
		print @{$hor[$_]}, "+\n";
		print @{$ver[$_]}, "|\n" if $_ < $h;
	}
}
no warnings 'recursion';

sub walk
{	my $cell = shift;

	my ($x, $y) = @_;
	$cell->[$y][$x] = '';
	$avail-- or return;	# no more bottles, er, cells
 
	my @d = ([-1, 0], [0, 1], [1, 0], [0, -1]);
	while (@d) {
		my $i = splice @d, int(rand @d), 1;
		my ($x1, $y1) = ($x + $i->[0], $y + $i->[1]);
 
		$cell->[$y1][$x1] or next;
 
		if ($x == $x1) { $hor[ max($y1, $y) ][$x] = '+  ' }
		if ($y == $y1) { $ver[$y][ max($x1, $x) ] = '   ' }
		walk($cell, $x1, $y1);
	}
}
	 

sub draw_rect
{	my $color = shift;
	my $r = shift;
	my $c = shift;
	my $w = shift;
	my $h = shift;

	my $r1 = $r + $h;

	while ($r < $r1) {
		printf "\033[%d;%dH\033[${color}m%s", $r, $c, " " x $w;
		$r++;
	}
}
sub get_tty_size
{
	my $s = `stty -a | grep columns`;
	chomp($s);
	$s =~ m/rows (\d+); columns (\d+)/;
	($rows, $columns) = ($1, $2);
}

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'help',
		);

	usage(0) if $opts{help};
	my $n = shift @ARGV;

	$| = 1;

	get_tty_size();

	my $game = defined($n) ? $n : int(rand(5));

	if ($game == 0) {
		system("$FindBin::RealBin/maze2.pl | $FindBin::RealBin/snake.pl");
		exit(0);
	}

	eval "do_graphic$game();";

	printf "\033[%dH\n", $rows;
}

sub max
{	my $x = shift;
	my $y = shift;
	
	return $x > $y ? $x : $y;
}

#######################################################################
#   Print out command line usage.				      #
#######################################################################
sub usage
{	my $ret = shift;
	my $msg = shift;

	print $msg if $msg;

	print <<EOF;
ascii-art - draw text patterns
Usage: ascii-art.pl [0..3]

Switches:

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

