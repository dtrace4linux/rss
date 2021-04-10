#! /bin/sh

# Configure a host in $HOME/.rss/rss_config.cfg. ticker.pl will
# poll once an hour for a software update.
# This is mostly useful for myself, during development.

eval `grep check_update_host=.. $HOME/.rss/rss_config.cfg`
if [ "$check_update_host" = "" ]; then
	exit 0
fi
host=$check_update_host

get=0
if [ ! -f /tmp/updates.txt ]; then
	echo > /tmp/updates.txt
	get=1
fi

scp $host:release/rss/updates.txt /tmp/updates-new.txt
diff -c /tmp/updates.txt /tmp/updates-new.txt
if [ $? = 1 ]; then
	get=1
	cp /tmp/updates-new.txt /tmp/updates.txt
fi

if [ $get = 0 ]; then
#	date "+%Y%m%d %H:%M:%S Software release up-to date."
	exit 0
fi
date "+%Y%m%d %H:%M:%S New update available"
scp $host:release/rss/rss-current.tar.gz /tmp
ssh $host ls -l release/rss
zcat < /tmp/rss-current.tar.gz | tar xf -
make
