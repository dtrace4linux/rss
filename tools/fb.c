/*

https://github.com/bvdberg/code/blob/master/linux/framebuffer/fb-example.c

Tool based on above example code to write a JPG to the console frame
buffer.

Date: Feb 2021
Author: Paul Fox (modifications/enhancements)

*/

#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <linux/fb.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include "fb.h"

int quiet;

int do_switches(int argc, char **argv)
{	int	i;

	for (i = 1; i < argc; i++) {
		char *cp = argv[i];

		if (*cp++ != '-')
			break;

		while (*cp) {
			switch (*cp++) {
			  case 'q':
			  	quiet = 1;
				break;
			  }
		}
	}

	return i;
}
int main(int argc, char **argv)
{
    struct fb_var_screeninfo vinfo;
    struct fb_fix_screeninfo finfo;
    long int screensize = 0;
    char *fbp = 0;
    int x = 0, y = 0;
    int	w = -1, h = -1;
    int	x0, y0;
    long int location = 0;
    int	arg_index = 1;
    char	*fname = NULL;
    struct imgRawImage *img;

    arg_index = do_switches(argc, argv);

    if (arg_index < argc) {
    	fname = argv[arg_index++];
    }

    if (arg_index < argc) {
    	x = atoi(argv[arg_index++]);
    }
    if (arg_index < argc) {
    	y = atoi(argv[arg_index++]);
    }
    if (arg_index < argc) {
    	w = atoi(argv[arg_index++]);
    }
    if (arg_index < argc) {
    	h = atoi(argv[arg_index++]);
    }

    if ((img = loadJpegImageFile(fname)) == NULL) {
    	printf("fb: Failed to load: %s\n", fname);
	exit(1);
    }

    int fbfd = open("/dev/fb0", O_RDWR);
    if (fbfd == -1) {
        perror("opening /dev/fb0");
        return -1;
    }

    // Get fixed screen information
    if (ioctl(fbfd, FBIOGET_FSCREENINFO, &finfo)) {
        printf("Error reading fixed information.\n");
        return -2;
    }

    // Get variable screen information
    if (ioctl(fbfd, FBIOGET_VSCREENINFO, &vinfo)) {
        printf("Error reading variable information.\n");
        return -3;
    }

    if (!quiet)
	    printf("%dx%d, %dbpp\n", vinfo.xres, vinfo.yres, vinfo.bits_per_pixel );

    // Figure out the size of the screen in bytes
    screensize = vinfo.xres * vinfo.yres * vinfo.bits_per_pixel / 8;

    // Map the device to memory
    fbp = (char *)mmap(0, screensize, PROT_READ | PROT_WRITE, MAP_SHARED, fbfd, 0);
    if (fbp == (char *) -1) {
        printf("Error: failed to map framebuffer device to memory.\n");
        return -4;
    }
/*
    printf("The framebuffer device was mapped to memory successfully.\n");
*/

    if (w < 0)
    	w = img->width;
    if (h < 0)
    	h = img->height;

//printf("%d %d w=%d h=%d\n", x, y, w, h);

    // Figure out where in memory to put the pixel
    for ( y0 = y; y0 < y + h; y0++ ) {
    	if (y0 - y >= img->height)
		break;

        location = (x+vinfo.xoffset) * (vinfo.bits_per_pixel/8) 
	    	+ (y0+vinfo.yoffset) * finfo.line_length;

        for ( x0 = x; x0 < x + w; x0++ ) {
	    unsigned char *data = &img->lpData[(y0-y) * img->width * 3 + 
	    	(x0 - x) * 3 + 0];
	    if (x0 - x >= img->width)
		break;
	    if (location >= screensize) {
//	    	printf("loc=0x%04x screensize=%04x\n", location, screensize);
	    	break;
	    }

	    unsigned int r = *data++;
	    unsigned int g = *data++;
	    unsigned int b = *data++;

            if ( vinfo.bits_per_pixel == 32 ) {
                *(fbp + location) = b;
                *(fbp + location + 1) = g;
                *(fbp + location + 2) = r;
                *(fbp + location + 3) = 0;      // No transparency
		location += 4;
	    } else {
	        /***********************************************/
	        /*   Really  need to look at the rgb ordering  */
	        /*   in vinfo				       */
	        /***********************************************/
                unsigned short int t = 
			((r >> 3) <<11) | 
			(((g >> 2) & 0x3f) << 5) | 
			((b >> 3) & 0x1f);
                *((unsigned short int*)(fbp + location)) = t;
		location += 2;
	    }

        }
    }
    munmap(fbp, screensize);
    close(fbfd);
    return 0;
}
