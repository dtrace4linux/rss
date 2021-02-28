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
my %opts;
my $columns;
my $rows;
my $stock_time = 0;
my $weather_time = 0;

sub clean_text
{	my $txt = shift;

	$txt =~ s/\xe2\x80/'/g;
	$txt =~ s/&#039;/'/g;
	$txt =~ s/&#39;/'/g;
	$txt =~ s/&#22;/"/g;
	$txt =~ s/&#27;/'/g;
	$txt =~ s/&#32;/ /g;
	$txt =~ s/&#x27;/'/g;
	$txt =~ s/&amp;#x27;/'/g;
	$txt =~ s/&quot;/"/g;
	$txt =~ s/&amp;/\&/g;
	$txt =~ s/&quot;/"/g;
	$txt =~ s/\xe2\x80[\x98\x99]/'/g;

	return $txt;
}

sub do_status_line
{
	return if $opts{notime};

	if (defined($opts{ppid}) && ! -d "/proc/$opts{ppid}") {
		print time_string() . "[$$] parent $opts{ppid} terminated\n";
		exit(0);
	}

	my $fh = new FileHandle("/proc/loadavg");
	my $avg = <$fh>;
	$avg =~ s/ .*//;
	printf "\033[1;%dH", $columns - 20;

	my $c;
	if ($avg >= 1) {
		$c = "\033[33m";
	} else {
		$c = "\033[1;33m";
	}
	printf strftime("$c Time: %H:%M:%S ", localtime()) .
		"\033[%dH\033[37;40m", $rows;
}

my $hist_mode = 0;
my $hist_pos = -1;
sub do_history
{	my $dir = shift;

	my $fh = new FileHandle("/tmp/rss_console.log");
	my @lns = <$fh>;

	if ($hist_mode == 0) {
		$hist_pos = @lns;
	}

	my $pos;
	my $pgsize = ($rows * 2) / 3;
	if ($dir > 0) {
		$pos = $hist_pos + $pgsize;
	} else {
		$pos = $hist_pos - $pgsize;
	}
	return if $pos < 0;
	if ($pos > @lns) {
		$hist_mode = 0;
		return;
	}

	$hist_pos = $pos;
	print "\033[93;37m  ==== history pos=$hist_pos, size=", scalar(@lns), "\033[K\n";
	print "\033[37;40m";
	$hist_mode = 1;
	for (my $i = 0; $i < $pgsize; $i++) {
		print $lns[$pos + $i];
	}
	my $green = "32";
	my $white = "37";
	print "\033[${green}m  -- More --\033[${white}m";
}

sub do_stocks
{
	if ($opts{stocks} &&
	    time() > $stock_time + $opts{stock_time}) {
	    	reset_fb();
		$stock_time = time();
		my $t = strftime("%H:%M ", localtime());
		my $cmd = "$FindBin::RealBin/stock.pl " .
			"-cols $columns -update -random -o $ENV{HOME}/.rss/ticker/stock.log " .
			join(" ", @{$opts{stocks}});
		#print "$cmd\n";
		my $str = `$cmd`;
		pr($t . $str);
	}
}


sub do_weather
{
	if ($opts{weather} && $opts{weather_location} &&
	    time() > $weather_time + $opts{weather_time} && -x $opts{weather_app}) {
	    	reset_fb();
		$weather_time = time();
		my $t = strftime("%H:%M ", localtime());
		my $w = `$opts{weather_app} -l $opts{weather_location} -p false`;

		my $fn = "$ENV{HOME}/.rss/ticker/weather.log";
		my $fh = new FileHandle(">>$fn");
		print $fh time_string() . $w if $fh;
		pr($t . $w);
	}
}

sub main
{
	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'help',
		'page=s',
		'ppid=s',
		);

	usage(0) if $opts{help};

	$| = 1;

	print "\033[37m";

	my $s = `stty -a | grep columns`;
	chomp($s);
	$s =~ m/rows (\d+); columns (\d+)/;
	($rows, $columns) = ($1, $2);

	read_rss_config();

	do_ticker();
}
######################################################################
#   Generate  periodic/random  headline.  We  want a console output  #
#   (plain  text)  and  HTML,  which  can  offer  more features. In  #
#   addition,  for  console, we may support touch based input. (Not  #
#   currently implemented).					     #
######################################################################

######################################################################
#   Array  allowing  us to control the order and frequency of pages  #
#   (per tick == minute)					     #
######################################################################
my %page_sched = (
	0 => { freq => 0},    # headlines
	1 => { freq => 60},   # random topic
	2 => { freq => 600},  # calendar
	3 => { freq => 1200}, # image
	4 => { freq => 1800}, # reminder
	5 => { freq => 1800}, # rss-hello banner
	6 => { freq => 3600}, # rss-help 
	);
my $npages = scalar(keys(%page_sched));

sub sched_page
{	my $txt = shift;

	return 0 if $txt;

	for (my $i = $npages - 1; $i > 0; $i--) {
		if (!defined($page_sched{$i}{last_time})) {
			$page_sched{$i}{last_time} = time();
			return $i;
		}
		if ($page_sched{$i}{last_time} + $page_sched{$i}{freq} < time()) {
			$page_sched{$i}{last_time} = time();
			return $i;
		}
	}

	return 1;
}

sub do_ticker
{
	my @files;
	my $f = 0;

	my $ticks = 0;
	my $t_copy = 0;

	my $css_fn = "$FindBin::RealBin/rss.css";

	my $cols = $columns - 10;
	my %seen_title;

	mkdir("$ENV{HOME}/.rss/ticker", 0755);

	###############################################
	#   We  display  other pages, other than raw  #
	#   headlines,  such  as a specific article,  #
	#   or  a  summary  or weather history. This  #
	#   selects which page we are doing.	      #
	###############################################
	my $page = 0;

	my @history;

	while (1) {
		if (defined($opts{ppid}) && ! -d "/proc/$opts{ppid}") {
			print "parent $opts{ppid} terminated\n";
			exit(0);
		}

		my $t = 60;

		###############################################
		#   Get  the  CSS file, dynamically, in case  #
		#   we  are  editing  it while the script is  #
		#   running.				      #
		###############################################
		my $fh = new FileHandle($css_fn);
		die "Cannot locate rss.css\n" if !$fh;
		my $rss = '';
		while (<$fh>) {
			$rss .= $_;
		}
		$fh->close();

		my $rss1 = $rss;
		$rss1 =~ s/\$t/60/;

		###############################################
		#   Look  at  about  100 recent articles for  #
		#   display.				      #
		###############################################
		my $con_txt = '';
		@files = (reverse(glob("$ENV{HOME}/.rss/articles/*")))[0..100];
		for (my $i = 0; $i < 100; $i++) {

			my $info = read_article($files[$i]);

			my $div1 = '';
			my $div2 = '';
			if (@history < 5) {
				$div1 = "<div style='font-size: 16px;'>";
				$div2 = "</div>";
			}

			my $title = $info->{title};
			next if $seen_title{$title};
			$seen_title{$title} = 1;

			###############################################
			#   Some  cleanups for common glyph usage in  #
			#   headlines				      #
			###############################################
			$title = clean_text($title);

			my $lnk = $info->{link};
			$lnk =~ s/^https*:\/\///;
			$lnk =~ s/^www\.//;
			$lnk =~ s/^(go|rss)\.//;
			$lnk =~ s/\..*$//;
			push @history,
				$div1 . 
				$info->{date2} . " " .
	#			strftime("%H:%M ", localtime()) . 
				"$title <a target='_blank' href='$info->{link}'><span data-label='$lnk'>$lnk</span></a>" .
				$div2;

			if (length($title) > $cols) {
				$title = substr($title, 0, $cols - 1);
				}

			$con_txt .= strftime("%H:%M ", localtime()) .  $title . "\n";
		}

		###############################################
		#   Screen  may  contain  an image - when we  #
		#   scroll  we  get turds. So put the screen  #
		#   back if we have a saved image.	      #
		###############################################
		reset_fb();

		$page = sched_page($con_txt);
		$page = $opts{page} if defined($opts{page});

		if ($page == 0) {
			pr($con_txt);
		} elsif ($page == 1) {
			my $fn = $files[rand(@files)];

			do_page1($fn);
		} elsif ($page == 2) {
			do_page2_calendar();
		} elsif ($page == 3) {
			do_page3_image()
		} elsif ($page == 4) {
			do_page4_reminder()
		} elsif ($page == 5) {
			do_page5_hello();
		} elsif ($page == 6) {
			do_page6_help();
		}

		do_weather();
		do_stocks();

		if (@history > 100) {
			@history = @history[0..99];
		}

		my $str = '';
		for (my $i = 0; $i < @history; ) {
			for (my $j = 0; $j < 5 && $i < @history; $j++) {
				$str .= $history[$i++] . "<br>\n";
			}
			$str .= "<hr>\n";
		}

		my $fn = "/tmp/ticker.html";
		my $ofh = new FileHandle(">$fn.tmp");
		print $ofh $rss1, 
			"Updated: ", strftime("%H:%M:%S %a %e %b", localtime()),
			$str;
		$ofh->close();
		rename("$fn.tmp", $fn);

		if (time() > $t_copy + 180 && $opts{copy_script}) {
			system("$opts{copy_script} $fn");
			$t_copy = time();
		}

		for (my $i = 0; $i < $t; $i++) {
			do_status_line();

			my ($ev, $action, $x, $y) = ev_check();
			if ($ev < 0) {
				sleep(1);
				next;
			}

			next if $ev == 0;

			if ($action eq 'top-left' || $action eq 'top-right') {
				do_history(-1);
				next;
			}
			
			if ($action eq 'bottom-left' || $action eq 'bottom-right') {
				do_history(1);
			}

			if ($hist_mode == 0) {
				$ticks++;
				last;
			}
		}
	}
	exit(0);
}

sub do_page1
{	my $fn = shift;


	my $info = read_article($fn);

	my $title = clean_text($info->{title});
	my $url = $info->{link};
	#$url =~ s/^https*:\/\///;
	#$url =~ s/\/.*$//;

	my $txt = $info->{body};
	$txt =~ s/<[^>]*>//g;
	$txt = clean_text($txt);

	###############################################
	#   Keep  a history of what we show; want to  #
	#   decide  if  we are repeating entries too  #
	#   often.				      #
	###############################################
	my $fh = new FileHandle(">>/tmp/page2.log");
	if ($fh) {
		print $fh time_string() . "article=" . basename($fn) . " $title\n";
	}

	pr("\n");
	pr("\033[37mTitle: \033[36m$title\033[32m\n");
	pr($url . "\n");

	my $last_ln = 'xxx';
	my $col = 0;
	my $row = 0;
	foreach my $ln (split("\n", $txt)) {
		$ln =~ s/^\s+//;
		next if $last_ln eq '' && $ln eq '';
		###############################################
		#   Print out the line, but word wrap it.     #
		###############################################
		foreach my $wd (split(" ", $ln)) {
			if ($col + 1 + length($wd) >= $columns) {
				pr("\n");
				$row++;
				$col = 0;
			}
			if ($col) {
				pr(" ");
				$col++;
			}
			pr($wd);
			$col += length($wd);
		}
		$last_ln = $ln;
	}
	pr("\n") if $col;
}

######################################################################
#   We do what /bin/cal does, but /bin/cal is not configurable - it  #
#   wont highlight the current day if stdout is a pipe.		     #
######################################################################
sub do_page2_calendar
{
	my %dow = (
		Sun => 0,
		Mon => 1,
		Tue => 2,
		Wed => 3,
		Thu => 4,
		Fri => 5,
		Sat => 6,
		);

	###############################################
	#   Get the time, for the margin.	      #
	###############################################
	my $tstr;
	if (int(rand(2)) == 0) {
		my $t = strftime("%H:%M", localtime());
		my $opt = int(rand(2)) == 0 ? " --gay" : "";
		$tstr = `toilet $opt $t`;
	} else {
		my $t = strftime("%H:%M", localtime());
		$tstr = `figlet $t`;
	}
	my @trow = split("\n", $tstr);
	while ($trow[0] =~ /^ +$/) {
		shift @trow;
	}

	my $margin = " " x (($columns - 21) / 4);
	my $s = strftime("   %B %Y", localtime());
	my $d = strftime("%d", localtime());
	my $this_month = strftime("%B", localtime());
	my $dow = strftime("%a", localtime());

	pr("\n");
	pr("$margin\033[36m$s\033[37m\n");
	pr("${margin}\033[33;1mSu Mo Tu We Th Fr Sa\033[0;37m\n");

	my $i = $dow{$dow};
	my $t = time() - $d * 86400;
	my $row = 0;
	for (my $j = 0; $j < 40; $j++) {
		my $d1 = strftime("%d", localtime($t));
		my $month = strftime("%B", localtime($t));
		my $dow1 = strftime("%a", localtime($t));
		$t += 86400;

		if ($dow1 eq 'Sun') {
			pr($margin);
		}
		if ($month ne $this_month) {
			pr("   ");
		} elsif ($d1 == $d) {
			pr(sprintf("\033[1;43;30m%2d\033[37;40;0m ", $d1));
		} else {
			pr(sprintf("%2d ", $d1));
		}
		if ($dow1 eq 'Sat') {
			if (@trow) {
				pr("    ");
				print shift @trow;
			}
			pr("\n");
			$row++;
		}
	}
	pr("\n");
}

######################################################################
#   Display a random image.					     #
######################################################################
sub do_page3_image
{

	$opts{image_dir} =~ s/\$HOME/$ENV{HOME}/;
	my @img = glob("$opts{image_dir}/*");
	push @img, glob("$ENV{HOME}/images/*");
	my $fn = $img[rand(@img)];
	pr(time_string() . "[img: $fn]\n");

	if (-x "$FindBin::RealBin/tools/fb") {
		# Save screen before
		if ( -e "/dev/fb0") {
			system("cat /dev/fb0 > /tmp/screendump");
		}
		system("$FindBin::RealBin/tools/fb -effects -fullscreen -q $fn");
		return;
	}

	if (-x "/usr/bin/img2txt" && $fn) {
		my $w = $columns - 1;
		my $h = $rows - 1;
		system("/usr/bin/img2txt -W $w -H $h $fn");
		return;
	}
	pr("(No images found to display)\n");
}
sub do_page4_reminder
{
	my $path = $FindBin::RealBin;
	my $fh = new FileHandle("$path/reminder.pl $path/reminders.txt |");
	while (<$fh>) {
		pr($_);
	}
}

sub do_page5_hello
{
	my $fh = new FileHandle("$FindBin::RealBin/rss-hello.txt");
	while (<$fh>) {
		print;
	}
}

my $hostname = `hostname`;
sub do_page6_help
{
	my $fh = new FileHandle("$FindBin::RealBin/rss-help.txt");
	while (<$fh>) {
		print;
	}
	if (! -w "/dev/input/event0") {
		print <<EOF;
      NOTE: /dev/input/event0 is not writable. Touch screen will not work.
           \$ chmod 666 /dev/input/event0
EOF
	}
	if (! -w "/dev/input/event0") {
		print <<EOF;
      NOTE: /dev/fb0 is not writable. Images will not display.
          \$ chmod 666 /dev/input/event0
EOF
	}
	chomp($hostname);
	my $ip = `getent hosts $hostname`;
	chomp($ip);
	$ip = (split(" ", $ip))[0];
	my $disk = `df -h /`;
	$disk = (split("\n", $disk))[1];
	my ($size, $used, $pc) = (split(" ", $disk))[1, 2, 4];
	print "Running on: $hostname ($ip)      Disk: $used/$size $pc\n";
}
######################################################################
#   Check for a touch screen event.				     #
######################################################################
my $EV_ABS = 0x03;
my $ABS_X = 0x00;
my $ABS_Y = 0x01;
my $ABS_MT_TRACKING_ID = 0x39;
my $scr_pix_width = 0;
my $scr_pix_height = 0;

my $ev_fh;
sub ev_check
{
	return -1 if !$opts{touchpad};

	if (!$ev_fh) {
		$ev_fh = new FileHandle("/dev/input/event0");
	}
	return -1 if !$ev_fh;

	if ($scr_pix_width == 0) {
		my $s = `$FindBin::RealBin/tools/fb -info`;
		chomp($s);
		$s =~ s/,.*$//;
		($scr_pix_width, $scr_pix_height) = split(/x/, $s);
	}

	my $bits = '';
	vec($bits, $ev_fh->fileno(), 1) = 1;

	my $t = 1;
	my $x = 0;
	my $y = 0;

	while (1) {
		my $rbits;
		my $n = select($rbits = $bits, undef, undef, $t);
		return 0 if !$n;

		$t = 0.1;

		my $s;
		last if !sysread($ev_fh, $s, 16);

		my ($secs, $usecs, $type, $code, $value) = unpack("LLSSS", $s);
#printf "type=0x%x code=0x%x value=0x%x\n", $type, $code, $value if $type == $EV_ABS;

		if ($type == $EV_ABS && $code == $ABS_X) {
		    	$x = $value;
			next;
		}
		if ($type == $EV_ABS && $code == $ABS_Y) {
		    	$y = $value;
			next;
		}

		if ($type == $EV_ABS && 
		    $code == $ABS_MT_TRACKING_ID &&
		    $value == 0xffff) {
		    	# Allow us to quickly see the other pages
			$page_sched{3}{last_time} = 0;
			$page_sched{4}{last_time} = 0;
			$stock_time = 0;
			$weather_time = 0;
#printf "touchscreen: ret=1\n";
			
			my $event = '';
			if ($x < $scr_pix_width / 2 && $y < $scr_pix_height/ 2) {
				$event = "top-left";
			} elsif ($x < $scr_pix_width / 2 && $y >= $scr_pix_height / 2) {
				$event = "bottom-left";
			} elsif ($x >= $scr_pix_width / 2 && $y < $scr_pix_height / 2) {
				$event = "top-right";
			} else {
				$event = "bottom-right";
			}

#			pr("[touchpad - $event ($x, $y) width=$scr_pix_width scr_height=$scr_pix_height]\n");
		    	return (1, $event, $x, $y);
		}
	}

	return 0;
}
my $output_fh;
sub pr
{
	my $str = join("", @_);

	if (!$output_fh) {
		$output_fh = new FileHandle(">>/tmp/rss_console.log");
		$output_fh->autoflush();
	}

	print $str;
	print $output_fh $str;
}
sub read_article
{	my $fname = shift;

	my $fh = new FileHandle($fname);
	my %info;

	while (<$fh>) {
		chomp;

		next if $_ eq '';
		my $lh = $_;
		$lh =~ s/=.*$//;
		if (length($lh) + 1 > length($_)) {
			print "$fname\n";
			print "length error: $_\n";
		}
		my $rh = substr($_, length($lh) + 1);
		$info{$lh} = $rh;

		if ($lh eq 'body') {
			while (<$fh>) {
				$info{body} .= $_;
			}
		}
	}
	return \%info;
}

######################################################################
#   Read  users  rss_config  file, for local customisation. This is  #
#   different from rss.cfg which enumerates the sites to poll/	     #
######################################################################
sub read_rss_config
{
	my $bin = "$FindBin::RealBin";
	my $fn;

	foreach my $f ("$ENV{HOME}/.rss/rss_config.cfg", "$bin/rss_config.cfg") {
		if (-f $f) {
			$fn = $f;
			last;
		}
	}
	if (!$fn) {
		print "no rss_config.cfg found\n";
		return;
	}

	print time_string() . "Reading: $fn\n";

	my $fh = new FileHandle($fn);
	return if !$fh;
	while (<$fh>) {
		chomp;
		$_ =~ s/#.*$//;
		next if $_ eq '';
		my ($lh, $rh) = split(/=/);
		if ($lh eq 'stocks') {
			push @{$opts{stocks}}, $rh;
		} else {
			$opts{$lh} = $rh;
		}
	}
}

sub reset_fb
{
	if (-f "/tmp/screendump") {
		system("cat /tmp/screendump > /dev/fb0");
		unlink("/tmp/screendump");
	}
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
ticker.pl -- tool to generate a personalized news headline and image viewer
Usage: ticker.pl

  ticker.pl works in conjunction with the RSS script to capture news 
  information.

Switches:

EOF

	exit(defined($ret) ? $ret : 1);
}

main();
0;

