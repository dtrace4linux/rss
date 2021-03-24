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

######################################################################
#   Array  allowing  us to control the order and frequency of pages  #
#   (per tick == minute)					     #
######################################################################
my %page_sched = (
	0  => { freq => 0,    title => "News topics"},
	1  => { freq => 60,   title => "Articles"},
	2  => { freq => 600,  title => "Calendar"},
	3  => { freq => 1750, title => "Reminder"},
	4  => { freq => 3600, title => "Hello"},
	5  => { freq => 4000, title => "Help"},
	6  => { freq => 600,  title => "Status" },

	7  => { freq => 1500, title => "News: front page"},
	8  => { freq => 1200, title => "Photos",},
	9  => { freq => 1200, title => "Images",},
	10 => { freq => 1200, title => "Album covers",},
	);
my $npages = scalar(keys(%page_sched));

#######################################################################
#   Command line switches.					      #
#######################################################################
my %opts;
my $columns;
my $rows;
my $cur_page = 0;
my $do_next_page = 0;
my $stock_time = 0;
my $weather_time = 0;
my $ev_fh;

sub clean_text
{	my $txt = shift;

	$txt =~ s/\xe2\x80./'/g;
	$txt =~ s/&#039;/'/g;
	$txt =~ s/&#39;/'/g;
	$txt =~ s/&#22;/"/g;
	$txt =~ s/&#27;/'/g;
	$txt =~ s/&#32;/ /g;
	$txt =~ s/&#34;/"/g;
	$txt =~ s/&#x27;/'/g;
	$txt =~ s/&amp;#x27;/'/g;
	$txt =~ s/&amp;#32;/ /g;
	$txt =~ s/&quot;/"/g;
	$txt =~ s/&amp;/\&/g;
	$txt =~ s/&amp;/\&/g;
	$txt =~ s/&quot;/"/g;
	$txt =~ s/&hellip;/.../g;
	$txt =~ s/&;#821[12];/-/g;
	$txt =~ s/\xe2\x80[\x98\x99]/'/g;

	return $txt;
}

sub display_image
{	my $fn = shift;
	my %opts = @_;

	# Check we are currently the active console.
	my $vt = `fgconsole 2>/dev/null`;
	chomp($vt) if defined($vt);
	if (defined($vt) && $vt ne '' && -x "$FindBin::RealBin/tools/fb") {
		if ($vt != 1) {
			print "[No image displayed - we lost the console: vt=$vt]\n";
			return;
		}
		# Save screen before
		if ( -e "/dev/fb0") {
			system("cat /dev/fb0 > /tmp/screendump");
		}

		if ($opts{multiimage}) {
			system("$FindBin::RealBin/tools/fb -effects -q \"$fn\" $opts{x} $opts{y}");
		} else {
			system("$FindBin::RealBin/tools/fb -effects -stretch -q \"$fn\"");
		}
		return;
	}

	if (-x "/usr/bin/img2txt" && $fn) {
		my $w = $columns - 1;
		my $h = $rows - 1;
		system("/usr/bin/img2txt -W $w -H $h \"$fn\"");
		return;
	}
	pr("(No images found to display)\n");
}

######################################################################
#   Select  a random collection of pictures and display them. We do  #
#   multi-image for news web pages.				     #
######################################################################
sub display_pictures
{	my $dir = shift;
	my $num = shift || 1;

	$opts{image_dir} =~ s/\$HOME/$ENV{HOME}/;
	$dir = "$opts{image_dir}/$dir";

	my @img;

	my $ctime1 = (stat($dir))[10];
	my $ctime2 = (stat("$dir/index.log"))[10];

	###############################################
	#   Cache   directory   so   we   dont  keep  #
	#   stat()'ing everything		      #
	###############################################
	if (!$ctime2 || $ctime1 > $ctime2 + 5) {
		index_dir($dir);
	}
	my $fh = new FileHandle("$dir/index.log");
	while (<$fh>) {
		chomp;
		my $f = $_;
		next if $f =~ /.old$/;
		next if $f !~ /jpg|jpeg|png/i;
		push @img, $f;
	}

	if (@img == 0) {
		pr(time_string() . "[No images in $dir]\n");
		return;
	}

	for (my $i = 0; $i < $num; $i++) {
		my $n = rand(@img);
		($img[$i], $img[$n]) = ($img[$n], $img[$i]);
	}

	my %iopts = { x => 0, y => 0};
	$iopts{multimage} = 1 if $num > 1;
	for (my $i = 0; $i < $num; $i++) {
		pr(time_string() . "[img: $img[$i]]\n");

		display_image($img[$i], %iopts);
		last if $num == 1;
		sleep(5);
		$iopts{x} += 600; # HACK: should be by img width
	}
}

sub do_status_line
{
	return if $opts{notime};

	if (defined($opts{ppid}) && ! -d "/proc/$opts{ppid}") {
		print time_string() . "[$$] ticker: parent $opts{ppid} terminated\n";
		exit(0);
	}

	my $fh = new FileHandle("/proc/loadavg");
	my $avg = <$fh>;
	$avg =~ s/ .*//;
	my $s = sprintf "\033[1;%dH", $columns - 20;

	my $c;
	if ($avg >= 1) {
		$c = "\033[33m";
	} else {
		$c = "\033[1;33m";
	}

	$s .= strftime("$c Time: %H:%M:%S ", localtime());
#	if (! -w "/dev/input/event0") {
#		$s .= sprintf "\033[2;%dH\033[41;37m /dev/input/event0 perms", $columns - 30;
#	}
#	if (! -w "/dev/fb0") {
#		$s .= sprintf "\033[3;%dH\033[41;37m /dev/fb0 perms         ", $columns - 30;
#	}

	my $row = 2;
	###############################################
	#   Get network status.			      #
	###############################################
	$fh = new FileHandle("/tmp/rss_status.log");
	my %info;
	my %iface;
	my $if_string = '';
	if ($fh) {
		while (<$fh>) {
			chomp;
			my ($lh, $rh) = split(/=/);
			$info{$lh} = $rh;
			if ($lh =~ /^iface_(.*)/ && $1 ne 'lo') {
				my $nm = $1;
				$rh =~ s/^.*,//;
				$iface{$nm}{ip} = $rh;
			}
			if ($lh =~ /^ssid_(.*)/) {
				$iface{$1}{ssid} = $rh;
			}
		}
	}

	foreach my $i (sort(keys(%iface))) {
		$if_string .= " " if $if_string;
		$if_string .= $iface{$i}{ip};
		$if_string .= "/$iface{$i}{ssid}" if $iface{$i}{ssid};
	}

	$s .= sprintf("\033[$row;%dH", $columns - 20);
	if (!$info{gw}) {
		$s .= sprintf("\033[1;41;37m Net ");
	} else {
		$s .= sprintf("\033[1;42;40m Net ");
	}
	$row++;
	if (!$info{ping}) {
		$s .= sprintf("\033[1;41;37m Ping ");
	} else {
		$s .= sprintf("\033[1;42;40m Ping ");
	}
	$row++;
	if (!defined($ev_fh)) {
		$s .= sprintf("\033[1;41;37m Touch ");
	}

	$s .= sprintf("\033[1H$if_string ");

	$s .= sprintf("\033[37;40m\033[%dH", $rows);
	print $s;
}

######################################################################
#   Scan  the  environment  for  useful  stuff,  especially  if the  #
#   network is down.						     #
######################################################################
sub do_status
{
	my $ppid = $$;

	return if fork();

	my $last_stock = 0;
	my %stats;
	my %old_stats;
	my $fh;

	while (1) {
		exit(0) if ! -d "/proc/$ppid";

		###############################################
		#   Get interface state.		      #
		###############################################
		$fh = new FileHandle("ifconfig |");
		my $iface;
		my $up = 0;
		while (<$fh>) {
			chomp;
			if (/^(.*): flags=/) {
				$iface = $1;
				$stats{"iface_$iface"} = "0,";
			}
			if (/flags=.*UP/) {
				$up = 1;
			} elsif (/flags=/) {
				$up = 0;
			}
			if (/inet ([^\s]*) /) {
				$stats{"iface_$iface"} = "$up,$1";
			}
		}

		###############################################
		#   Get the gateway to ping		      #
		###############################################
		$fh = new FileHandle("route -n |");
		$stats{gw} = '';
		while (<$fh>) {
			chomp;
			next if !/^\d/;
			my $s = (split(" ", $_))[1];
			next if $s eq '0.0.0.0';
			$stats{gw} = $s;
		}
		$fh->close();

		$stats{ping} = 0;
		if ($stats{gw}) {
			my $s = system("ping -c 1 -W 2 $stats{gw} >/dev/null");
			$stats{ping} = $? ? 0 : 1;
		}

		$fh = new FileHandle("iwconfig |");
		while (<$fh>) {
			chomp;
			if (/^([^ ]*) .*ESSID:"([^"]*)"/) {
				$stats{"ssid_$1"} = $2;
			}
		}

		###############################################
		#   See if anything changed		      #
		###############################################
		my $chg = 0;
		foreach my $s (sort(keys(%stats))) {
			$chg = 1 if !defined($old_stats{$s}) || $old_stats{$s} ne $stats{$s};
		}

		###############################################
		#   Keep status, and audit trail.	      #
		###############################################
		if ($chg) {
			my $ofh = new FileHandle(">>/tmp/rss_status_history.log");
			foreach my $s (sort(keys(%stats))) {
				print $ofh time_string() . "$s=$stats{$s}\n";
			}
			$ofh->close();

			$ofh = new FileHandle(">/tmp/rss_status.log");
			foreach my $s (sort(keys(%stats))) {
				print $ofh "$s=$stats{$s}\n";
			}
			$ofh->close();
		}

		%old_stats = %stats;

		if ($stats{gw} && time() > $last_stock + $opts{stock_time}) {
			my $cmd = "$FindBin::RealBin/scripts/stock.pl " .
				"-cols $columns -update -random -o $ENV{HOME}/.rss/ticker/stock.log " .
				join(" ", @{$opts{stocks}});
			my $str = `$cmd`;
		}

		sleep(5);
	}
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
		print $lns[$pos + $i] if $lns[$pos + $i];
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
		my $cmd = "$FindBin::RealBin/scripts/stock.pl " .
			"-cols $columns -random -o $ENV{HOME}/.rss/ticker/stock.log " .
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
		'debug',
		'help',
		'page=s',
		'ppid=s',
		);

#my $a = read_article("$ENV{HOME}/.rss/articles/art0005921");
#print "t=", clean_text($a->{title}), "\n";
#print clean_text($a->{body});
#exit;

	usage(0) if $opts{help};

	$| = 1;

	my $pid = $$;
	if (!defined($opts{page})) {
		if (fork() == 0) {
			exec "$FindBin::RealBin/scripts/get-web.pl -ppid $pid >/tmp/get-web.log";
			exit(0);
		}
	}

	print "\033[37m";

	get_tty_size();

	read_rss_config();

	do_status();

	do_ticker();
}
######################################################################
#   Generate  periodic/random  headline.  We  want a console output  #
#   (plain  text)  and  HTML,  which  can  offer  more features. In  #
#   addition,  for  console, we may support touch based input. (Not  #
#   currently implemented).					     #
######################################################################

sub sched_page
{	my $txt = shift;

	return 0 if $txt;

	if ($do_next_page) {
		$do_next_page = 0;
		return $cur_page;
	}

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

		my $do_weather = 1;
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
			do_page3_reminder();
		} elsif ($page == 4) {
			do_page4_hello();
		} elsif ($page == 5) {
			do_page5_help();
		} elsif ($page == 6) {
			do_page6_status();
		} elsif ($page == 7 && !$opts{enable_news_scraping}) {
			do_page7_web();
			$do_weather = 0;
		} elsif ($page == 8) {
			do_page8_photos();
			$do_weather = 0;
		} elsif ($page == 9) {
			do_page9_images();
			$do_weather = 0;
		} elsif ($page == 10) {
			do_page10_album();
			$do_weather = 0;
		}

		if ($do_weather) {
			do_weather();
			do_stocks();
		}

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
			
			if ($action eq 'bottom-left') {
				do_history(1);
			}

			if ($action eq 'bottom-right') {
				$cur_page = ($cur_page + 1) % scalar(keys(%page_sched));
				$do_next_page = 1;
			}

			if ($hist_mode == 0) {
				$ticks++;
				last;
			}

		get_tty_size();
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
	my $str = '';
	foreach my $ln (split("\n", $txt)) {
		$ln =~ s/^\s+//;
		next if $last_ln eq '' && $ln eq '';
		###############################################
		#   Print out the line, but word wrap it.     #
		###############################################
		foreach my $wd (split(" ", $ln)) {
			if ($col + 1 + length($wd) >= $columns) {
				$str .= "\n";
				$row++;
				$col = 0;
			}
			if ($col) {
				$str .= " ";
				$col++;
			}
			$str .= $wd;
			$col += length($wd);
		}
		$last_ln = $ln;
	}
	$str .= "\n" if $col;
	pr($str);
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
		$tstr = `toilet -t $opt $t`;
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

sub do_page3_reminder
{
	my $path = $FindBin::RealBin;
	my $fh = new FileHandle("$path/reminder.pl $path/reminders.txt |");
	while (<$fh>) {
		pr($_);
	}
}

sub do_page4_hello
{
	my $fh = new FileHandle("$FindBin::RealBin/rss-hello.txt");
	my @msg;
	my $txt = '';
	while (<$fh>) {
		chomp;
		if ($_ =~ /^:/) {
			push @msg, substr($_, 1);
		} else {
			$txt .= "$_\n";
		}
	}
	my $m = $msg[rand(scalar(@msg))];
	system("toilet -t --gay $m");
	print $txt;

}

my $hostname = `hostname`;
sub do_page5_help
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

	###############################################
	#   We  want  the IP addr of the interfaces,  #
	#   but  we  cant  assume  the  IP  for  our  #
	#   hostname  is  an actual external address  #
	#   (its usually a localhost address).	      #
	###############################################
	$fh = new FileHandle("ifconfig |");
	my $up = 0;
	my $interface;
	my $ip = '';
	while (<$fh>) {
		chomp;
		if (/^(.*): flags/) {
			$interface = $1;
			$up = 0;
			if (/\<UP/) {
				$up = 1;
			}
			next;
		}
		if (/inet ([^ ]*) /) {
			my $p = $1;
			$ip .= " " if $ip && $ip !~ /^127/;
			$ip .= $p;
		}
	}
	my $disk = `df -h /`;
	$disk = (split("\n", $disk))[1];
	my ($size, $used, $pc) = (split(" ", $disk))[1, 2, 4];
	print "Running on: $hostname ($ip)      Disk: $used/$size $pc\n";
}

sub do_page6_status
{
	my %d = (
		album => "Album covers",
		images => "Stock photos",
		photos => "Personal photos",
		news => "Web Images",
		);

	$opts{image_dir} =~ s/\$HOME/$ENV{HOME}/;

	foreach my $d (sort(keys(%d))) {
		index_dir("$opts{image_dir}/$d");

		my $fh = new FileHandle("$opts{image_dir}/$d/index.log");
		next if !$fh;
		my $n = 0;
		while (<$fh>) {
			$n++ if $_ =~ /jpg|jpeg|png/i;
		}
		pr(sprintf("%-18s: %4d\n", $d{$d}, $n));

	}

	my $disk = `df -h /`;
	$disk = (split("\n", $disk))[1];
	my ($size, $used, $pc) = (split(" ", $disk))[1, 2, 4];
	$pc =~ s/%//;

	my $d = " " x (60 * ($pc / 100.));
	my $d1 = " " x (60 - length($d));

	pr("Disk Usage: [\033[41m$d\033[40m$d1] $pc%\n");

	###############################################
	#   We  want  the IP addr of the interfaces,  #
	#   but  we  cant  assume  the  IP  for  our  #
	#   hostname  is  an actual external address  #
	#   (its usually a localhost address).	      #
	###############################################
	my $fh = new FileHandle("ifconfig |");
	my %iface;
	my $up = 0;
	my $interface;
	my $ip = '';
	while (<$fh>) {
		chomp;
		if (/^(.*): flags/) {
			$interface = $1;
			$iface{$interface}{up} = 0;
			if (/\<UP/) {
				$iface{$interface}{up} = 1;
			}
			next;
		}
		if (/inet ([^ ]*) /) {
			$iface{$interface}{ip} = $1;
			$ip .= " " if $ip && $ip !~ /^127/;
		}
	}

	my $s = "Network: ";
	foreach my $n (sort(keys(%iface))) {
		next if $n eq 'lo';
		$s .= sprintf( " $n: %s %s ",
			$iface{$n}{up} ? "\033[33mUp\033[37m" : 
				"\033[31mDOWN\033[37m",
			$iface{$n}{ip} || "(noip)");
	}
	pr("$s\n");


}

sub do_page7_web
{
	display_pictures("news", 2);
}

sub do_page8_photos
{
	display_pictures("photos");
}

######################################################################
#   Display a random image.					     #
######################################################################
sub do_page9_images
{
	display_pictures("images");
}

sub do_page10_album
{
	display_pictures("album");
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
my $is_64bit;
my $ev_device = "/dev/input/event0";

sub ev_check
{
	return -1 if !$opts{touchpad};

	###############################################
	#   Ubuntu 64b edition will have a different  #
	#   input_event structure size.		      #
	###############################################
	if (!defined($is_64bit)) {
		my $arch = `uname -m`;
		chomp($arch);
		$is_64bit = $arch =~ /64/;
		# Dirty to assume this.
		if ($is_64bit) {
#			$ev_device = "/dev/input/event1";
		}
	}

	# On Ubuntu, sometimes the touchpad disappears
	my $mtime = (stat($ev_device))[9];
	$ev_fh = undef if !defined($mtime);
	if (!$ev_fh) {
		$ev_fh = new FileHandle($ev_device);
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
	vec($bits, STDIN->fileno(), 1) = 1;

	my $t = 1;
	my $x = 0;
	my $y = 0;

	while (1) {
		my $rbits;
		my $n = select($rbits = $bits, undef, undef, $t);
		return 0 if !$n;

		my $s;
		if (vec($rbits, STDIN->fileno(), 1)) {
			if (sysread(STDIN, $s, 1)) {
				return (1, "enter", 0, 0);
			}
			next;
		}

		$t = 0.1;

		last if !sysread($ev_fh, $s, $is_64bit ? 24 : 16);

		my ($secs, $usecs, $type, $code, $value);

		if ($is_64bit) {
			($secs, $usecs, $type, $code, $value) = unpack("qqSSS", $s);
		} else {
			($secs, $usecs, $type, $code, $value) = unpack("LLSSS", $s);
		}
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

			if ($opts{debug}) {
				pr("[touchpad - $event ($x, $y) width=$scr_pix_width scr_height=$scr_pix_height]\n");
			}
		    	return (1, $event, $x, $y);
		}
	}

	return 0;
}

sub index_dir
{	my $dir = shift;

	return if ! -d $dir;

	system("find $dir -follow -type f | sort > $dir/index.log");
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

