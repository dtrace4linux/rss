BIN=bin.$(shell uname -m)

all:
	mkdir -p $(BIN)
	rm -f bin
	ln -s $(BIN) bin
	cd framebuffer ; make
	#scripts/gendraw.pl

hello:
	toilet --gay rss news - no adverts > rss-hello.txt
	echo "Touch the screen, to display the next item." >> rss-hello.txt
	echo "https://github.com/dtrace4linux/rss" >> rss-hello.txt

get:
	scp -r ricky:src/rss /tmp/rss
	diff -r . /tmp/rss

release:
	v=`head -1 version.txt` ; \
	v=`expr $$v + 1` ; \
	v=`printf %04d $$v` ; \
	echo $$v > version.txt ; \
	git commit -m "version $$v" . ; \
	git tag "version-$$v" ; \
	label=`date +%Y%m%d-$$v` ; \
	fn=$(HOME)/release/rss/rss-$$label.tar.gz ; \
	tar czf $$fn --exclude=bin --exclude=.git . ; \
	echo $$fn created ; \
	rm -f $(HOME)/release/rss/rss-current.tar.gz ; \
	ln -s rss-$$label.tar.gz $(HOME)/release/rss/rss-current.tar.gz ; \
	cp version.txt $(HOME)/release/rss
	cd $(HOME)/release/rss ; . ; find . | sort > updates.txt

push:

	for host in pi3 pi4news_a pi4news2 ; do \
	scp $(HOME)/release/rss/rss-current.tar.gz $$host:/tmp ; \
	ssh $$host "cd src/rss ; zcat < /tmp/rss-current.tar.gz | tar xf - " ; \
	done
