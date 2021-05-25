# Build the image displayer

BIN=../bin.$(shell uname -m)

$(BIN)/fb: fb.c fb.h jpeg.c png.c shapes.c
	mkdir -p $(BIN)
	gcc -W -g -O2 -o $(BIN)/fb fb.c jpeg.c png.c shapes.c -ljpeg -lpng
