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
