#! /usr/bin/perl

# http://rosettacode.org/wiki/Conway%27s_Game_of_Life#Perl
# 

my $rows;
my $columns;
my $exit_time;

sub get_tty_size
{
	my $s = `stty -a | grep columns`;
	chomp($s);
	$s =~ m/rows (\d+); columns (\d+)/;
	($rows, $columns) = ($1, $2);
}

$| = 1;
get_tty_size();
my ($width, $height, $generations) = @ARGV;
if (!$width) {
	$width = $columns-1;
	$height = $rows-2;
	$generations = 10000;
	$exit_time = time() + 20;
}
 
my $printed;
 
sub generate {
   (map
       {[ (map { rand () < 0.5 } 1 .. $width), 0 ]}
       1 .. $height),
   [(0) x ($width + 1)];
}
 
sub nexgen {
   my @prev = map {[@$_]} @_;
   my @new = map {[ (0) x ($width + 1) ]} 0 .. $height;
   foreach my $row ( 0 .. $height - 1 ) {
       foreach my $col ( 0 .. $width - 1 ) {
           my $val =
             $prev[ $row - 1 ][ $col - 1 ] +
             $prev[ $row - 1 ][ $col     ] +
             $prev[ $row - 1 ][ $col + 1 ] +
             $prev[ $row     ][ $col - 1 ] +
             $prev[ $row     ][ $col + 1 ] +
             $prev[ $row + 1 ][ $col - 1 ] +
             $prev[ $row + 1 ][ $col     ] +
             $prev[ $row + 1 ][ $col + 1 ];
           $new[$row][$col] =
               ( $prev[$row][$col] && $val == 2 || $val == 3 );
       }
   }
   return @new;
}
 
sub printlife {
   my @life = @_;
   if ($printed) {
	# Move the cursor up to print over prior generation.
	print "\e[1A" x $height;
   }
   $printed = 1;
   foreach my $row ( 0 .. $height - 1 ) {
       foreach my $col ( 0 .. $width - 1 ) {
           print($life[$row][$col]
             ? "\e[33;45;1m \e[0m"
             : "\e[1;34;1m \e[0m");
       }
       print "\n";
   }
}
 
my @life = generate;
print "Start\n";
printlife @life;
foreach my $stage ( 1 .. $generations ) {
   select(undef, undef, undef, 0.5);
   print "Generation $stage\e[1A";
   @life = nexgen @life;
   printlife @life;
   last if $exit_time && time() > $exit_time;
}
print "\n";
