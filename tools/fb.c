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
#include <string.h>
#include <linux/fb.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include "fb.h"

int quiet;
int fullscreen;

struct fb_var_screeninfo vinfo;
struct fb_fix_screeninfo finfo;
long int location = 0;
long int screensize = 0;

/**********************************************************************/
/*   Prototypes.						      */
/**********************************************************************/
void normal_display(char *fbp, struct imgRawImage *img, int x, int y, int w, int h);
void fullscreen_display(char *fbp, struct imgRawImage *img);
void put_pixel(char *fbp, int r, int g, int b);
void	usage(void);

int do_switches(int argc, char **argv)
{	int	i;

	for (i = 1; i < argc; i++) {
		char *cp = argv[i];

		if (*cp++ != '-')
			break;

		while (*cp) {
			if (strcmp(cp, "fullscreen") == 0) {
				fullscreen = 1;
				break;
			}

			switch (*cp++) {
			  case 'q':
			  	quiet = 1;
				break;
			  default:
			  	usage();
				exit(0);
			  }
		}
	}

	return i;
}
int main(int argc, char **argv)
{
    char *fbp = 0;
    int x = 0, y = 0;
    int	w = -1, h = -1;
    int	x0, y0;
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

	if (fullscreen) {
		fullscreen_display(fbp, img);
	} else {
		normal_display(fbp, img, x, y, w, h);
	}

    munmap(fbp, screensize);
    close(fbfd);
    return 0;
}

void
fullscreen_display(char *fbp, struct imgRawImage *img)
{
	int	x, y;
	float xfrac = vinfo.xres / (float) img->width;
	float yfrac = vinfo.yres / (float) img->height;
//printf("frac=%f %f\n", xfrac, yfrac);

	for (y = 0; y < vinfo.yres; y++) {
	        location = (vinfo.yoffset + y) * finfo.line_length;
			vinfo.xoffset * (vinfo.bits_per_pixel / 8);
		for (x = 0; x < vinfo.xres; x++) {
			unsigned char *data = &img->lpData[
				(int) (y / yfrac) * img->width * 3 +
				(int) (x / xfrac) * 3];

			put_pixel(fbp, data[0], data[1], data[2]);
		}
	}
}

void 
normal_display(char *fbp, struct imgRawImage *img, int x, int y, int w, int h)
{	int	x0, y0;

//printf("%d %d w=%d h=%d\n", x, y, w, h);

    // Figure out where in memory to put the pixel
    for ( y0 = y; y0 < y + h; y0++ ) {
    	if (y0 - y >= img->height)
		break;

        location = 
	    	(y0+vinfo.yoffset) * finfo.line_length +
		(x+vinfo.xoffset) * (vinfo.bits_per_pixel/8);

	unsigned char *data = &img->lpData[((y0-y) * img->width + x) * 3];
        for (x0 = x; x0 < x + w; x0++) {
	    if (x0 - x >= img->width) {
		break;
	    }
	    if (location >= screensize) {
//	    	printf("loc=0x%04x screensize=%04x\n", location, screensize);
	    	break;
	    }

	    put_pixel(fbp, data[0], data[1], data[2]);
	    data += 3;

        }
    }
}

void
put_pixel(char *fbp, int r, int g, int b)
{
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
void
usage()
{
	fprintf(stderr, "fb -- tool to display JPG images on the framebuffer\n");
	fprintf(stderr, "Usage: fb [switches] <filename.jpg>\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "Switches:\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "   -fullscreen     Stretch image to fill screen\n");

}
