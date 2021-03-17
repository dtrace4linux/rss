#! /usr/bin/perl

# $Header:$

# 20140217 Fix CDATA processing for Risks
# 20140217 Strip \r\n from title.
# 20140217 Add gzip compression - 2.8x compression
# 20140221 Add https: support for HackerNews
# 20140224 Fix https 
# 20140224 Add 'Next-dl' to the page.
# 20140304 Fix HackerNews download
# 20140304 Dont kill myself on a re-exec
# 20140304 Fix "status" file output.
# 20140304 Add "/" request support.
# 20140305 Add 404 support. Silly me.
# 20140305 Add inquirer/arstecnica.
# 20140315 Add non-blocking writes.
# 20140317 Add metrics per site.
# 20140318 Avoid infinite cpu use if we hit an error'ed connection.
# 20140319 Add art_hash limit of 10,000
# 20140406 Ignore 'Win' from HotUkDeals.
# 20140406 Add /q page and use/store cookies to do T-4h.
# 20140521 Avoid hanging on an accept/sysread with no timeout.
# 20140907 Better unicode handling; centralise the conversions.
# 20150205 Add disabled support
# 20150309 Keep old articles; fix rquote/lquote
# 20150501 Update to www.crispeditor.co.uk
# 20160515 Improve hackernews collection.
# 20160604 Break up hackernews pages.
# 20160609 Add article links to HN pages and fix the relative links.

use strict;
use warnings;

use File::Basename;
use FileHandle;
use Getopt::Long;
use IO::File;
use POSIX;
use FindBin;

use IO::Socket;
use Compress::Zlib;

use lib "$FindBin::RealBin/";
use Utils;

my %sites;
my %history = (
	req => 0,
	googlebot => 0,
	);

#######################################################################
#   Command line switches.					      #
#######################################################################
my %opts = (
	port => 3000,
	size => 250,
	num => 2000,
	art_history => 10000,
	sleep => 60,
	stock_time => 1000,
	);

my $a_id = 0;
my %art_hash;
my @art_list;
my $prog;
my $prog_mtime = (stat($0))[9];
my $rss_cfg;
my $err = 0;
my $target_time = 0;
my %cookies;
my $next_scan = '';
my @argv = @ARGV;
my @writers;
my $wbits = '';
my $curl_msg = '';

my $copyright_year = "2015-2021";

my $javascript = <<EOF;
<!-- rss.pl, author: Paul.D.Fox (crispeditor-at-gmail-com). (c) $copyright_year -->
<script type='text/javascript'>
function toggle(id) {
	var e = document.getElementById(id);
	var e1 = document.getElementById(id + 'p');
	if (e.style.display == 'block') {
		e.style.display = 'none';
		e1.style.background = '#d0d0d0';
	} else {
		e.style.display = 'block';
		e1.style.background = '#00ff00';
	}
}
</script>
EOF

######################################################################
#   CSS stylesheet.						     #
######################################################################
my $css = <<EOF;
<style type='text/css'>
td, body, mp, m, p {
        border-radius: 20px ;
        color: #000000 ;
        background-color: #ebeced ;
	zzwidth: 330;
	max-width: 100%;
        font-family: Verdana, Helvetica, Arial, sans-serif ;
}
p.fn {
	font-size: 11;
	font-family: "Lucida Console", Monaco, monospace;
}
#aa
{
    background:#ebeced;
    border: none;
    border-top: 1px solid #d0d2d5;
    border-radius: 0 0 4px 4px;
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.75);
    margin: 5px 0 -20px -20px;  padding: 18px 20px;
    width: 100%;
}

px {
  border:1px solid #ccc;
  padding:6px 12px;
  text-align:left;
  vertical-align:top;
        font-family: Helvetica, Arial, sans-serif ;
  background-color:inherit;
}
</style>
EOF

######################################################################
#   Help text.							     #
######################################################################
my $help_txt = <<EOF;
<table width=400>
<tr><td>
This web site is an RSS feed aggregator, but designed to be
as frugal as possible - ideal for mobile phones and low data
limits. There are two types of pages - 'p' which are 250k/90k (raw/compressed)
and 'q'. The 'q' pages uses a simple cookie to track the last time
you made a request, and give you everything +4h from that request.

<p>
The 'q' pages avoid repeatedly giving you news items you may have read.

The pages are sent as gzipped encoded pages which reduces the data size
enormously.

<p>
If you have suggestions for sites to add to the feed, or feature
enhancements, feel free to contact CRiSP.Editor at gmail.com, or 
<a href="mailto:Crisp.Editor\@gmail.com?Subject=RSS%20Feed%20Suggestions" target="_top">click here</a>

<p>
The following summarises the pages available:
</td></table>

<table width=400 border=1>
<tr>
<td valign=top><a href='/'>p</a></td><td>
The first page of headlines - whatever fits into 250k uncompressed. You
can omit the 'p'. Older pages are available as p1.html, p2.html, ... or
use the "Next" button at the top of the page.
</td>
<tr>
<td valign=top><a href='/q'>q</a></td><td>Retrieves items from the last request, minus 4h, so that you
wont get a blank page if you do quick/successive requests.</td>
<tr>
<td valign=top><a href='/status'>status</a></td><td>Some metrics for the author to look at. These
include counts of requests per day, and when the next requests are due.</td>
</table>

<p>
If you like this feed, feel free to donate:

<form name="_xclick" action="https://www.paypal.com/cgi-bin/webscr" method="post">
	<input type="hidden" name="cmd" value="_xclick">
	<input type="hidden" name="business" value="CrispEditor\@gmail.com">
	<input type="hidden" name="item_name" value="CRiSP">
	<input type="hidden" name="currency_code" value="GBP">
	<input type="hidden" name="amount" value="5.00">
	<b>&nbsp;&nbsp;&nbsp;RSS</b>
	<input type="image" src="http://www.paypal.com/en_US/i/btn/btn_donate_LG.gif" border="0" name="submit" alt="Make payments with PayPal - it's fast, free and secure!">
</form> 

EOF


sub convert_chars
{	my $str = shift;

	$str =~ s/<div class='mf-viral'.*$//;
	$str =~ s/&quot;/"/g;
	$str =~ s/&amp;#215;/x/g;
	$str =~ s/&#039;/'/g;
	$str =~ s/&amp;shy;/-/g;
	$str =~ s/<div class='mf-viral'.*$//;
	$str =~ s/<script/<Xscript/g;
	$str =~ s/<code/<Xcode/g;

	###############################################
	#   Unicode.				      #
	###############################################
	$str =~ s/\xe2\x99/ /g;
	$str =~ s/\xe2\x80\x93/-/g;
	$str =~ s/\xe2\x80\x99/'/g;
	$str =~ s/\xe2\x80\xa6/.../g;
	$str =~ s/\xc2\xa0\x20/ /g;

	$str =~ s/&[lr]quote;/"/g;
	$str =~ s/&gt;/>/g;
	$str =~ s/&lt;/</g;
	$str =~ s/&amp;yen;/Y/g;
	$str =~ s/&amp;#8216;/'/g;
	$str =~ s/&amp;hellip;/.../g;
	$str =~ s/&amp;lang;/L</g;
	$str =~ s/&amp;rang;/>/g;
	$str =~ s/&amp;amp;/&/g;
	$str =~ s/<!--.*-->//g;
	$str =~ s/<\/p>//g;
	$str =~ s/\x80//g;
	$str =~ s/\r//g;
	$str =~ s/\t/ /g;
	$str =~ s/ +/ /g;
	$str =~ s/&amp;#039;/'/g;
	$str =~ s/&amp;#237;/í/g;
	$str =~ s/&#237;/í/g;
	return $str;
}
######################################################################
#   Dont let disk fill up.					     #
######################################################################
sub do_clean
{
	my @lst = reverse(glob("$opts{dir}/articles/*"));

	my $dirty = 0;
	my $today = strftime("$opts{dir}/archive/%Y%m%d", localtime());
	for (my $i = $opts{num}; $i < @lst; $i++) {
		my $a = basename($lst[$i]);
		$a =~ s/^art//;
		$a =~ s/^0*//;
		$a = 0 if $a eq '';

		$dirty = 1;
		my $target = "$today/" . basename($lst[$i]);
		if ( ! -d $today) {
			if (!mkdir($today, 0755)) {
				print "error:mkdir($today, 0755) - $!\n";
			}
		}
		if (!rename($lst[$i], $target)) {
			print time_string() . "Failed to rename: $lst[$i] -> $target - $!\n";
		}
	}

	if (@art_list > $opts{art_history}) {
		my $n = 0;
		for (my $i = $opts{art_history}; $i < @art_list; $i++) {
			my $id = $art_list[$i]->{id};
			$n++;
			delete($art_hash{$id});
			}
		print time_string() . "Cleaned $n articles\n";
		@art_list = @art_list[0..$opts{art_history}-1];
		save_art_hash() if $dirty;
	}
}

######################################################################
#   Generate the output page.					     #
######################################################################
sub do_output
{
	my @lst = reverse(glob("$opts{dir}/articles/*"));

	my $i = 0;
	my $pg = 0;
	my $size = 0;
	my @secs;

	for ( ; $i < @lst; $pg++) {
		my $html = '';
		my $txt = '';

		my $cont = '<table>';

		$html .= $javascript;

		my $site = '';
		my $last_site = '';
		my $ent = 0;
		my $last_ent = 0;
		my $sec1 = '';
		my $sec2 = '';
		my $hide = '';

		my %info;
		for (; $i < scalar(@lst); $i++) {
			my $fname = $lst[$i];
			#print "Output: $fname\n";

#print "$fname $size sec1=", length($sec1), " sec2=", length($sec2), "\n";
			%info = ();
			my $fh = new FileHandle($fname);
			my $mtime = (stat($fname))[9];
			my $tstr = strftime("%d %a %H:%M", localtime($mtime));
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
					foreach my $t (qw/body title/) {
						$info{$t} = convert_chars($info{$t});
					}
					last;
				}
			}

			###############################################
			#   Generate article.			      #
			###############################################
			if (!defined($info{site})) {
				print "missing info{site} for $fname\n";
				unlink($fname);
				next;
			}
			if (!defined($sites{$info{site}})) {
#				print "ignore: $fname ($info{site}\n";
				next;
			}
	#print "$info{site} vs $site\n";
			if ($info{site} ne $last_site) {
				if ($last_site) {
					my $n = $ent - $last_ent;
					my $m = '';
					#$m = sprintf(" %dK", (length($sec1) + length($sec2)) / 1024);
					$sec1 =~ s/\[XX]/[$n$m]/;
					$size += length($sec1) + length($sec2);
					push @secs, $sec1 . $sec2;
	#print "#$last_ent $info{name}\n";
				}
				$last_site = $info{site};
				$site = $info{site};

				$sec1 = '';
				$sec2 = '';
				$sec1 .= "$hide</pre></strong></b></i></ul></div>\n";
				$sec1 .= "<br>\n";
				$sec1 .= "<div id='a${ent}p'>";
				$sec1 .= "&nbsp;&nbsp;&nbsp;&nbsp;";
				$sec1 .= "<a href='#' onclick=\"toggle('a$ent'); return false;\">Show</a> ";
				$sec1 .= "$tstr\n";
				$sec1 .= "<a name='$ent'>";
				$sec1 .= "<a href='" . ($sites{$site}{site} || $site) . "'>";
				$sec1 .= "$info{name}</a> [XX]";
				$sec1 .= "</div>\n";
				$hide = "<br><span style='background-color:#ff9040;'><a href='#' onclick=\"toggle('a$ent'); return false;\">Hide</a></span>";
				$sec1 .= "<div id='a$ent' style=\"display: none;\">";
				$last_ent = $ent;
			}
			$sec2 .= "<p>$info{date3} ";
			$sec2 .= "<a href='$info{link}'><b>$info{title}</b></a><br>";
			$sec2 .= "$info{body}";

			$txt .= "$info{date3} Title: $info{title}\n";
			$txt .= "   $info{body}\n";
			$txt .= "   $info{link}\n";

			if ($size + length($sec1) + length($sec2) > $opts{size} * 1024) {
#print "bump to next $size sec1=", length($sec1), " sec2=", length($sec2), " fname=$fname\n";
				$sec2 .= "<p><b>results truncated...\n";
				last;
			}
			$ent++;
		}

		###############################################
		#   Generate output file.		      #
		###############################################
		my $ofname = $pg == 0 ? "p" : "p$pg";
		my $fh = new FileHandle(">$opts{dir}/$ofname.html");
#		print $fh $cont;
		my $s = $html;
		$s .= $_ foreach @secs;
		printf $fh strftime("Generated %d %a %H:%M", localtime()) . " Size: %dK", 
			length($s) / 1024;
		print $fh " Articles: $ent ";
		if ($pg) {
			print $fh "&nbsp;&nbsp;&nbsp;<a href='p" . ($pg == 1 ? "" : $pg-1) . ".html'>Prev</a>";
		}
		if ($i < @lst) {
			print $fh "&nbsp;&nbsp;&nbsp;<a href='p" . ($pg+1) . ".html'>Next</a>";
		}
		print $fh "<hr>";
		print $fh <<EOF;
<p>
If you want to see or try CRiSP, visit 
<a href='http://www.crispeditor.co.uk'>http://www.crispeditor.co.uk</a>
and try one of the longest established and functional editors on
the web! Or subscribe to <a href='http://crtags.blogspot.com'>http://crtags.blogspot.com</a> for 
a blog on technical articles and joy of computing (sometimes!).
<p>
EOF
		print $fh "<hr>";
		print $fh $html;
		print $fh $_ foreach @secs;

		print $fh "</div><hr>rss.pl, Author: Paul Fox $copyright_year crispeditor-at-gmail-com\n";
		$fh = new FileHandle(">$opts{dir}/$ofname.txt");
		print $fh $txt;

		print time_string() . "$ofname.html: ", length($html) . " articles: $ent\n";

		###############################################
		#   Post processing.			      #
		###############################################
		$size = 0;
		@secs = ();
	}

	gen_status();
}

######################################################################
#   Parse the html/xml files into articles.			     #
######################################################################
sub do_parse
{
	my @stack;

	my $uri;
	foreach my $fname (glob("$ENV{HOME}/.rss/sites/*")) {

		my $site = basename($fname);
		if (!defined($sites{$site})) {
			unlink($fname);
			next;
		}

		my %info;

		my $fh = new FileHandle($fname);
		$uri = <$fh>;
		chomp($uri);
		#print "$fname: ($uri)\n";
		my $str = '';
		while (<$fh>) {
			$str .= $_;
		}

		my $sec = '';
		my $num_art = 0;
		my $tot_art = 0;

		for (my $i = 0; $i < length($str); $i++) {
			my $ch = substr($str, $i, 1);
			if ($ch ne '<') {
				$info{$sec} .= $ch;
				next;
			}

			$ch = substr($str, ++$i, 1);
			if ($ch eq '!') {
				for ($i++; $i < length($str); $i++) {
					if (substr($str, $i, 3) eq ']]>') {
						$i += 2;
						last;
					}
					$info{$sec} .= substr($str, $i, 1);
				}
				next;
			}

			my $ch0 = $ch;
			$sec = '';
			for (; $i < length($str); $i++) {
				my $ch = substr($str, $i, 1);
				last if $ch eq '>';
				$sec .= $ch;
				if ($sec eq '[CDATA[') {
					$sec = '';
					for ($i++; $i < length($str); $i++) {
						$ch = substr($str, $i, 1);
						$sec .= $ch;
						last if $sec =~ /]]$/;
					}
				}
			}
#print "sec=$sec\n";

			###############################################
			#   www.register.co.uk			      #
			###############################################
			if ($sec =~ /link.*href="([^"]*)"/) {
				$info{link} = $1;
				$sec = '';
				next;
			}

			$sec =~ s/ .*$//;
			if ($sec eq 'item' || $sec eq 'entry') {
				%info = ();
				next;
			}
#print "yes - '$sec'\n";
			$sec =~ s/ .*$//;
			next if $sec !~ /\/(item|entry)$/;

			###############################################
			#   Check for HotUKDeals categories.	      #
			###############################################
			next if $sites{$site}{category} &&
				$info{category} &&
			        $info{category} !~ /$sites{$site}{category}/;

			$info{title} ||= "NO-TITLE";
			$info{title} =~ s/\t\t/ /g;
			$info{title} =~ s/\[CDATA\[//;
			if ($sites{$site}{ignore_title} &&
				$info{title} =~ /$sites{$site}{ignore_title}/i) {
#				print time_string() . "Ignore_title: $info{title}\n";
				next;
			}
			$info{description} = $info{summary} if $info{summary};
			$info{description} = $info{content} if $info{content};

#print "content=", substr($info{content}, 0, 100), "\n" if $info{content};
#print "link=$info{link}\n" if $info{content};
			if (!defined($info{description})) {
				print time_string() . "ERROR(parse): $fname - no description\n";
				next;
			}

			$info{description} =~ s/\[CDATA\[//;
			$info{description} =~ s/<img[^>]*>//;
			$info{description} =~ s/&lt;/</g;
			$info{description} =~ s/&gt;/>/g;
			$info{description} =~ s/&euro;/e/g;
			$info{description} =~ s/&amp;#8217;/'/g;
			$info{description} =~ s/&amp;#8220;/'/g;
			$info{description} =~ s/&amp;#8221;/'/g;
			$info{description} =~ s/&amp;nbsp;/ /g;
			$info{description} =~ s/\xe2\x80\x93/-/g;
			$info{description} =~ s/&mdash;/-/g;
			$info{description} =~ s/&ndash;/-/g;
			$info{description} =~ s/&quot;/"/g;
			$info{description} =~ s/&amp;rsquo;/'/g;
			$info{description} =~ s/&amp;mdash;/-/g;
			$info{description} =~ s/<img [^>]*>//g;
			$info{description} =~ s/<iframe [^>]*>//g;
			$info{description} =~ s/ at Slashdot\.//g;
			$info{description} =~ s/&amp;lt;/</g;
			$info{description} =~ s/<div class='mf-viral'.*$//;
			$info{description} =~ s/&amp;gt;/>/g;
			$info{description} =~ s/http:\/\/twitter[^"]*"/"/;
			$info{description} =~ s/http:\/\/www.facebook[^"]*"/"/;
			$info{description} =~ s/http:\/\/plus.google[^"]*"/"/;

			###############################################
			#   Slashdot...				      #
			###############################################
			$info{description} =~ s/<div class="share_submission".*$//;

			###############################################
			#   HotUKDeals.				      #
			###############################################
			$info{description} =~ s/^Found by .*<a[^<]*<\/a><br\/>//;

			###############################################
			#   Get date.				      #
			###############################################
			my $d = $info{pubDate};
			if ($d) {
				$d =~ s/^.* (\d\d:\d\d):.*$/$1/;
			} elsif ($info{"dc:date"}) {
				$d = $info{"dc:date"};
				$d =~ s/^.*T//;
			} elsif ($info{"updated"}) {
				$d = $info{"updated"};
				$d =~ s/^.*T//;
			} else {
				$d = "--";
			}
			$d =~ s/Z//;

			###############################################
			#   Compile to standard form.		      #
			###############################################

			my %art;
			$art{title} = $info{title};
			$art{link} = $info{link} || $info{uri};
			$art{link} =~ s/^\s+//;
			$art{link} =~ s/\s+$//;
			$art{link} =~ s/&#x2F;/\//g;
#print "cat=$info{category}  -- $sites{$site}{category}\n" if $site eq 'HotUKDeals';
#$art{title} .= "cat=" . ($info{category} || '');
			$art{text} = $info{description};
#$art{text} .= "cat=" . ($info{category} || '');
			$art{id} = $a_id;
			$art{src} = $site;
			$art{name} = $sites{$uri}{name};
			$art{site} = $uri;
			%info = ();

			$art{title} =~ s/[\r\n]//g;
			$art{link} =~ s/[\r\n]//g;

			###############################################
			#   Skip if we have seen this before.	      #
			###############################################
#if (defined($art_hash{$art{link}})) {
#print "dup art $art{link}\n";
#}
			$tot_art++;
			next if defined($art_hash{$art{link}});
			$num_art++;

			$a_id++;

			my $fname = sprintf("$opts{dir}/articles/art%07d", $a_id);
			my $fh = new FileHandle(">$fname");
			die "Cannot create $fname - $!" if !$fh;

			print $fh "id=$art{id}\n";
			print $fh "site=$art{site}\n";
			print $fh "date1=" . time() . "\n";
			print $fh "date2=" . strftime("%Y%m%d %H:%M:%S", localtime()) . "\n";
			print $fh "date3=" . strftime("%H:%M", localtime()) . "\n";
			print $fh "date4=$d\n";
			print $fh "link=$art{link}\n";
			print $fh "name=", $art{name} || "", "\n";
			print $fh "title=$art{title}\n";
			print $fh "body=\n";
			print $fh $art{text};

			$art_hash{$art{link}} = $art{id};
			my $art_info = {
				link => $art{link},
				id => $art{id},
				time => time()
				};
			unshift @art_list, $art_info;
		}

		$sites{$site}{tot_art} += $tot_art;
		$sites{$site}{tot_new} += $num_art;
		$sites{$site}{art_new} = $num_art;
		$sites{$site}{art_tot} = $tot_art;
		print "$site: $num_art/$tot_art\n";
	}

	my $fname = "$opts{dir}/seq_no";
	my $fh = new FileHandle(">" . $fname);
	print $fh "$a_id\n";
	$fh->close();

	save_art_hash();
}


sub gen_status
{
	###############################################
	#   Generate status page.		      #
	###############################################
	my $fh = new FileHandle(">$opts{dir}/status.html");
	if ($fh) {
		print $fh $javascript;
		print $fh "<p>\n";
		print $fh "<a href='p.html'>Page 1</a> &nbsp;";
		print $fh "b=", $history{req404} || 0, " ";
		print $fh "c=", $history{cookie} || 0, " g=$history{googlebot} r=$history{req}<br>\n";
		foreach my $k (reverse(sort(keys(%history)))) {
			next if $k !~ /^s2/;
			printf $fh "%s=%s<br>\n",
				substr($k, 1), $history{$k};
		}
	}
	save_history();
}

######################################################################
#   Simple cookie code.						     #
######################################################################
sub get_cookie
{
	my $c = $history{cookie}++;
	$c = "simple-$c";
	return $c;
}

######################################################################
#   Get all the hackernews comments.				     #
######################################################################
sub get_hackernews
{
	my $mtime = (stat("$opts{dir}/hackernews/index.html"))[9];
	return if $mtime && time() - $mtime < 2 * 3600;

	my $hn_dir = "$opts{dir}/hackernews";
	mkdir($hn_dir, 0755);
	my @lst = reverse(glob("$opts{dir}/articles/*"));
	foreach my $fname (@lst) {
		my $info = read_article($fname);
		next if ($info->{site} || '') ne "HackerNews";
		my $uri = $info->{body};
		$uri =~ s/^.*(https:[^"]*)".*/$1/s;
		my $id = $uri;
		$id =~ s/^.*id=//;

		###############################################
		#   Dont   get  file  if  its  quite  old  -  #
		#   probably not updating much.		      #
		###############################################
		my $tmp = "$hn_dir/$id";
		my $mtime = (stat($tmp))[9];
		next if $mtime && time() - $mtime > 30;

		print "$fname $uri\n";
		my $cmd = "curl -k '$uri' >>$tmp 2>/dev/null";
		spawn($cmd);
	}

	###############################################
	#   Create index			      #
	###############################################
	my %idx;
	foreach my $fname (reverse(glob("$hn_dir/*"))) {
		next if basename($fname) !~ /^\d+$/;
		my $fh = new FileHandle($fname);
		my $title = "";
		my $slink = '';
		my $cmts;
		my $score = 0;
		while (<$fh>) {
			if (!$slink &&
			    /<a href="(http[^"]*)"/ && $1 !~ /http:\/\/www.ycombinator/) {
				$slink = $1;
			}
			if (/<title>(.*)<\/title>/) {
				$title = $1;
				$title =~ s/ \| Hacker News//;
				next;
			}
			if (/>(\d+) comment/) {
				$cmts = $1;
			}
			if (/">(\d+) point/) {
#print "got score $fname $1\n";
				$score = $1;
			}
			last if $cmts && $score;
		}
		###############################################
		#   Keep it if it looks good.		      #
		###############################################
#if (!defined($cmts)) {
#die "$fname";
#}
		if ($cmts && $cmts > 10) {
			$idx{$fname}{cmt} = $cmts;
			$idx{$fname}{score} = $score;
			$idx{$fname}{title} = $title;
			$idx{$fname}{size} = (stat($fname))[7];
			$idx{$fname}{slink} = $slink;
		}
	}

	my $last_mo = '';
	my $ofh;
	my $idx = "";
	my %seen;

	foreach my $f (sort(keys(%idx))) {
		my $mtime = (stat($f))[9];
		my $this_mo = strftime("%Y%m", localtime($mtime));

		if (!defined($seen{$this_mo})) {
			$idx .= "<a href='/hackernews/$this_mo.html'>$this_mo</a> ";
			$seen{$this_mo} = '';
		}
	}

	foreach my $m (keys(%seen)) {
		$seen{$m} = "<p>$idx<p><table>\n";
	}

	foreach my $f (reverse(sort(keys(%idx)))) {
		my $mtime = (stat($f))[9];
		my $this_mo = strftime("%Y%m", localtime($mtime));

		my $t = $idx{$f}{title};
		$t = substr($t, 0, 54) . "..." if length($t) > 54;
#		printf "%3d %3dKB %3d | %s\n", 
#			$idx{$f}{cmt}, $idx{$f}{size} / 1024, 
#			$idx{$f}{score},
#			$t,
#			basename($f);

		my $str = '';
		$str .= "<tr>\n";
		$str .= "<td>" . strftime("%Y%m%d", localtime($mtime)) . "</td>";
		$str .= sprintf("<td width=40 align=right>%d</td>",
			$idx{$f}{cmt});
		$str .= sprintf("<td width=40 align=right>%dKB</td>",
			$idx{$f}{size} / 1024);
		$str .= sprintf("<td width=40><a href='%s'>Link</a></td>",
			$idx{$f}{slink});
		$str .= sprintf("<td><a href='%s'>%s</td>\n",
			basename($f),
			$idx{$f}{title});
		$seen{$this_mo} .= $str;
	}

	my $str = '';
	foreach my $m (sort(keys(%seen))) {
		$ofh = new FileHandle(">$opts{dir}/hackernews/$m.html");
		$str = $seen{$m};
		print $ofh $seen{$m};
		print $ofh "<p>Bytes: ", length($str), "\n";
	}
	
	$ofh = new FileHandle(">$opts{dir}/hackernews/index.html");
	print $ofh $str;
	print $ofh "<p>Bytes: ", length($str), "\n";

}

######################################################################
#   Get a page or the next page.				     #
######################################################################
sub get_page
{	my $epoch = shift;

	my @lst = reverse(glob("$opts{dir}/articles/*"));

	my $i = 0;
	my $pg = 0;
	my $size = 0;
	my @secs;
	my $html = $javascript;

	for ( ; $i < @lst; $pg++) {
		my $html = '';
		my $txt = '';

		my $site = '';
		my $last_site = '';
		my $ent = 0;
		my $last_ent = 0;
		my $sec1 = '';
		my $sec2 = '';

		my %info;
		for (; $i < scalar(@lst); $i++) {
			my $fname = $lst[$i];
			#print "Output: $fname\n";

			%info = ();
			my $fh = new FileHandle($fname);
			my $mtime = (stat($fname))[9];
			my $tstr = strftime("%d %a %H:%M", localtime($mtime));
			my $ignore = 0;
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
				if ($epoch && $lh eq 'date1' && $rh < $epoch) {
					$ignore = 1;
					last;
				}
#print "epoch=$epoch lh=$lh rh=$rh\n";
				$info{$lh} = $rh;

				if ($lh eq 'body') {
					while (<$fh>) {
						$info{body} .= $_;
					}
					foreach my $t (qw/body title/) {
						$info{$t} = convert_chars($info{$t});
					}
					last;
				}
			}

			###############################################
			#   Generate article.			      #
			###############################################
	#print "$info{site} vs $site\n";
			last if $ignore;

			if (!defined($sites{$info{site}})) {
#				print "ignore: $fname ($info{site}\n";
				next;
			}

			if ($info{site} ne $last_site) {
				if ($last_site) {
					my $n = $ent - $last_ent;
					$sec1 =~ s/\[XX]/[$n]/;
					$size += length($sec1) + length($sec2);
					push @secs, $sec1 . $sec2;
	#print "#$last_ent $info{name}\n";
				}
				$last_site = $info{site};
				$site = $info{site};

				$sec1 = '';
				$sec2 = '';
				$sec1 .= "</div>\n";
				$sec1 .= "<br>\n";
				$sec1 .= "<div id='a${ent}p'>";
				$sec1 .= "&nbsp;&nbsp;&nbsp;&nbsp;";
				$sec1 .= "<a href='#' onclick=\"toggle('a$ent'); return false;\">Show</a> ";
				$sec1 .= "$tstr\n";
				$sec1 .= "<a name='$ent'><a href='$sites{$site}{site}'>$info{name}</a> [XX]";
				$sec1 .= "</div>\n";
				$sec1 .= "<div id='a$ent' style=\"display: none;\">";
				$last_ent = $ent;
			}
			$sec2 .= "<p>$info{date3} ";
			$sec2 .= "<a href='$info{link}'><b>$info{title}</b></a><br>";
			$sec2 .= "$info{body}";

			$txt .= "$info{date3} Title: $info{title}\n";
			$txt .= "   $info{body}\n";
			$txt .= "   $info{link}\n";

			if ($size + length($sec1) + length($sec2) > $opts{size} * 1024) {
				$sec2 .= "<p><b>results truncated...\n";
				last;
			}
			$ent++;
		}

		###############################################
		#   Generate output file.		      #
		###############################################
		my $secs = join("", @secs);
		my $page = sprintf(strftime("Generated %d %a %H:%M", localtime()) . " Size: %dK", 
			(length($html) + length($secs)) / 1024);
		$page .= " Articles: $ent ";
		if ($pg) {
			$page .= "&nbsp;&nbsp;&nbsp;<a href='p" . ($pg == 1 ? "" : $pg-1) . ".html'>Prev</a>";
		}
		if ($i < @lst) {
			$page .= "&nbsp;&nbsp;&nbsp;<a href='p" . ($pg+1) . ".html'>Next</a>";
		}
		$page .= "<hr>" . $html;

		$html = $page .
			$html . 
			$secs .
			"</div><hr>rss.pl, Author: Paul Fox $copyright_year crispeditor-at-gmail-com\n";

		return $html if $epoch;

		###############################################
		#   Post processing.			      #
		###############################################
		$size = 0;
		@secs = ();
	}

}
######################################################################
#   Retrieve page from the web site.				     #
######################################################################
sub get_rss
{	my $s = shift;

	return if $s eq 'GLOBAL';
	if (!$opts{fetch}) {
#print "a\n";
		return -1 if $sites{$s}{disabled};
		$sites{$s}{period} ||= 4 * 3600;

		###############################################
		#   If this site is in error mode, then dont  #
		#   keep retrying it.			      #
		###############################################
#print "b - ", time(), " $sites{$s}{etime} ", strftime("%Y%m%d %H%M%S", localtime($sites{$s}{etime})), " $sites{$s}{period}\n";
		return (0, 1) if $sites{$s}{etime} && time() < $sites{$s}{etime} + $sites{$s}{period};
#print "c\n";
		return 0 if $sites{$s}{stime} && time() + 10 < $sites{$s}{stime} + $sites{$s}{period};
#print "d\n";
	}
	if ($opts{n}) {
		print time_string() . "Get[-n]: $s\n";
		return 1;
	}

	my $proto = $sites{$s}{site};
#print "e - $proto s=$s\n";
	return 0 if !$proto;
#print "f\n";

	$proto =~ s/:.*$//;
	my $addr = $sites{$s}{site};
#print "$s.site=$addr proto=$proto\n";
	$addr =~ s/^http[^:]*:\/\///;
	$addr =~ s/\/.*$//;

	###############################################
	#   Handle https			      #
	###############################################
	if ($proto eq 'https' || 1) {
		my $fname = $sites{$s}{name} || $addr;
		$fname = "$opts{dir}/sites/$fname";
		my $fh = new FileHandle(">$fname");
		print $fh "$s\n";
		$fh->close();

		my $cmd = "curl -L $sites{$s}{site} >>$fname 2>/dev/null";
#print $cmd, "\n";
		system($cmd);
		delete($sites{$s}{error});
		delete($sites{$s}{etime});
		$sites{$s}{stime} = time();
		$sites{$s}{stime2} = strftime("%Y%m%d %H:%M:%S", localtime());

		my $size = (stat($fname))[7];
		print time_string() . "$s .. ", $size, " bytes\n";
		return 1;
	}

	###############################################
	#   Plain http				      #
	###############################################

	my $uri = $sites{$s}{site};
	$uri =~ s/^http:\/\///;
	$uri =~ s/^[^\/]*\///;
#print "uri='$uri'\n";
#return;
#	print "  addr=$addr\n";
	my $sock = IO::Socket::INET->new (
	   PeerAddr => $addr,
	   PeerPort => 80,
	   Type      => SOCK_STREAM,
	   Timeout => 10);
	if (!$sock) {
		###############################################
		#   Record  last time we had an error, so we  #
		#   dont  keep  retrying  in  the face of an  #
		#   issue.				      #
		###############################################
		$sites{$s}{error} = $!;
		$sites{$s}{etime} = time();
		print time_string() . "Cannot connect to '$addr': $!\n";
		$err++;
		sleep(1);
		return 0;
	}

	print $sock 
		"GET /$uri HTTP/1.0\r\n" .
		"Host: $addr\r\n" .
		"\r\n";

	my $str = '';
	my $str1 = '';
	eval {
		local $SIG{ALRM} = sub {};
		alarm(15);
		while (sysread($sock, $str1, 32768)) {
			$str .= $str1;
		}
		alarm(0);
		};
	if ($@) {
		print time_string() . "Error reading from $s\n";
		return 0;
	}

	my $fname = $sites{$s}{name} || $addr;
	my $fh = new FileHandle(">$opts{dir}/sites/$fname");
	print $fh "$s\n";
	print $fh $str;
	delete($sites{$s}{error});
	delete($sites{$s}{etime});
	$sites{$s}{stime} = time();
	$sites{$s}{stime2} = strftime("%Y%m%d %H:%M:%S", localtime());
	$sites{$s}{bytes} = length($str);

	print time_string() . "$s .. ", length($str), " bytes\n";
	return 1;
}

my %hackernews;

######################################################################
#   Handle webserver request.					     #
######################################################################
sub handle_client
{	my $client = shift;
	my $ccookies = shift;
	my $req = shift;
	my $cnt = shift;

	my $str = '';
	my $gzip = 1;
	my $content_type = "text/html";
	my $cookie = $ccookies->{RSS_PL_FOXTROT} || get_cookie();
	my $raw_cookie = $cookie;
	$req = "/p.html" if !$req || $req eq '/' || $req eq '/p';
	$req = '/status.html' if $req eq '/status';


	if ($req eq '/help') {
		$str = $javascript . $help_txt;
	} elsif ($req eq '/favicon.ico') {
		my $fh = new FileHandle("rss.ico");
		return if !$fh;

		sysread($fh, $str, 16384);

		$gzip = 0;
		$content_type = "image/x-icon";

	} elsif ($req eq '/q') {
		my $t = $cookies{$raw_cookie} || time();
		$str = $javascript . get_page($t - 4*3600);
	} else {
		if ($req eq "/hackernews" || $req eq '/hackernews/index.html') {
			get_hackernews();
			$req = "/hackernews/index.html";
		} elsif ($req =~ /^\/hackernews\/(\d+).html$/ ||
		         $req =~ /^\/hackernews\/(\d+)$/) {
			$hackernews{$1} = 1;
		} elsif ($req !~ /\/p\d*.html$/ && $req ne '/status.html') {
			$history{req404}++;
			print $client "HTTP/1.0 404 not found\r\n" .
				"Content-Type: text/html\r\n\r\n";
			return;
		}

		###############################################
		#   Refresh status page if we wanted that.    #
		###############################################
		if ($req eq '/status.html') {
			gen_status();
		}

		my $fh = new FileHandle("$opts{dir}$req");
		if (!$fh) {
			print $client "HTTP/1.0 404 sorry\r\n" .
				"Content-Type: text/html\r\n" .
				$cookie .
				"\r\n" .
				"I'm afraid I cant do that. Someone borrowed that file and didnt put it back.\r\n";
			return;
		}
	#print "cookie='$cookie'\n";
		sysread($fh, $str, 1024 * 1024);
	}

	if ($cookie) {	
		$cookies{$cookie} = time();
		$cookie = strftime("Set-Cookie: RSS_PL_FOXTROT=$cookie; expires=%a, %d %b %Y %H:%M:%S UTC; path=/\r\n", 
			localtime(time() + 7 * 86400));
	}

	my %wr;
	$wr{time} = time();
	$wr{client} = $client;
	$wr{str} = '';
	$wr{pos} = 0;
	$client->blocking(0);
	
	$wr{str} = "HTTP/1.0 200 ok\r\n" .
		"Content-Type: $content_type\r\n" .
		($gzip ? "Content-Encoding: gzip\r\n" : "") .
		$cookie .
		"\r\n";

	my $t = $curl_msg . "Next: " . strftime("%H:%M ", localtime($target_time));
	$t .= " Req#$history{req} ";
	$t .= "<a href='/hackernews/index.html'> HN </a>&nbsp;&nbsp;" if $req !~ /\/q/;
	$t .= "<a href='/p'> P </a>&nbsp;&nbsp; " if $req !~ /\/p/;
	$t .= "<a href='/q'> Q </a>&nbsp;&nbsp; " if $req !~ /\/q/;
	$t .= "<a href='/help'>Help</a> ";
#$t .= " <span style='color:yellow; background:red;'>cookie: $raw_cookie/$cookies{$raw_cookie}</span> ";
#$t .= $css;
#$t .= "<table width=300><tr><td>";
	my $tail = <<EOF;
<br>
<div id='mp'><a href='#' onclick="toggle('m'); return false;">More...</a></div>
<div id='m' style="display:none;">
This web site may be withdrawn at any stage, and is provided
especially for minimising mobile bandwidth whilst looking at 
particular pages. It is not customisable and hope you find
it useful. You may see it evolve to add more features.
Cookie support may be added to allow "continuation browsing" to
be implemented.
<p class='fn'>
$next_scan
</div>
EOF
	$tail = "" if $req ne '/status.html' && $req ne '/help';


#$tail .= "</td></table>\n";

	###############################################
	#   Generate the page with header/footer.     #
	###############################################
	$str = Compress::Zlib::memGzip($t . $str . $tail) if $gzip;
	$t = '';
	$wr{str} .= $str;

	###############################################
	#   Send  page to client - allow us to break  #
	#   up the page.			      #
	###############################################
	my $n = syswrite($client, $wr{str});
	print time_string() . "Response: ", int((length($wr{str}) + 512) / 1024), "K\n";
	return if !defined($n);
	return if $n eq length($wr{str});

	print time_string() . "deferred write...n=$n\n";
	$wr{pos} = $n;
	###############################################
	#   Avoid  DOS  by  holding  open  too  many  #
	#   connections.			      #
	###############################################
	@writers = () if @writers > 30;
	push @writers, \%wr;
	vec($wbits, $client->fileno(), 1) = 1;
}


######################################################################
#   Main entry point.						     #
######################################################################
sub main
{
	$ENV{TZ} = "/etc/localtime";

	Getopt::Long::Configure('require_order');
	Getopt::Long::Configure('no_ignore_case');
	usage() unless GetOptions(\%opts,
		'clean',
		'copy_script=s',
		'dir=s',
		'f',
		'fetch',
		'get=s',
		'hackernews',
		'help',
		'init',
		'n',
		'nokill',
		'notime',
		'output',
		'page=s',
		'parse',
		'size=s',
		'sleep=s',
		'ticker',
		'weather',
		);

	$prog = $0;

	usage() if $opts{help};

	print time_string() . "RSS starting - pid $$\n";
	print "\033[37m";

	$opts{dir} = "$ENV{HOME}/.rss";
	if ($opts{hackernews}) {
		get_hackernews();
		exit(0);
	}

	if (! -f "/usr/bin/curl") {
		$curl_msg = "<h2>NOTE! curl is missing so some sites may fail to work</h2>\n";
	}

	###############################################
	#   Check if rss.pl is already running.	      #
	###############################################
	$opts{quiet} = 1;
	kill_old("rss", \%opts);

	$| = 1;

	my $ticker = "$FindBin::RealBin/ticker.pl";

	open(my $orig_stdout, '>&', \*STDOUT);
	open(my $orig_stdin, '<&', \*STDIN);

	###############################################
	#   Run in server mode.			      #
	###############################################
	if (!$opts{f} && !$opts{init} && !$opts{clean} && !$opts{parse} && !$opts{output}) {
		background("rss", \*STDOUT, \%opts);
	}

	if ($opts{ticker}) {
		my $pid = $$;
		if (fork() == 0) {
     			open(STDOUT, ">&", $orig_stdout);
     			open(STDIN, "<&", $orig_stdin);
			exec "$ticker -ppid $pid";
			exit(0);
		}
	}

	my $dir = $opts{dir};
	$rss_cfg = shift @ARGV || "rss.cfg";
	read_cfg($rss_cfg);
	read_cfg($opts{dir} . "/status", 1);

	$opts{dir} = $dir if $dir;

	mkdir("$opts{dir}/sites", 0755);
	mkdir("$opts{dir}/articles", 0755);
	mkdir("$opts{dir}/archive", 0755);

	read_art_hash();
	read_history();
	read_seq_no();

	###############################################
	#   Prune out disabled sites.		      #
	###############################################
	foreach my $s (keys(%sites)) {
		next if $s eq 'GLOBAL';
		if (defined($sites{$s}{disabled}) || !defined($sites{$s}{site})) {
			print time_string() . "Deleting old: $s\n";
			delete($sites{$s});
			next;
		}
		$sites{$s}{stime} ||= time() - 86400;
	}

	if ($opts{init}) {
		print "Initialising...\n";
		unlink("$opts{dir}/status");
		unlink("$opts{dir}/seq_no");
		unlink("$opts{dir}/art.hash");
		unlink(glob("$opts{dir}/articles/*"));
		unlink(glob("$opts{dir}/sites/*"));
		exit(0);
	}

	if ($opts{clean}) {
		do_clean();
		exit(0);
	}
	if ($opts{get}) {
		get_rss($opts{get});
		exit(0);
	}
	if ($opts{parse}) {
		do_parse();
		do_output();
		exit(0);
	}
	if ($opts{output}) {
		do_output();
		exit(0);
	}

	main_loop();
}
######################################################################
#   Main loop - keep checking periodically.			     #
######################################################################
sub main_loop
{
	$SIG{PIPE} = 'IGNORE';

	my @sites;
	my $sock = IO::Socket::INET->new (
	   LocalPort => $opts{port},
	   Type      => SOCK_STREAM,
	   ReuseAddr => 1,
	   Listen    => 10);
	if (!$sock) {
		print time_string() . "ERROR: cannot create socket port:$opts{port} - $!\n";
		exit(1);
	}

	my $last_status = 0;
	my $last_num = 0;
	my $tot_num = -1;
	my @lst = glob("$opts{dir}/articles/*");
	gen_status();

	while (1) {
		###############################################
		#   Update hackernews index page.	      #
		###############################################
		get_hackernews();

		###############################################
		#   Get sites into time order.		      #
		###############################################
		@sites = sort(keys(%sites));

		@sites = sort {
			if (!defined($sites{$a}{stime})) {
				print "sort: no stime for '$a'\n";
			}
			if (!defined($sites{$b}{stime})) {
				print "sort: no stime for '$b'\n";
			}
			($sites{$b}{stime} || 0) + ($sites{$b}{period} || 0) <=> 
				($sites{$a}{stime} || 0) + ($sites{$a}{period} || 0)
			} @sites;

		$target_time = time() + 86400;
		my $mtime = (stat($prog))[9];
		if ($mtime && $mtime != $prog_mtime) {
			$ENV{RSS_RESTART} = 1;
			print time_string() . "Executable changed .. restarting\n";
			save_history();
			exec($0, @argv);
		}

		my $num = 0;
#print "\n";
		foreach my $s (@sites) {
#print "site: $s\n";
			next if $s eq 'GLOBAL';
			next if $sites{$s}{disabled};
			my $t = ($sites{$s}{stime} || time()) + ($sites{$s}{period} || 0);
			$t ||= time() + 365 * 86400;
#print "$target_time - $s - ", $target_time - time(), "\n";
			my ($ret, $errtime) = get_rss($s);
			next if $ret < 0 || $errtime;
			$num += $ret;

			if ($t < $target_time) {
#printf "target_time=$target_time %s $s ret=$ret\n", 
#	strftime("%Y%m%d %H:%M:%S", localtime($target_time));
				$target_time = $t;
				if ($target_time == 0) {
					printf "zero target_time=$target_time %s $s\n", 
						strftime("%Y%m%d %H:%M:%S", localtime($target_time));
				}
			}
		}
		$opts{fetch} = 0;
		if ($num) {
			$tot_num += $num;
			@lst = glob("$opts{dir}/articles/*");
			do_parse();
			do_output();
			do_clean();
			save_history();
 			save_status(@sites);
		}

		if (time() > $last_status + 300 && ($last_status == 0 || $tot_num != $last_num)) {
			$last_num = $tot_num;
			$tot_num = 0;
			$next_scan = '<table>';
			$next_scan .= "<tr bgcolor='#ffd040'>\n";
			$next_scan .= "<td>New</td>\n";
			$next_scan .= "<td>Total</td>\n";
			$next_scan .= "<td>Next scan</td>\n";
			$next_scan .= "<td>Name</td>\n";
			my $r = 0;
			foreach my $s (@sites) {
				next if $sites{$s}{disabled};
				next if !$sites{$s}{site};

				my $txt = sprintf(time_string() . "%6d/%-6d %s %s%s",
					$sites{$s}{tot_new} || 0, $sites{$s}{tot_art} || 0,
					strftime("%a %H:%M:%S", localtime($sites{$s}{stime} + $sites{$s}{period})),
					$sites{$s}{etime} ? "!" : " ",
					$s);
				print $txt, " ", 
					$sites{$s}{bytes} || 0, " bytes",
					" ",
					$sites{$s}{art_new} || 0,
					"/",
					$sites{$s}{art_tot} || 0,
					"\n";

				if ($r++ & 1) {
					$next_scan .= "<tr>";
				} else {
					$next_scan .= "<tr bgcolor='#c0e0ff'>";
				}
				$next_scan .= "<td align=right>" .
					($sites{$s}{tot_new} || 0) .
					"</td>\n";
				$next_scan .= "<td align=right>" .
					($sites{$s}{tot_art} || 0) .
					"</td>\n";
				$next_scan .= "<td>" .
					strftime("%a %H:%M:%S", localtime($sites{$s}{stime} + $sites{$s}{period})) .
					"</td>\n";
				$next_scan .= "<td>" .
					$s .
					"</td>\n";
			}
			$next_scan .= "</table>\n";
			$last_status = time();
		}

		my $msg = "Sleeping til " . 
			strftime("%Y%m%d %H:%M:%S", localtime($target_time)) . "... (" . 
			scalar(@lst) . "/" .
			scalar(@art_list) .
			" articles)\n";
		print time_string() . $msg;
		$msg = "";

		###############################################
		#   Dont  wait  exactly  until the time runs  #
		#   out - so we can detect swsusp.	      #
		###############################################
		my $bits = '';
#print "sock=$sock\n";
		vec($bits, $sock->fileno(), 1) = 1;
		my $select_time = time();
#print "target_time=$target_time ", time(), "\n";
		my $t = $target_time - time();
#print "t=$t\n";
		$t = 200 if $t > 200;
		my $n = select(my $rbits = $bits, my $wbit = $wbits, undef, $t);
		if (!$n) {
			if (time() == $select_time) {
				print "select($t) took zero seconds.\n";
				sleep(2);
			}
			next;
		}

		###############################################
		#   Handle non-blocking writers.	      #
		###############################################
		my @nwr;
		foreach my $wr (@writers) {
			if ($wr->{time} + 120 < time()) {
				print time_string() . "Dropping stale writer\n";
				vec($wbits, $wr->{client}->fileno(), 1) = 0;
				next;
			}
			if (!vec($wbit, $wr->{client}->fileno(), 1)) {
				push @nwr, $wr;
				next;
			}
			my $n = syswrite($wr->{client}, $wr->{str}, length($wr->{str}) - $wr->{pos}, $wr->{pos});
			if (!defined($n)) {
				print time_string() . "Write error: $!\n";
				vec($wbits, $wr->{client}->fileno(), 1) = 0;
				next;
			}
			print time_string() . "Deferred write pos=$wr->{pos} len=", length($wr->{str}), " n=$n\n";
			if ($n + $wr->{pos} >= length($wr->{str})) {
				print time_string() . "Write completed\n";
				vec($wbits, $wr->{client}->fileno(), 1) = 0;
				next;
			}
			$wr->{pos} += $n;
			push @nwr, $wr;
		}
		@writers = @nwr;

		###############################################
		#   Handle new connection.		      #
		###############################################
		next if !vec($rbits, $sock->fileno(), 1);
		my $client = $sock->accept();
		next if !$client;

		###############################################
		#   Assume req fits into a single block.      #
		###############################################
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
			next;
		}

		###############################################
		#   Look for cookie.			      #
		###############################################
		my %ccookies;
		my %fields;
		foreach my $ln (split("\n", $req)) {
			$ln =~ s/\r//;
			if ($ln =~ /^cookie:/i) {
				$ln =~ s/^cookie:\s*//;
				chomp($ln);
				foreach my $c (split(/[; ]+/, $ln)) {
					my ($lh, $rh) = split("=", $c);
					next if !$rh;
					$rh =~ s/"*\s*$//;
					$rh =~ s/\s*"//;
					$ccookies{$lh} = $rh;
				}
			} else {
				my ($label, $val) = split(/[: ]+/, $ln);
				next if !$label;
				$fields{lc($label)} = $val;
			}
		}
		if ($fields{from} && $fields{from} =~ /googlebot.com/) {
			$history{googlebot}++;
		}

		###############################################
		#   Send client the page.		      #
		###############################################
		my ($hname) = gethostbyaddr($client->peerhost(), AF_INET) || 'unknown';
		print time_string() . "Connection ",
				$client->peerhost() . ":" . $client->peerport() . " $hname\n";
		if (!$req) {
			print time_string() . "ERROR: Req: no request present?\n";
			next;
		}
 		print "Req=$req\n";
		if ($req !~ /^GET /) {
			print "ERROR: Invalid GET - ignoring\n";
			next;
		}

		$req = (split(/[\r\n]/, $req))[0];
#		print time_string() . "Req: $req\n";
		$req = (split(" ", $req))[1];

		my $cnt = 0;
		if ($req ne '/status.html') {
			$history{req}++;
			my $stats_idx = strftime("s%Y%m%d", localtime());
			$cnt = ++$history{$stats_idx};
		}

		handle_client($client, \%ccookies, $req, $cnt);
	}
}

######################################################################
#   Read   the   history  of  article  links  -  so  we  dont  keep  #
#   representing old news stories.				     #
######################################################################
sub read_art_hash
{
	@art_list = ();

if (1) { # to delete
	my $fname = "$opts{dir}/art.hash";
	my $fh = new FileHandle($fname);
	return if !$fh;
	while (<$fh>) {
		chomp;
		my ($a, $h) = split(" ");
		$art_hash{$h} = $a;
		push @art_list, {
			id => $a,
			link => $h,
			time => time(),
			};
	}
}

	my $fname = "$opts{dir}/art.hash2";
	my $fh = new FileHandle($fname);
	return if !$fh;
	while (<$fh>) {
		chomp;
		my ($id, $yymmdd, $hhmmss, $time, $link) = split(" ");
		next if defined($art_hash{$link});
		push @art_list, {
			id => $id,
			link => $link,
			time => $time,
			};
		$art_hash{$link} = $id;
	}
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
#   Read the config file - site definitions and other aspects.	     #
######################################################################
sub read_cfg
{	my $fname = shift;
	my $quiet = shift;

	$fname ||= "rss.cfg";
	my $fh = new FileHandle($fname);
	if (!$fh) {
		return if $quiet;
		print "rss.pl: Cannot open $fname - $!\n";
		return;
	}

	my $site = '';
	while (<$fh>) {
		chomp;
		next if /^#/;
		$_ =~ s/^\s+//;
		$_ =~ s/^\s+$//;

		my ($lh, $rh) = split("=");
		next if !$lh;
		if ($lh eq "dir") {
			$rh =~ s/\$HOME/$ENV{HOME}/;
			$opts{dir} = $rh;
			mkdir($rh, 0755);
			next;
		}
		if ($lh =~ /^(period|retry)$/) {
			if ($rh =~ /m$/) {
				$rh =~ s/m$//;
				$rh *= 60;
			} elsif ($rh =~ /h$/) {
				$rh =~ s/h$//;
				$rh *= 3600;
			} elsif ($rh =~ /d$/) {
				$rh =~ s/d$//;
				$rh *= 86400;
			}
		}
		if ($lh =~ /^retry$/) {
			$opts{$lh} = $rh;
			next;
		}
		if ($lh eq 'name') {
			$site = $rh;
		}
#print "$site.$lh=$rh\n";
		$sites{$site}{$lh} = $rh;
		$sites{$site}{stime} ||= 0;
	}
}
######################################################################
#   Load the cookie data.					     #
######################################################################
sub read_cookies
{
	my $fname = "$opts{dir}/cookies";
	my $fh = new FileHandle($fname);
	return if !$fh;
	while (<$fh>) {
		chomp;
		my ($a, $h) = split("=");
		$cookies{$a} = $h;
	}
}
######################################################################
#   Read history and stats.					     #
######################################################################
sub read_history
{
	read_cookies();

	my $fname = "$opts{dir}/history";
	my $fh = new FileHandle($fname);
	return if !$fh;
	while (<$fh>) {
		chomp;
		my ($a, $h) = split("=");
		$history{$a} = $h;
	}
}

sub read_seq_no
{
	my $fname = "$opts{dir}/seq_no";
	my $fh = new FileHandle($fname);
	return if !$fh;

	$a_id = <$fh>;
	$a_id = 0 if !defined($a_id);
	chomp($a_id);
}

######################################################################
#   Save  articles  in  numeric  order  -  helps  to  debug or spot  #
#   something strange.						     #
######################################################################
sub save_art_hash
{
	###############################################
	#   Save the article hash.		      #
	###############################################
if (1) {
	my $fname = "$opts{dir}/art.hash";
	my $fh = new FileHandle(">" . $fname);
	my %h;
	$h{$art_hash{$_}} = $_ foreach keys(%art_hash);
	foreach my $id (sort { $a <=> $b } (keys(%h))) {
		print $fh "$id $h{$id}\n";
	}
}

	my $fname = "$opts{dir}/art.hash2";
	my $fh = new FileHandle(">" . $fname);
	foreach my $a (@art_list) {
		print $fh "$a->{id} ", 
			strftime("%Y%m%d %H:%M:%S", localtime($a->{time})),
			" $a->{time} ",
			"$a->{link}\n";
	}
}
######################################################################
#   Save the cookies.						     #
######################################################################
sub save_cookies
{
	my $fname = "$opts{dir}/cookies";
	my $fh = new FileHandle(">" . $fname);
	print $fh "$_=$cookies{$_}\n" foreach sort(keys(%cookies));
}
######################################################################
#   Save some connection history.				     #
######################################################################
sub save_history
{
	save_cookies();

	###############################################
	#   Save the article hash.		      #
	###############################################
	my $fname = "$opts{dir}/history";
	my $fh = new FileHandle(">" . $fname);
	print $fh "$_=$history{$_}\n" foreach sort(keys(%history));
}

sub save_status
{	my @sites = @_;

	my $fh = new FileHandle(">$opts{dir}/status.tmp");
	if (!$fh) {
		die "Cannot create $opts{dir}/status.tmp - $!";
	}
	foreach my $s (sort(@sites)) {
		next if $s eq 'GLOBAL';
		print $fh "name=$s\n";
		foreach my $k (sort(keys(%{$sites{$s}}))) {
			next if !defined($sites{$s}{name});
			next if $sites{$s}{name} eq 'GLOBAL';
			next if $k eq 'name';
			print $fh "$k=$sites{$s}{$k}\n";
		}
		print $fh "\n";
	}
	$fh->close();
	if (!rename("$opts{dir}/status.tmp", "$opts{dir}/status")) {
		print time_string() . "Error: rename $opts{dir}/status.tmp - $!\n";
	}
}

sub spawn
{	my $cmd = shift;

	print time_string() . "$cmd\n";
	return if $opts{n};
	return system($cmd);
}

#######################################################################
#   Print out command line usage.				      #
#######################################################################
sub usage
{
	print <<EOF;
rss.pl -- RSS feed reader.
Usage: rss.pl [rss.cfg]

Description:

  An RSS feed reader - designed to create small downloadable
  pages to optimise mobile bandwidth. A config file lists the
  sites to visit, and how long.

  The script will act as a web service, serving up compressed
  pages, which are totally self-contained, and designed to allow
  the reader to read the items, whilst tracking what they have
  read. This tracking is purely done in javascript in the browser.

  rss.pl does not implement any tracking, except for possible
  cookie support to track/hilight what is new compared to your
  last refresh.

Ticker mode:

  When RSS runs, it runs in the background, collecting data.
  In the foreground, it can display a terminal based display of
  headlines, and random content.

  (Additionally, an HTML page is created, which can be viewed from
  an available webserver, to see a richer version of the current
  headlines).

Switches:

  -clean       Just clean and exit.
  -copy_script <script>
               Copy ticker.html script, e.g. archive copies and remote
               copy to another machine (web server)
  -dir <dir>   Override default \$HOME/.rss
  -f           Dont fork into the background.
  -fetch       Refetch data from sites.
  -hackernews  Generate hackernews index
  -init        Initialise the repository.
  -n           Dry run - dont fetch.
  -output      Generate output file.
  -page2       In ticker mode, just display page#2 which is a random
               topic
  -parse       Parse RSS feeds into articles
  -size NN     Size (in KB) for the output page.
  -sleep NN    Time for refresh when doing news ticker.
  -ticker      Generate ticker.html and console output file.
  -weather     Generate warther reports in ticker output.

EOF

	exit(1);
}

main();
0;