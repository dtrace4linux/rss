#! /bin/bash
i=100
if [ -f /tmp/fineart.idx ]; then
	i=$(cat /tmp/fineart.idx)
fi
while [ $i -lt 2000 ]
do
	echo $i > /tmp/fineart.idx
	fn=$HOME/images/fine-art/img$i.jpg
	if [ ! -f $fn ]; then
		echo wget -O $fn "http://www.fine-art-images.net/img_z.php?id=$i&s=n"
		wget -O $fn "http://www.fine-art-images.net/img_z.php?id=$i&s=n"
	else
		echo Skipping $i: $fn
	fi
	if [ ! -s $fn ]; then
		rm $fn
	fi
	i=$(expr $i + 1)
done
