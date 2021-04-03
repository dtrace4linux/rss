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

######################################################################
#   Temperature RGB gradient					     #
######################################################################
my @grad = (
	[ 255,14,240 ],
	[ 255,13,240 ],
	[ 255,12,240 ],
	[ 255,11,240 ],
	[ 255,10,240 ],
	[ 255,9,240 ],
	[ 255,8,240 ],
	[ 255,7,240 ],
	[ 255,6,240 ],
	[ 255,5,240 ],
	[ 255,4,240 ],
	[ 255,3,240 ],
	[ 255,2,240 ],
	[ 255,1,240 ],
	[ 255,0,240 ],
	[ 255,0,224 ],
	[ 255,0,208 ],
	[ 255,0,192 ],
	[ 255,0,176 ],
	[ 255,0,160 ],
	[ 255,0,144 ],
	[ 255,0,128 ],
	[ 255,0,112 ],
	[ 255,0,96 ],
	[ 255,0,80 ],
	[ 255,0,64 ],
	[ 255,0,48 ],
	[ 255,0,32 ],
	[ 255,0,16 ],
	[ 255,0,0 ],
	[ 255,10,0 ],
	[ 255,20,0 ],
	[ 255,30,0 ],
	[ 255,40,0 ],
	[ 255,50,0 ],
	[ 255,60,0 ],
	[ 255,70,0 ],
	[ 255,80,0 ],
	[ 255,90,0 ],
	[ 255,100,0 ],
	[ 255,110,0 ],
	[ 255,120,0 ],
	[ 255,130,0 ],
	[ 255,140,0 ],
	[ 255,150,0 ],
	[ 255,160,0 ],
	[ 255,170,0 ],
	[ 255,180,0 ],
	[ 255,190,0 ],
	[ 255,200,0 ],
	[ 255,210,0 ],
	[ 255,220,0 ],
	[ 255,230,0 ],
	[ 255,240,0 ],
	[ 255,250,0 ],
	[ 253,255,0 ],
	[ 215,255,0 ],
	[ 176,255,0 ],
	[ 138,255,0 ],
	[ 101,255,0 ],
	[ 62,255,0 ],
	[ 23,255,0 ],
	[ 0,255,16 ],
	[ 0,255,54 ],
	[ 0,255,92 ],
	[ 0,255,131 ],
	[ 0,255,168 ],
	[ 0,255,208 ],
	[ 0,255,244 ],
	[ 0,228,255 ],
	[ 0,212,255 ],
	[ 0,196,255 ],
	[ 0,180,255 ],
	[ 0,164,255 ],
	[ 0,148,255 ],
	[ 0,132,255 ],
	[ 0,116,255 ],
	[ 0,100,255 ],
	[ 0,84,255 ],
	[ 0,68,255 ],
	[ 0,50,255 ],
	[ 0,34,255 ],
	[ 0,18,255 ],
	[ 0,2,255 ],
	[ 0,0,255 ],
	[ 1,0,255 ],
	[ 2,0,255 ],
	[ 3,0,255 ],
	[ 4,0,255 ],
	[ 5,0,255 ],
);
@grad = reverse(@grad);

my %icons = (
		Unknown => [
			"    .-.      ",
			"     __)     ",
			"    (        ",
			"     `-      ",
			"             ",
		],
		Cloudy => [
			"             ",
			"\033[38;5;250m     .--.    \033[0m",
			"\033[38;5;250m  .-(    ).  \033[0m",
			"\033[38;5;250m (___.__)__) \033[0m",
			"             ",
		],
		Fog => [
			"             ",
			"\033[38;5;251m _ - _ - _ - \033[0m",
			"\033[38;5;251m  _ - _ - _  \033[0m",
			"\033[38;5;251m _ - _ - _ - \033[0m",
			"             ",
		],
		HeavyRain => [
			"\033[38;5;240;1m     .-.     \033[0m",
			"\033[38;5;240;1m    (   ).   \033[0m",
			"\033[38;5;240;1m   (___(__)  \033[0m",
			"\033[38;5;21;1m             \033[0m",
			"\033[38;5;21;1m             \033[0m",
		],
		HeavyShowers => [
			"\033[38;5;226m _`/\"\"\033[38;5;240;1m.-.    \033[0m",
			"\033[38;5;226m  ,\\_\033[38;5;240;1m(   ).  \033[0m",
			"\033[38;5;226m   /\033[38;5;240;1m(___(__) \033[0m",
			"\033[38;5;21;1m             \033[0m",
			"\033[38;5;21;1m             \033[0m",
		],
		HeavySnow => [
			"\033[38;5;240;1m     .-.     \033[0m",
			"\033[38;5;240;1m    (   ).   \033[0m",
			"\033[38;5;240;1m   (___(__)  \033[0m",
			"\033[38;5;255;1m   * * * *   \033[0m",
			"\033[38;5;255;1m  * * * *    \033[0m",
		],
		HeavySnowShowers => [
			"\033[38;5;226m _`/\"\"\033[38;5;240;1m.-.    \033[0m",
			"\033[38;5;226m  ,\\_\033[38;5;240;1m(   ).  \033[0m",
			"\033[38;5;226m   /\033[38;5;240;1m(___(__) \033[0m",
			"\033[38;5;255;1m    * * * *  \033[0m",
			"\033[38;5;255;1m   * * * *   \033[0m",
		],
		LightRain => [
			"\033[38;5;250m     .-.     \033[0m",
			"\033[38;5;250m    (   ).   \033[0m",
			"\033[38;5;250m   (___(__)  \033[0m",
			"\033[38;5;111m             \033[0m",
			"\033[38;5;111m             \033[0m",
		],
		LightShowers => [
			"\033[38;5;226m _`/\"\"\033[38;5;250m.-.    \033[0m",
			"\033[38;5;226m  ,\\_\033[38;5;250m(   ).  \033[0m",
			"\033[38;5;226m   /\033[38;5;250m(___(__) \033[0m",
			"\033[38;5;111m             \033[0m",
			"\033[38;5;111m             \033[0m",
		],
		LightSleet => [
			"\033[38;5;250m     .-.     \033[0m",
			"\033[38;5;250m    (   ).   \033[0m",
			"\033[38;5;250m   (___(__)  \033[0m",
			"\033[38;5;111m      \033[38;5;255m*\033[38;5;111m   \033[38;5;255m*  \033[0m",
			"\033[38;5;255m   *\033[38;5;111m   \033[38;5;255m*\033[38;5;111m     \033[0m",
		],
		LightSleetShowers => [
			"\033[38;5;226m _`/\"\"\033[38;5;250m.-.    \033[0m",
			"\033[38;5;226m  ,\\_\033[38;5;250m(   ).  \033[0m",
			"\033[38;5;226m   /\033[38;5;250m(___(__) \033[0m",
			"\033[38;5;111m       \033[38;5;255m*\033[38;5;111m   \033[38;5;255m* \033[0m",
			"\033[38;5;255m    *\033[38;5;111m   \033[38;5;255m*\033[38;5;111m    \033[0m",
		],
		LightSnow => [
			"\033[38;5;250m     .-.     \033[0m",
			"\033[38;5;250m    (   ).   \033[0m",
			"\033[38;5;250m   (___(__)  \033[0m",
			"\033[38;5;255m    *  *  *  \033[0m",
			"\033[38;5;255m   *  *  *   \033[0m",
		],
		LightSnowShowers => [
			"\033[38;5;226m _`/\"\"\033[38;5;250m.-.    \033[0m",
			"\033[38;5;226m  ,\\_\033[38;5;250m(   ).  \033[0m",
			"\033[38;5;226m   /\033[38;5;250m(___(__) \033[0m",
			"\033[38;5;255m     *  *  * \033[0m",
			"\033[38;5;255m    *  *  *  \033[0m",
		],
		PartlyCloudy => [
			"\033[38;5;226m   \\  /\033[0m      ",
			"\033[38;5;226m _ /\"\"\033[38;5;250m.-.    \033[0m",
			"\033[38;5;226m   \\_\033[38;5;250m(   ).  \033[0m",
			"\033[38;5;226m   /\033[38;5;250m(___(__) \033[0m",
			"             ",
		],
		Sunny => [
			"\033[38;5;226m    \\   /    \033[0m",
			"\033[38;5;226m     .-.     \033[0m",
			"\033[38;5;226m    (\033[43m   )\033[40m    \033[0m",
			"\033[38;5;226m     `-      \033[0m",
			"\033[38;5;226m    /   \\    \033[0m",
		],
		ThunderyHeavyRain => [
			"\033[38;5;240;1m     .-.     \033[0m",
			"\033[38;5;240;1m    (   ).   \033[0m",
			"\033[38;5;240;1m   (___(__)  \033[0m",
			"\033[38;5;21;1m    \033[38;5;228;5m \033[38;5;21;25m  \033[38;5;228;5m \033[38;5;21;25m     \033[0m",
			"\033[38;5;21;1m      \033[38;5;228;5m \033[38;5;21;25m      \033[0m",
		],
		ThunderyShowers => [
			"\033[38;5;226m _`/\"\"\033[38;5;250m.-.    \033[0m",
			"\033[38;5;226m  ,\\_\033[38;5;250m(   ).  \033[0m",
			"\033[38;5;226m   /\033[38;5;250m(___(__) \033[0m",
			"\033[38;5;228;5m     \033[38;5;111;25m   \033[38;5;228;5m \033[38;5;111;25m    \033[0m",
			"\033[38;5;111m             \033[0m",
		],
		ThunderySnowShowers => [
			"\033[38;5;226m _`/\"\"\033[38;5;250m.-.    \033[0m",
			"\033[38;5;226m  ,\\_\033[38;5;250m(   ).  \033[0m",
			"\033[38;5;226m   /\033[38;5;250m(___(__) \033[0m",
			"\033[38;5;255m     *\033[38;5;228;5m \033[38;5;255;25m *\033[38;5;228;5m \033[38;5;255;25m * \033[0m",
			"\033[38;5;255m    *  *  *  \033[0m",
		],
		VeryCloudy => [
			"             ",
			"\033[38;5;240;1m     .--.    \033[0m",
			"\033[38;5;240;1m  .-(    ).  \033[0m",
			"\033[38;5;240;1m (___.__)__) \033[0m",
			"             ",
		],
	);

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'help',
		'daily',
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
	my $api_cmd = $opts{daily} ? 'forecast/daily' : 'weather';

	my $cmd = "http://api.openweathermap.org/data/2.5/" .
		"$api_cmd?q=$opts{location}&units=$opts{units}&appid=$opts{key}";

	print $cmd, "\n" if $opts{v};

	my $fn = $opts{daily} ? "/tmp/weather-daily.json" : "/tmp/weather-forecast.json";
	my $mtime = (stat($fn))[9];
	if (!defined($mtime) || $mtime + 1500 < time()) {
		system("curl -s  -o $fn '$cmd'");
	}

	my $fh = new FileHandle($fn);
	local $/ = undef;
	my $txt = <$fh>;

	my $json = JSON->new->allow_nonref;
	my $info = $json->decode($txt);

	if (!$opts{daily}) {
		printf "Temperature: %4d C  %s - %s\n", 
			$info->{main}{temp},
			$info->{weather}[0]{main},
			$info->{weather}[0]{description},
			;
		printf "Temp min   : %4d C\n", $info->{main}{temp_min};
		printf "Temp max   : %4d C\n", $info->{main}{temp_max};
		printf "Pressure   : %4d hPa\n", $info->{main}{pressure};
		printf "Humidity   : %4d %%\n", $info->{main}{humidity};
		return;
	}

	print "\033[44m    \033[46m    \033[43m    \033[41m    \033[40m\n";

	my %data;
	my $r = 0;
	my $c = 0;
	foreach my $dt (@{$info->{list}}) {
#		my $c = ($dt->{temp}{max} - -15) / 6;
		my $s = sprintf("| %s %2dC / %-3s\n|    %s - %s\n",
			strftime("%a %b %d", localtime($dt->{dt})),
#			sprintf("\033[48;5;%dm        \033[0m", $c),
			$dt->{temp}{min},
			sprintf("%dC", $dt->{temp}{max}),
#			show_temp($dt->{temp}{max}),
			$dt->{weather}[0]{main},
			$dt->{weather}[0]{description},
			);

		foreach my $w (qw/morn day eve night/) {
			$s .= sprintf("|  %-6s %3d C\n", 
				$w, $dt->{temp}{$w},
				);
		}
		$s .= "  " . show_temp($dt->{temp}{max}) . "\n";

#		my $d = get_icon($dt->{weather}[0]{main} . " " .
#			$dt->{weather}[0]{description});
#		print $_, "\n" foreach @{$icons{$d}};

		$data{$r}{$c} = $s;
		if (++$c > 2) {
			$r++;
			$c = 0;
		}
	}

	for (my $r1 = 0; $r1 <= $r; $r1++) {
		last if !defined($data{$r1});
		for ($c = 0; defined($data{$r1}{$c}) && $c < 3; $c++) {
			foreach my $s (split("\n", $data{$r1}{$c})) {
				print "$s\n";
			}
		}
	}
}

sub get_icon
{	my $d = shift;

	return "PartlyCloudy" if $d =~ /Clouds scattered/;
	return "Sunny" if $d =~ /clear/;
	return "Unknown";
}

sub show_temp
{	my $t = shift;

	my $n = scalar(@grad);

	my $t1 = 0;
	$t1 = .9 * $n if $t > 30;
	$t1 = .7 * $n if $t < 30;
	$t1 = .6 * $n if $t < 20;
	$t1 = .5 * $n if $t < 15;
	$t1 = .3 * $n if $t < 10;
	$t1 = .2 * $n if $t < 0;

	my $s = '';
	for (my $i = 0; $i < @grad && $i < $t1; $i += 4) {

		$s .= sprintf("\033[48;2;%d;%d;%dm  \033[0m", 
			$grad[$i][0],
			$grad[$i][1],
			$grad[$i][2],
			);
	}
#	print " $t1 - $t - $n\n";
#	print "$s\n";
	return $s;
}

#######################################################################
#   Print out command line usage.				      #
#######################################################################
sub usage
{	my $ret = shift;
	my $msg = shift;

	print $msg if $msg;

	print <<EOF;
weather.pl -- show temperature and forecast information
Usage:

Switches:

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;
