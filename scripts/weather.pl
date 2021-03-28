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

my %map = (
	"Clouds - scattered clouds" => "PartlyCloudy",
	);

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
	foreach my $dt (@{$info->{list}}) {
		my $c = ($dt->{temp}{max} - -15) / 6;
		printf "| %s %s %2dC / %-3s\n|    %s - %s\n",
			strftime("%a %b %d", localtime($dt->{dt})),
			sprintf("\033[48;5;%dm        \033[0m", $c),
			$dt->{temp}{min},
			sprintf("%dC", $dt->{temp}{max}),
			$dt->{weather}[0]{main},
			$dt->{weather}[0]{description},
			;

		foreach my $w (qw/morn day eve night/) {
			printf "|  %-6s %3d C\n", 
				$w, $dt->{temp}{$w},
				;
		}

		my $d = get_icon($dt->{weather}[0]{main} . " " .
			$dt->{weather}[0]{description});
		print $_, "\n" foreach @{$icons{$d}};
	}
}

sub get_icon
{	my $d = shift;

	return "PartlyCloudy" if $d =~ /Clouds scattered/;
	return "Sunny" if $d =~ /clear/;
	return "Unknown";
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

