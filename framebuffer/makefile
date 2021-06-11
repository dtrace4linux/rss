# Build the image displayer

CC= gcc -W -g -O2
BIN=../bin.$(shell uname -m)

all: $(BIN)/fb $(BIN)/xlib

$(BIN)/fb: fb.c fb.h jpeg.c png.c script.c shapes.c usage.c
	mkdir -p $(BIN)
	$(CC) -o $(BIN)/fb fb.c jpeg.c png.c script.c shapes.c usage.c -ljpeg -lpng
$(BIN)/xlib: xlib.c
	$(CC) -o $(BIN)/xlib xlib.c -lX11

usage.c: usage.txt
	(echo 'const char *usage_text = ' ; \
	sed -e 's/"/\\"/g' -e 's/^\(.*\)/"\1\\n"/' < usage.txt ; \
	echo ';' ) >usage.c
