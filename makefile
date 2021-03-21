
none:

all:
	toilet --gay rss news - no adverts > rss-hello.txt
	echo "Touch the screen, to display the next item." >> rss-hello.txt
	echo "https://github.com/dtrace4linux/rss" >> rss-hello.txt

get:
	scp -r ricky:src/rss /tmp/rss
	diff -r . /tmp/rss
