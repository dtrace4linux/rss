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

scp $host:release/rss/version.txt /tmp/version.txt
diff -c /tmp/version.txt version.txt
if [ $? = 1 ]; then
	get=1
fi

if [ $get = 0 ]; then
#	date "+%Y%m%d %H:%M:%S Software release up-to date."
	exit 0
fi
date "+%Y%m%d %H:%M:%S New update available: `cat /tmp/version.txt`"
scp $host:release/rss/rss-current.tar.gz /tmp
sync
#ssh $host ls -lrt release/rss | tail
zcat < /tmp/rss-current.tar.gz | tar xf -
make
sync
