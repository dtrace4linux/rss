The RSS feed tool is designed to be an eye-candy application.
It can be run on a small screen, e.g. a 5" or 7" screen attached
to a raspberry pi, but, can also be run on a monitor, and
even a 4K TV screen.

The application is divided up into multiple components:

   * rss.pl: Application launcher. This handles getting information
   from various web sites, via RSS feed, and stores them to disk.

   * ticker.pl: This randomly selects items from the RSS data, and
   intermingles with various slide shows, and random games. All
   designed to make the screen interesting.

   * fb: fb started as a simple tool to display a JPG or PNG
   image to the console. Much of ticker.pl is plain text - to the
   console, but by allowing images to be displayed, we can get
   a richer experience. fb can display images, and run scripts,
   and layout images in random or non-random ways.

   * fbview: fbview is an X11 application, which can display
   a virtual screen buffer. Whilst 'fb' is designed to write to
   the physical video console, via a bitmap buffer, this is not
   under X windows, or, inside a web browser. "fb" can write
   to the physical console, or a virtual console (a memory
   mapped file). The latter is useful for debuggin, from an X desktop.
   fbview provides a way to monitor, in real time, the screen
   content. (Without this, it is necessary to switch outside of
   the X desktop, to a console screen, which can be inconvenient
   for debugging). Additionally, since fb can view the content,
   a future version may provide video recording of the screen content.
