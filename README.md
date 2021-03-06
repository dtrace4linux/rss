
  ![Photos](images/IMG_0855.jpg)

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
  * image display - divided up into album covers, photos,
    stock images, web site front pages
  * reminders

The file rss_options.cfg can be used to configure the weather, stock
symbols, and other attributes. The file rss.cfg is used to describe the
sites to poll.

Screenshots are recorded, so you can publish random samples of whats
on the display (easier than trying to get a good quality photograph).

Outputs

  The script has three modes of operation:

  * process to periodically retrieves headlines and store them
  * process to generate a news stream to stdout/console
  * generate a clickable HTML page, with option to copy the page
    to your own web site. 

Notes
  
  The code is largely standalone with almost no dependencies.
  (scripts/get-deps.sh can be used to install some of the optional
  useful utilities for text manipulation, and to build the
  framebuffer driver).
  
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

$HOME/images directory

  The $HOME/images folder is used to store and display images. So
  far, there are four types of pages:

  images/news - autopopulated with the home page of certain news web
  sites

  images/photos - your selection of personal photos

  images/album - album covers - put your own selection of jpg/png
  files in here.

  By segregating the photos, we can be sure that each type will be
  displayed on a periodic basis, rather than one single/giant collection
  of images.

  If the screen frame buffer cannot be accessed (eg permission issue
  or OS specific issue), then the image will be rendered with the img2txt
  utility

  img2txt provides ASCII art based rendering, which is fine, but not
  truely accurate. It is available in the caca-utils package if you
  want it.

Makefile
  The makefile is setup to build the C utility, "fb" (framebuffer).
  You will need gcc and libjpeg/libpng libraries to build this.
  The fb utility is used to display images and take screenshots.

  $ make

  It will create a frame-buffer renderer and draw the real JPG or PNG
  image. 

  The script "scripts/pexels.pl" can be used to acquire random stock images
  from http://pexels.com, but you need an API key to do this. Or,
  just populate the folder with a random selection of your own photos.

reminders.txt

  Periodically, the reminders.txt file is checked for small/short
  messages to display on the console. Useful for reminders.

  (At a later date, may provide a WEB UI to add/update/delete items
  so that others in the house can make updates).

  For example:

```
 _        _          _   _            _     _                         _
| |_ __ _| | _____  | |_| |__   ___  | |__ (_)_ __  ___    ___  _   _| |_
| __/ _` | |/ / _ \ | __| '_ \ / _ \ | '_ \| | '_ \/ __|  / _ \| | | | __|
| || (_| |   <  __/ | |_| | | |  __/ | |_) | | | | \__ \ | (_) | |_| | |_
 \__\__,_|_|\_\___|  \__|_| |_|\___| |_.__/|_|_| |_|___/  \___/ \__,_|\__|
```

TODO

  There are many things to do for future work. The current UI for
  the console is just a periodic scrolling of headlines. It would be
  good to add touch support to drill into a news item or show
  alternate views (such as weather/stocks)

  * Cycle a weather history / prediction
  * Stock chart

Dependencies:

  See scripts/get-deps.pl for the dependencies on Raspbian/Buster
  and Ubuntu.

Examples:

  ![Demo](video/video1.svg)

  ![Screenshot](images/screenshot-1510.jpg)

  ![Screenshot](images/screenshot-1511.jpg)

  ![Screenshot](images/screenshot-1520.jpg)

  ![Screenshot](images/screenshot-1547.jpg)

  ![Screenshot](images/screenshot-1626.jpg)

  ![Screenshot](images/screenshot-1635.jpg)

  ![Screenshot](images/screenshot-1708.jpg)
