#! /bin/bash

base=stained-glass
url=https://stainedglassinc.com/glass/mid/
idx=/tmp/$base.idx

i=100
if [ -f $idx ]; then
	i=$(cat $idx)
fi

mkdir -p $HOME/images/$base
j=$(expr $i + 100)

while [ $i -lt $j ]
do
	echo $i > $idx
	fn=$HOME/images/$base/img$i.jpg
	if [ ! -f $fn ]; then
		echo wget -O $fn "$url/$i.jpg"
		wget -O $fn "$url/$i.jpg"
	else
		echo Skipping $i: $fn
	fi
	if [ ! -s $fn ]; then
		rm $fn
	fi
	i=$(expr $i + 1)
done
find $HOME/images/$base -type f | sort > $HOME/images/$base/index.log
