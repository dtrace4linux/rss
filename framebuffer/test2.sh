#! /bin/sh

FB="-framebuffer /tmp/fb"

doit ()
{
	echo $*
	$*
}

for i in data/draw*.txt
do
	doit bin/fb $FB -script $i -f $HOME/images/movie-posters/index.log
done
