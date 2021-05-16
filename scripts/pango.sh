#! /bin/sh

#echo "$@" >/tmp/pango.txt
pango-view --dpi 200 -q -o /tmp/pango.png $1
bin/fb /tmp/pango.png
