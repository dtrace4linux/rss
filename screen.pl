#! /usr/bin/perl

# $Header:$

use strict;
use warnings;

use File::Basename;
use FileHandle;
use Getopt::Long;
use IO::File;
use POSIX;
use IO::Socket;
use FindBin;

#######################################################################
#   Command line switches.					      #
#######################################################################
my %opts = (
	port => 22223,
	dir => "/tmp/$ENV{USER}/screenshots",
	);

my $sock;
my $fb_prog = "$FindBin::RealBin/bin/fb";

######################################################################
#   Remote http request to dump the console screen buffer.	     #
######################################################################
my $seq_num = 0;

sub do_screen
{	my $client = shift;
	my $req = shift;

	$req =~ s/ .*$//;
	$req =~ s/^.*\///;

#print STDERR "sending screen dump\n";
	print $client "HTTP/1.0 200 ok\r\n";

	if ($req eq 'screen') {
		print $client "Content-Type: text/html\r\n";
		print $client "\r\n";
		print $client <<EOF;
<!DOCTYPE html>
<html lang="en-US">
<meta charset="UTF-8">

<script type="text/javascript">

	var i = 0;
	var downloadingImage = new Image();
	downloadingImage.onload = function(){
	    var image = document.images[0];
	    image.src = this.src;   
	};
	function updateImage() { 
		obj = document.img1;
		document.getElementById("myelement1") = "Hello world!" + i++;
		//document.write("Text to display." + i++);
		downloadingImage.src = obj.src;
		setTimeout(updateImage, 1000);
	}
	setTimeout(updateImage, 1000);
</script>

<div style="position:relative">
<p id="myelement1">
hello world
</p>

<img name='img1' class='pic' src='/screen2.jpg' width=1000 height=600 />
<!--
<img name='img2' class='pic' src='/screen2.jpg' width=1000 height=600 
	style="visibility:hidden"
        onload="this.style.visibility='visible'"
	/>
-->

</div>
</body>
EOF
     	return;
	}

#print "req=$req\n";

	if ($req ne 'screen2.jpg') {
		return;
	}

	$client->autoflush();

	my $fn = do_screenshot();

	print $client "Content-Type: image/jpeg\r\n";
	my $size = (stat("$fn"))[7];
	print $client "Content-Size: $size\r\n";
	print $client "\r\n";

	my $fh = new FileHandle("$fn");
	my $s;
	while (sysread($fh, $s, 32 * 1024)) {
		syswrite($client, $s);
	}
#print STDERR "done\n";
}

sub do_client
{
	my $client = shift;

	my $req = '';
	eval {
		local $SIG{ALRM} = sub {};
		alarm(5);
		sysread($client, $req, 4096);
		alarm(0);
		};
	if ($@) {
		my ($hname) = gethostbyaddr($client->peerhost(), AF_INET) || 'unknown';
		print time_string() . "Connection ",
			$client->peerhost() . ":" . $client->peerport() . " $hname - timed out reading request\n";
		return;
	}

	return if !$req;

	return if $req !~ /^GET /;
	$req =~ s/^GET //;
	$req = (split(/[\r\n]/, $req))[0];

	print time_string() . "Admin: $req\n";

	do_screen($client, $req);
	exit(0);
}

my $ss_time = 0;

sub do_screenshot
{
	my $t = strftime("%H%M", localtime());
	my $fn = "$opts{dir}/screen-$t.jpg";
	if ($ss_time != $t || ! -f $fn) {
		$ss_time = $t;
		spawn("$fb_prog -o $fn");
	}

	return $fn;
}

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'dir=s',
		'help',
		'port=s',
		'ppid=s',
		);

	usage(0) if $opts{help};

	mkdir($opts{dir}, 0755);

	$SIG{CHLD} = 'IGNORE';

	$sock = IO::Socket::INET->new (
	   LocalPort => $opts{port},
	   Type      => SOCK_STREAM,
	   ReuseAddr => 1,
	   Listen    => 10);
	die "screen.pl: Cannot create listening port $opts{port} - $!" if !$sock;

	while (1) {
		my $bits = '';
		my $rbits;

		vec($bits, $sock->fileno(), 1) = 1;
		my $n = select($rbits = $bits, undef, undef, 1.0);
		exit(0) if $opts{ppid} && ! -d "/proc/$opts{ppid}";

		if (!vec($rbits, $sock->fileno(), 1)) {
			do_screenshot();
			next;
		}

		my $client = $sock->accept();
		if (fork() == 0) {
			do_client($client);
			exit(0);
		}
	}
}

sub spawn
{	my $cmd = shift;

	return system($cmd);
}
sub time_string
{
	return strftime("%Y%m%d %H:%M:%S ", localtime);
}

#######################################################################
#   Print out command line usage.				      #
#######################################################################
sub usage
{	my $ret = shift;
	my $msg = shift;

	print $msg if $msg;

	print <<EOF;
screen - render local framebuffer to a web request
Usage: screen.pl [switches]

Switches:

  -dir <dir>      Directory to write screenshots.
  -port NN        Port to listen on (default: $opts{port})
  -ppid <pid>     Terminate if parent process dies.

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

