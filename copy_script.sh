#! /bin/sh

exit 0

fn=$1

# Machine to copy to (if it exists)
dest=berry:release/website/site

# Archive the web pages, hourly.
mkdir $HOME/.rss/ticker
t=$(date +%Y%m%d-%H00)
fn2=$(basename $fn | sed -e "s/.html/-$t.html/")
cp $fn $HOME/.rss/ticker/$fn2

# echo scp $fn $dest
scp $fn $dest >/dev/null
