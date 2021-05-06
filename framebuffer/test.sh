#! /bin/sh

for i in $HOME/images/test/*
do
	fn=$(basename "$i")
	fn=$(echo "$fn" | sed -e 's/\.[^.]*$//')
	bin/fb -cvt /tmp/"$fn.jpg" "$i"
	echo "/tmp/$fn.jpg" created
done
