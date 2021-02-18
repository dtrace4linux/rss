#! /usr/bin/perl
package Utils;

use strict;
use warnings;

use POSIX;
use File::Basename;

use Exporter;                                                                
our @ISA = qw(Exporter);   
our @EXPORT = qw(background kill_old logfname time_string);

######################################################################
#   Background and redirect output.				     #
######################################################################
our $logfname;
sub background
{	my $ident = shift;
	my $log_fh = shift;
	my $opts = shift;

	return if $opts->{f};

	###############################################
	#   Now redirect.			      #
	###############################################
	my $logdir = $ENV{LOGDIR} || "$ENV{HOME}/log";
	$logfname = "$logdir/$ident.log";
	print time_string() . "Process $$ Redirecting to $logfname\n" if !$opts->{quiet};
	mkdir($logdir, 0755);
	if (!open(STDOUT, ">>$logfname")) {
		system("ls -l $logfname ; id");
		die "Cannot redirect STDOUT to $logfname - $!";
	}
	open(STDERR, ">>&STDOUT");
	select(STDERR); $| = 1;
	select(STDOUT); $| = 1;
	STDIN->close();
	STDOUT->autoflush();
	STDERR->autoflush();

	$$log_fh = \*STDOUT;

	$SIG{HUP} = '__IGNORE__';
	if (fork()) {
		exit(1);
	}
	my $fh = new FileHandle(">/tmp/$ident.pid");
	die "Cannot create /tmp/$ident.pid - $!" if !$fh;
	print $fh "$$ " . time() . " " . time_string() . "\n";
	$fh->close();

	print "\n";
	print time_string() . "$0 starting - PID: $$\n";
}

sub kill_old
{	my $ident = shift;
	my $opts = shift;

	return if $opts->{nokill};

	###############################################
	#   Check if rss.pl is already running.	      #
	###############################################
	my $fh = new FileHandle("/tmp/$ident.pid");
	if ($fh && !$opts->{clean}) {
		my $pid = <$fh>;
		if ($pid) {
			$pid = (split(" ", $pid))[0];
			chomp($pid);
			if ($pid == $$) {
				print "kill_old: looking at my own pid ($$) in /tmp/$ident.pid\n";
				return;
			}
			system("ps $pid") if !$opts->{quiet};
			my $cnt = `ps $pid | grep -v PID | wc -l`;
			chomp($cnt);
			if ($cnt) {
				print "Killing (SIGTERM) old $ident.pl - pid:$pid\n" if !$opts->{quiet};
				kill(SIGTERM, $pid);
				sleep(1);
			} else {
				my $s = `ps ax | grep -v sudo | grep -v PID | grep -v grep | grep $ident.pl`;
				foreach my $ln (split("\n", $s)) {
					my $p = (split(" ", $ln))[0];
					if ($p eq $$ || get_ppid($$) eq $p) {
#						print "me: $ln\n";
						next;
					}
					print "Killing old process $ident.pl - pid:$p (mypid:$$)\n";
					print "$ln\n";
					kill(SIGTERM, $p);
					sleep(1);
				}
			}
		}
		$fh->close();
	}
}

sub get_ppid
{	my $p = shift;

	my $fh = new FileHandle("/proc/$p/status");
	while (<$fh>) {
		chomp;
		if (/^PPid:\t(\d+)/) {
			return $1;
		}
	}
	return -1;
}
sub time_string
{
	return strftime("%Y%m%d %H:%M:%S ", localtime);
}

1;
