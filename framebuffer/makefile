# Build the image displayer

BIN=../bin.$(shell uname -m)

$(BIN)/fb: fb.c fb.h jpeg.c png.c script.c shapes.c usage.c
	mkdir -p $(BIN)
	gcc -W -g -O2 -o $(BIN)/fb fb.c jpeg.c png.c script.c shapes.c usage.c -ljpeg -lpng

usage.c: usage.txt
	(echo 'const char *usage_text = ' ; \
	sed -e 's/"/\\"/g' -e 's/^\(.*\)/"\1\\n"/' < usage.txt ; \
	echo ';' ) >usage.c
