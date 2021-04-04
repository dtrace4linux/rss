/*

https://github.com/bvdberg/code/blob/master/linux/framebuffer/fb-example.c

Tool based on above example code to write a JPG to the console frame
buffer.

Date: Feb 2021
Author: Paul Fox (modifications/enhancements)

Useful ref for a similar tool to this:

https://github.com/godspeed1989/fbv/blob/master/main.c

*/

#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <linux/fb.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <errno.h>
#include "fb.h"

int quiet;
int fullscreen;
int	stretch;
int	effects;
int	info;
int	page = -1;
float	xfrac = 1.0;
float	yfrac = 1.0;

struct fb_var_screeninfo vinfo;
struct fb_fix_screeninfo finfo;
long int location = 0;
long int screensize = 0;

/**********************************************************************/
/*   Prototypes.						      */
/**********************************************************************/
void normal_display(char *fbp, struct imgRawImage *img, int x, int y, int w, int h);
void fullscreen_display(char *fbp, struct imgRawImage *img, double f);
void stretch_display(char *fbp, struct imgRawImage *img);
void put_pixel(char *fbp, int r, int g, int b);
void	usage(void);

int do_switches(int argc, char **argv)
{	int	i;

	for (i = 1; i < argc; i++) {
		char *cp = argv[i];

		if (*cp++ != '-')
			break;

		while (*cp) {
			if (strcmp(cp, "effects") == 0) {
				effects = 1;
				break;
			}
			if (strcmp(cp, "fullscreen") == 0) {
				fullscreen = 1;
				break;
			}
			if (strcmp(cp, "info") == 0) {
				info = 1;
				break;
			}
			if (strcmp(cp, "page") == 0) {
				if (++i >= argc)
					usage();
				page = atoi(argv[i]);
				break;
			}
			if (strcmp(cp, "stretch") == 0) {
				stretch = 1;
				break;
			}
			if (strcmp(cp, "xfrac") == 0) {
				if (++i >= argc)
					usage();
				xfrac = atof(argv[i]);
				break;
			}
			if (strcmp(cp, "yfrac") == 0) {
				if (++i >= argc)
					usage();
				yfrac = atof(argv[i]);
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
    int	fd;
    char	buf[BUFSIZ];

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

    if (info) {
	    printf("%dx%d, %dbpp\n", vinfo.xres, vinfo.yres, vinfo.bits_per_pixel );
	    printf("xres_virtual=%d yres_virtual=%d\n",
	    	vinfo.xres_virtual, vinfo.yres_virtual);
    }


    if (fname == NULL) {
    	if (info)
		exit(0);
    	usage();
	exit(1);
    }

    if ((fd = open(fname, O_RDONLY)) < 0) {
    	printf("fb: Cannot open %s - %s\n", fname, strerror(errno));
	exit(1);
    }
    if (read(fd, buf, 4) != 4) {
    	printf("File too short - %s\n", fname);
	exit(1);
    }
    close(fd);

    if (memcmp(buf, "\x89PNG", 4) == 0) {
    	if ((img = read_png_file(fname)) == NULL) {
    		printf("fb: Failed to load: %s\n", fname);
		exit(1);
	}
    } else if (memcmp(buf, "\xff\xd8\xff", 3) == 0) {
	if ((img = loadJpegImageFile(fname)) == NULL) {
    		printf("fb: Failed to load: %s\n", fname);
		exit(1);
		}
    } else {
    	printf("Cannot determine image format\n");
	exit(1);
    }

    if (info) {
    	printf("Image: %ldx%ld\n", img->width, img->height);
    	exit(0);
    }

    if (!quiet) {
	    printf("%dx%d, %dbpp\n", vinfo.xres, vinfo.yres, vinfo.bits_per_pixel );
	    printf("Image: %ldx%ld\n", img->width, img->height);
    }

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

	if (effects) {
		int i;
		double f = 0;
		struct timeval tv;
		for (i = 0; i < 10; i++) {
			fullscreen_display(fbp, img, f);
			f += 0.1;
			tv.tv_sec = 0;
			tv.tv_usec = 100000;
			select(0, NULL, NULL, NULL, &tv);
		}
	} else if (fullscreen) {
		fullscreen_display(fbp, img, 1.0);
	} else if (stretch) {
		stretch_display(fbp, img);
	} else {
		normal_display(fbp, img, x, y, w, h);
	}

    munmap(fbp, screensize);
    close(fbfd);
    return 0;
}

void
fullscreen_display(char *fbp, struct imgRawImage *img, double f)
{
	int	x, y;
	float xfrac = vinfo.xres / (float) img->width;
	float yfrac = vinfo.yres / (float) img->height;
//printf("frac=%f %f\n", xfrac, yfrac);

	for (y = 0; y < vinfo.yres; y++) {
	        location = (vinfo.yoffset + y) * finfo.line_length +
			vinfo.xoffset * (vinfo.bits_per_pixel / 8);
		for (x = 0; x < vinfo.xres; x++) {
			unsigned char *data = &img->lpData[
				(int) (y / yfrac) * img->width * 3 +
				(int) (x / xfrac) * 3];

			put_pixel(fbp, data[0] * f, data[1] * f, data[2] * f);
		}
	}
}

void 
normal_display(char *fbp, struct imgRawImage *img, int x, int y, int w, int h)
{	int	x0, y0;
	unsigned char *img_data = img->lpData;

	if (page > 0)
		img_data += img->width * 3 * page * vinfo.yres;
//printf("%d %d w=%d h=%d\n", x, y, w, h);

    // Figure out where in memory to put the pixel
    for ( y0 = y; y0 < y + h; y0++ ) {
    	if (y0 - y >= img->height)
		break;

        location = 
	    	(y0+vinfo.yoffset) * finfo.line_length +
		(x+vinfo.xoffset) * (vinfo.bits_per_pixel/8);

	unsigned char *data = &img_data[((y0-y) * img->width + x) * 3];
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
stretch_display(char *fbp, struct imgRawImage *img)
{
	int	x, y;
	float xfrac = 1;
	float yfrac = 1;
	int	width = img->width;

	xfrac = vinfo.xres / (float) img->width;
	yfrac = vinfo.yres / (float) img->height;
	xfrac = yfrac;
	width *= xfrac;

	int	x0 = (vinfo.xres - width) / 2;
//printf("frac=%f %f\n", xfrac, yfrac);
//printf("x0=%d xfrac=%.2f yfrac=%.2f\n", x0, xfrac, yfrac);

	for (y = 0; y < vinfo.yres; y++) {
	        location = (vinfo.yoffset + y) * finfo.line_length +
			vinfo.xoffset * (vinfo.bits_per_pixel / 8);
		for (x = 0; x < vinfo.xres; x++) {
			if (x < x0 || x > x0 + width)
				put_pixel(fbp, 0, 0, 0);
			else {
				unsigned char *data = &img->lpData[
					(int) (y / yfrac) * img->width * 3 +
					(int) ((x - x0) / xfrac) * 3];

				put_pixel(fbp, data[0], data[1], data[2]);
			}
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
	fprintf(stderr, "   -effects        Scroll-in effects enabled\n");
	fprintf(stderr, "   -fullscreen     Stretch image to fill screen\n");
	fprintf(stderr, "   -info           Print screen size info\n");
	fprintf(stderr, "   -page N         Display page/screen N of the image\n");
	fprintf(stderr, "   -stretch        Stretch but dont change aspect ratio\n");
	fprintf(stderr, "   -xfrac N.NN     Shrink image on the x-axis\n");
	fprintf(stderr, "   -yfrac N.NN     Shrink image on the y-axis\n");

}
