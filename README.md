"rss.pl" is yet another RSS reader. In many respects, it is nothing
special. It was written to provide a stream of news headlines, ideal
for consumption on mobile - just the text, no images or complex javascript.
And no adverts, from the underlying streams.

It has evolved, to include a news-ticker stream. This means that
the page can be viewed in a web browser, or a special display-only
device, and provide real news. (Having experienced Amazon Alexa devices,
with a nice hardware construction, the on-screen results are very
lacking in content, timeliness, or real world interest).

The single script, rss.pl, runs in multiple modes:

  * data collection on a periodic basis
  * console mode display (ticker mode)

As well as news headlines, it includes the following:

  * stock symbol updates
  * weather for your area

The file rss_options.cfg can be used to configure the weather, stock
symbols, and other attributes. The file rss.cfg is used to describe the
sites to poll.

Outputs

  The script has three modes of operation:

  * process to periodically retrieves headlines and store them
  * process to generate a news stream to stdout/console
  * generate a clickable HTML page, with option to copy the page
    to your own web site. 

Notes
  
  The code is largely standalone with almost no dependencies.
  
  The weather report relies on /usr/bin/ansiweather - so you would need
  to install that. At some point I may replace with a native API.
  (ansiweather uses its own API key, so we can piggy back that).
  
  The code uses a config (rss.cfg) to determine what sites to hit.
  Be careful of hitting sites too frequently - else the owner may
  block access for a period of time. "Every few hours" is reasonable
  for most sites. Ultimately the code should work out itself a reasonable
  polling frequency.
  
  What this means is that it can go quiet for an hour or more (on the
  display), and suddenly 30 or more headlines would appear, rather than
  drip feeding them in at a constant rate. (I tried this, but didnt work
  and the code needs rethinking).

  Site data is cached into $HOME/.rss - where the archives of
  headlines and summaries/hashes are kept. No auto clean up is done,
  so you may find after a year or two, its eating a fair amount
  of space (no more than a few GB / year - depending on your site
  subscriptions).

  The site list is mostly tech orientated. Some sites have been
  commented out. Many/most have migrated to https, and the native
  http get code will automatically default to 'curl' to pull the headlines 
  down.

Startup

  You can just manually run "rss.pl" - no setup. It will start streaming
  to the console/terminal.

  There is an S99rss script you can put into /etc/rc5.d or /etc/init.d
  so that it starts on boot.

  The start script may have uncustomizable items in (eg refs to /home dir
  where it assumes its running from). Good to check out the script.

  There is also a 'startup' simplified script.

  The goal of S99rss is to switch to the console terminal on Linux.
  On a keyboardless raspberry pi, you likely have the Raspian UI
  appear on startup. By switching to /dev/tty1, we leave that running
  and just run in the console. You may decide to nuke the UI.

  There is a 15s or so startup delay, as the script hopes that the GUI
  has finished appearing, so that we switch screens after the UI is up,
  and not before. This needs improving.

  The code for launching the ticker display in the background is a bit
  ugly, but seems to work. The main rss.pl forks a grand child to
  handle the terminal. This should be a foreground process, but is
  actually a background (need to fix). You can normally just rerun
  rss.pl - and it will take care of killing the existing background
  processes.

images/ directory

  If you place a series of images in this folder, then periodically
  they are rendered to the screen, via the img2txt tool (caca-utils
  package)

TODO

  There are many things to do for future work. The current UI for
  the console is just a periodic scrolling of headlines. It would be
  good to add touch support to drill into a news item or show
  alternate views (such as weather/stocks)

  * Cycle a weather history / prediction
  * Stock chart

Dependencies:

  These tools or packages are optional but will be invoked if installed:

  * ansiweather
  * caca-utils

Examples:

  [Demo](video/video1.svg)
