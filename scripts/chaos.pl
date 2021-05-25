#!/usr/bin/perl

# http://rosettacode.org/wiki/Chaos_game#Perl

my $rows;
my $columns;

sub get_tty_size
{
	my $s = `stty -a | grep columns`;
	chomp($s);
	$s =~ m/rows (\d+); columns (\d+)/;
	($rows, $columns) = ($1, $2);
}

$| = 1;
get_tty_size();
my $width  = $columns - 1;
my $height = $rows - 1;
 
my @points = (
    [ $width/2,         0],
    [        0, $height-1],
    [$height-1, $height-1],
);
 
my $r = [int(rand($width)), int(rand($height))];
$| = 1;
printf("\033[%dm", int(rand(7)) + 31);
 
foreach my $i (1 .. 100000) {
    my $p = $points[rand @points];
 
    my $h = [
        int(($p->[0] + $r->[0]) / 2),
        int(($p->[1] + $r->[1]) / 2),
    ];
 
    printf("\033[%d;%dHx", $h->[0] + 1, $h->[1] + 1);
 
    $r = $h;
}
