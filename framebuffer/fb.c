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
#include <time.h>
#include "fb.h"

enum ctypes { C_NONE, C_DELAY, C_EXIT };

typedef struct cmd_t {
	int	type;
	int	x, y, w, h;
	} cmd_t;

int quiet;
char	*f_flag;
char	*script_file;
int fullscreen;
int	rand_flag;
int	stretch;
int	montage;
int	shrink;
int	effects;
int	scroll = 0;
int	scroll_y_incr = 50;
int	info;
int	num;
int	page = -1;
int	seq_flag;
char	*cvt_ofname;
char	*ofname;
long	delay = 500;
float	xfrac = 1.0;
float	yfrac = 1.0;
int	x_arg = 0, y_arg = 0;
int	w_arg = -1, h_arg = -1;
int	v_flag;

char *fbp = 0;
struct fb_var_screeninfo vinfo;
struct fb_fix_screeninfo finfo;
long int location = 0;
long int screensize = 0;

/**********************************************************************/
/*   Prototypes.						      */
/**********************************************************************/
cmd_t	*next_script_cmd(void);
void process_file(void);
void shrink_display(char *fbp, struct imgRawImage *img);
int	display_file(char *fname, int do_wait);
void normal_display(char *fbp, struct imgRawImage *img, int x, int y, int w, int h, int x1, int y1);
void fullscreen_display(char *fbp, struct imgRawImage *img, double f);
void stretch_display(char *fbp, struct imgRawImage *img);
void put_pixel(char *fbp, int r, int g, int b);
void	usage(void);
int	write_jpeg(char *ofname, unsigned char *img, int w, int h, int depth);

int
display_file(char *fname, int do_wait)
{	int	fd;
	char	buf[BUFSIZ];
	struct imgRawImage *img = NULL;

	if ((fd = open(fname, O_RDONLY)) < 0) {
		printf("fb: Cannot open %s - %s\n", fname, strerror(errno));
		return 1;
	}
	if (read(fd, buf, 4) != 4) {
		printf("File too short - %s\n", fname);
		return 1;
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
		return 1;
//		printf("Cannot determine image format: %s\n", fname);
//		exit(1);
	}

	if (info) {
		printf("Image: %ldx%ld\n", img->width, img->height);
		return 1;
	}

//printf("num=%d\n", img->numComponents);

# if 0
	if (img->numComponents == 81) {
		/***********************************************/
		/*   Convert mono to RGB/24 bit		       */
		/***********************************************/
		unsigned char *newimg = malloc(img->width * img->height * 4 + 1);
		unsigned x, y;
printf("converting\n");

		for (y = 0; y < img->height; y++) {
			char *sp = img->lpData + y * img->width * 3;
			char *dp = newimg + y * img->width * 4;
			for (x = 0; x < img->width; x++) {
				*dp++ = *sp;
				*dp++ = *sp;
				*dp++ = *sp;
				*dp++ = 0;
				sp++;
			}
		}
		free(img->lpData);
		img->lpData = newimg;
		img->numComponents = 32;
	}
# endif

	if (cvt_ofname) {
		write_jpeg(cvt_ofname, img->lpData, 
			img->width, img->height, img->numComponents);
		exit(0);
	}

	if (ofname) {
		write_jpeg(ofname, fbp, vinfo.xres, vinfo.yres, vinfo.bits_per_pixel);
		exit(0);
	}

/*
    printf("The framebuffer device was mapped to memory successfully.\n");
*/

	if (w_arg < 0)
		w_arg = img->width;
	if (h_arg < 0)
		h_arg = img->height;

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
	} else if (script_file) {
		cmd_t *cmdp;

		if ((cmdp = next_script_cmd()) != NULL) {
			if (cmdp->type == C_EXIT)
				return 0;

			x_arg = cmdp->x;
			y_arg = cmdp->y;
			w_arg = cmdp->w;
			h_arg = cmdp->h;
			shrink_display(fbp, img);
		}
	} else if (montage) {
static int x, y;
		x_arg = (rand() / (float) RAND_MAX) * vinfo.xres;
		y_arg = (rand() / (float) RAND_MAX) * vinfo.yres;
		w_arg = (rand() / (float) RAND_MAX) * 80 + 20;
		h_arg = (rand() / (float) RAND_MAX) * 80 + 20;
		if (seq_flag) {
			x_arg = x;
			y_arg = y;
			if ((x += w_arg) >= (int) vinfo.xres) {
				x = 0;
				y += 40;
			}
		}
		shrink_display(fbp, img);
	} else if (shrink) {
		shrink_display(fbp, img);
	} else if (stretch) {
		stretch_display(fbp, img);
	} else if (scroll) {
		int i;
		int	x1 = 0;
		int	y1 = 0;
		struct timeval tv;
		while (y1 + vinfo.yres < img->height) {
			normal_display(fbp, img, x_arg, y_arg, w_arg, h_arg, x1, y1);
			tv.tv_sec = delay / 1000;
			tv.tv_usec = (delay % 1000) * 1000;
			y1 += scroll_y_incr;
			select(0, NULL, NULL, NULL, &tv);
		}
	} else {
		normal_display(fbp, img, x_arg, y_arg, w_arg, h_arg, 0, 0);
	}

	free(img->lpData);
	free(img);

	if (!do_wait)
		return 1;

    	struct timeval tval;
	tval.tv_sec = 0;
	tval.tv_usec = 0;
	tval.tv_usec = delay * 1000;
	select(0, NULL, NULL, NULL, &tval);
	return 1;
}

int 
do_switches(int argc, char **argv)
{	int	i;

	for (i = 1; i < argc; i++) {
		char *cp = argv[i];

		if (*cp++ != '-')
			break;

		while (*cp) {
			if (strcmp(cp, "cvt") == 0) {
				if (++i >= argc)
					usage();
				cvt_ofname = argv[i];
				break;
			}
			if (strcmp(cp, "delay") == 0) {
				if (++i >= argc)
					usage();
				delay = atol(argv[i]);
				break;
			}
			if (strcmp(cp, "f") == 0) {
				if (++i >= argc)
					usage();
				f_flag = argv[i];
				break;
			}
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
			if (strcmp(cp, "montage") == 0) {
				montage = 1;
				break;
			}
			if (strcmp(cp, "num") == 0) {
				if (++i >= argc)
					usage();
				num = atoi(argv[i]);
				break;
			}

			if (strcmp(cp, "o") == 0) {
				if (++i >= argc)
					usage();
				ofname = argv[i];
				break;
			}
			if (strcmp(cp, "page") == 0) {
				if (++i >= argc)
					usage();
				page = atoi(argv[i]);
				break;
			}
			if (strcmp(cp, "rand") == 0) {
				rand_flag = 1;
				break;
			}
			if (strcmp(cp, "script") == 0) {
				if (++i >= argc)
					usage();
				script_file = argv[i];
				break;
			}
			if (strcmp(cp, "seq") == 0) {
				seq_flag = 1;
				break;
			}
			if (strcmp(cp, "shrink") == 0) {
				shrink = 1;
				break;
			}
			if (strcmp(cp, "scroll") == 0) {
				scroll = 1;
				break;
			}
			if (strcmp(cp, "scroll_y_incr") == 0) {
				if (++i >= argc)
					usage();
				scroll_y_incr = atoi(argv[i]);
				break;
			}
			if (strcmp(cp, "stretch") == 0) {
				stretch = 1;
				break;
			}
			if (strcmp(cp, "x") == 0) {
				if (++i >= argc)
					usage();
				x_arg = atoi(argv[i]);
				break;
			}
			if (strcmp(cp, "y") == 0) {
				if (++i >= argc)
					usage();
				y_arg = atoi(argv[i]);
				break;
			}
			if (strcmp(cp, "w") == 0) {
				if (++i >= argc)
					usage();
				w_arg = atoi(argv[i]);
				break;
			}
			if (strcmp(cp, "h") == 0) {
				if (++i >= argc)
					usage();
				h_arg = atoi(argv[i]);
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
			  case 'v':
			  	v_flag = 1;
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
    int	x0, y0;
    int	arg_index = 1;
    char	*fname = NULL;
    int	fd;

    arg_index = do_switches(argc, argv);

    srand(time(NULL));

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

    // Figure out the size of the screen in bytes
    screensize = vinfo.xres * vinfo.yres * vinfo.bits_per_pixel / 8;

    if (info) {
	    printf("%dx%d, %dbpp\n", vinfo.xres, vinfo.yres, vinfo.bits_per_pixel );
	    printf("xres_virtual=%d yres_virtual=%d\n",
	    	vinfo.xres_virtual, vinfo.yres_virtual);
    }


    if (arg_index >= argc && !ofname && !f_flag) {
    	if (info)
		exit(0);
    	usage();
	exit(1);
    }

    if (!quiet) {
	    printf("%dx%d, %dbpp\n", vinfo.xres, vinfo.yres, vinfo.bits_per_pixel );
    }

    // Map the device to memory
    fbp = (char *)mmap(0, screensize, PROT_READ | PROT_WRITE, MAP_SHARED, fbfd, 0);
    if (fbp == (char *) -1) {
        printf("Error: failed to map framebuffer device to memory.\n");
        return -4;
    }

    if (ofname) {
    	write_jpeg(ofname, fbp, vinfo.xres, vinfo.yres, vinfo.bits_per_pixel);
	exit(0);
    }

    /***********************************************/
    /*   Clear screen if doing montage.		   */
    /***********************************************/
    if (montage) {
    	memset(fbp, 0x00, screensize);
    }

    if (f_flag) {
    	process_file();
    } else {

	    while (arg_index < argc) {

	    	fname = argv[arg_index++];
		display_file(fname, arg_index >= argc ? 0 : 1);
		if (arg_index >= argc)
			break;

	    }
	}

    munmap(fbp, screensize);
    close(fbfd);
}


void
fullscreen_display(char *fbp, struct imgRawImage *img, double f)
{
	int	x, y;
	float xfrac = vinfo.xres / (float) img->width;
	float yfrac = vinfo.yres / (float) img->height;
//printf("frac=%f %f\n", xfrac, yfrac);

	for (y = 0; y < (int) vinfo.yres; y++) {
	        location = (vinfo.yoffset + y) * finfo.line_length +
			vinfo.xoffset * (vinfo.bits_per_pixel / 8);
		for (x = 0; x < (int) vinfo.xres; x++) {
			unsigned char *data = &img->lpData[
				(int) (y / yfrac) * img->width * 3 +
				(int) (x / xfrac) * 3];

			put_pixel(fbp, data[0] * f, data[1] * f, data[2] * f);
		}
	}
}

cmd_t *
next_script_cmd()
{	static cmd_t c;
static FILE *fp;
	char	buf[BUFSIZ];
# define MAX_ARGS 16
	char	*args[MAX_ARGS];
	char	*cp;
static int line = 0;
static int swidth, sheight;

	if (fp == NULL) {
		if ((fp = fopen(script_file, "r")) == NULL) {
			perror(script_file);
			exit(1);
		}
	}

	while (1) {
		int	a = 0;

		line++;
		if (fgets(buf, sizeof buf, fp) == NULL) {
			if (v_flag)
				printf("[EOF]\n");
			c.type = C_EXIT;
			return &c;
		}
		if (v_flag) {
			printf("%s", buf);
		}

		if (*buf && buf[strlen(buf) - 1] == '\n') {
			buf[strlen(buf) - 1] = '\0';
		}

		if (*buf == '\0' || *buf == ' ' || *buf == '#' || *buf == '\n')
			continue;

		for (cp = strtok(buf, " "); cp; cp = strtok(NULL, " ")) {
			if (a < MAX_ARGS) {
				args[a++] = cp;
			}
		}
		if (strcmp(args[0], "draw") == 0 && a >= 5) {
			c.x = atoi(args[1]);
			c.y = atoi(args[2]);
			c.w = atoi(args[3]);
			c.h = atoi(args[4]);

			c.x *= vinfo.xres / (float) swidth;
			c.y *= vinfo.yres / (float) sheight;
			c.w *= vinfo.xres / (float) swidth;
			c.h *= vinfo.yres / (float) sheight;

			return &c;
		}
		if (strcmp(args[0], "clear") == 0) {
		    	memset(fbp, 0x00, screensize);
			continue;
		}
		if (strcmp(args[0], "delay") == 0 && a >= 1) {
			delay = atoi(args[1]);
			continue;
		}
		if (strcmp(args[0], "number") == 0 && a >= 1) {
		    	num = atoi(args[1]);
			continue;
		}
		if (strcmp(args[0], "clear") == 0) {
		    	memset(fbp, 0x00, screensize);
			continue;
		}
		if (strcmp(args[0], "sleep") == 0 && a >= 1) {
			sleep(atoi(args[1]));
			continue;
		}
		if (strcmp(args[0], "screensize") == 0 && a >= 1) {
			swidth = atoi(args[1]);
			sheight = atoi(args[2]);
			continue;
		}

		printf("%s:%d: bad command - not recognized '%s'\n",
			script_file, line, args[0]);
	}

	return &c;
}

void 
normal_display(char *fbp, struct imgRawImage *img, int x, int y, int w, int h, int x_off, int y_off)
{	int	x0, y0;
	unsigned char *img_data = img->lpData;

	img_data += y_off * 3 * img->width;

	if (page > 0)
		img_data += img->width * 3 * page * vinfo.yres;
//printf("%d %d w=%d h=%d\n", x, y, w, h);

	for (y0 = y; y0 < y + h; y0++) {
		if (y0 - y >= (int) img->height)
			break;

	        location = 
		    	(y0+vinfo.yoffset) * finfo.line_length +
			(x+vinfo.xoffset) * (vinfo.bits_per_pixel/8);

		unsigned char *data = &img_data[((y0-y) * img->width + x) * 3];
	        for (x0 = x; x0 < x + w; x0++) {
		    if (x0 - x >= (int) img->width) {
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

/**********************************************************************/
/*   Read image names from a file. Allow us to randomize them.	      */
/**********************************************************************/
void
process_file()
{	int	n = 0;
	char	**names = malloc(1);
	char	*name1, *name2;
    	char buf[BUFSIZ];
	int	i;
    	FILE *fp = fopen(f_flag, "r");

	if (fp == NULL) {
		perror(f_flag);
		exit(1);
	}
	while (fgets(buf, sizeof buf, fp) != NULL) {
		if (*buf && buf[strlen(buf)-1] == '\n')
			buf[strlen(buf) - 1] = '\0';
		names = realloc(names, (n+1) * sizeof(char *));
		names[n++] = strdup(buf);
	}

	if (rand_flag) {
		for (i = 0; i < n; i++) {
			int r = (rand() / (float) RAND_MAX) * n;
			name1 = names[i];
			name2 = names[r];
			names[i] = name2;
			names[r] = name1;
		}
	}

	for (i = 0; i < n; i++) {

		if (display_file(names[i], 1) == 0)
			break;

		free(names[i]);
		if (num && --num == 0)
			break;
	}
	free(names);
}

void
shrink_display(char *fbp, struct imgRawImage *img)
{
	int	x, y;
	float xfrac = 1;
	float yfrac = 1;
	int	width = img->width;

	width *= xfrac;

	int vwidth = w_arg < (int) vinfo.xres ? w_arg : (int) vinfo.xres;
	int vheight = h_arg < (int) vinfo.yres ? h_arg : (int) vinfo.yres;

	xfrac = img->width / (float) vwidth;
	yfrac = img->height / (float) vheight;

	int	x0 = 0;
//printf("frac=%f %f [img: %dx%d] %d,%d\n", xfrac, yfrac, img->width, img->height, x_arg, y_arg);
//printf("x0=%d xfrac=%.2f yfrac=%.2f\n", x0, xfrac, yfrac);

	for (y = 0; y < vheight; y++) {
		if (y_arg + vinfo.yoffset > vinfo.yres)
			break;

	        location = (y_arg + vinfo.yoffset + y) * finfo.line_length +
			(x_arg + vinfo.xoffset) * (vinfo.bits_per_pixel / 8);
		for (x = 0; x < vwidth; x++) {
			if (x + x_arg > (int) vinfo.xres || location >= screensize)
				break; 
			if (x < x0 || x > x0 + width)
				put_pixel(fbp, 0, 0, 0);
			else {
				unsigned char *data = &img->lpData[
					(int) (y * yfrac) * img->width * 3 +
					(int) ((x - x0) * xfrac) * 3];

				put_pixel(fbp, data[0], data[1], data[2]);
			}
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

	for (y = 0; y < (int) vinfo.yres; y++) {
	        location = (vinfo.yoffset + y) * finfo.line_length +
			vinfo.xoffset * (vinfo.bits_per_pixel / 8);
		for (x = 0; x < (int) vinfo.xres; x++) {
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
	fprintf(stderr, "Usage: fb [switches] <file1> <file2> ...\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "Switches:\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "   -cvt <fname>       Write loaded image to file.\n");
	fprintf(stderr, "   -delay NN          Scroll delay in milliseconds\n");
	fprintf(stderr, "   -effects           Scroll-in effects enabled\n");
	fprintf(stderr, "   -f <file>          Get filenames from specified file.\n");
	fprintf(stderr, "   -fullscreen        Stretch image to fill screen\n");
	fprintf(stderr, "   -info              Print screen size info\n");
	fprintf(stderr, "   -o <fname>         Write screen buffer to an output jpg file\n");
	fprintf(stderr, "   -montage           Display images as thumbnails\n");
	fprintf(stderr, "   -num NN            Only process first NN images\n");
	fprintf(stderr, "   -page N            Display page/screen N of the image\n");
	fprintf(stderr, "   -rand              Randomize files\n");
	fprintf(stderr, "   -script <file>     Script file to do complex layouts\n");
	fprintf(stderr, "   -scroll            Scroll image\n");
	fprintf(stderr, "   -scroll_y_incr NN  When using -scroll, scroll by this much.\n");
	fprintf(stderr, "   -seq               When doing montage, display l->r\n");
	fprintf(stderr, "   -stretch           Stretch but dont change aspect ratio\n");
	fprintf(stderr, "   -xfrac N.NN        Shrink image on the x-axis\n");
	fprintf(stderr, "   -yfrac N.NN        Shrink image on the y-axis\n");
	fprintf(stderr, "   -x NN              Set co-ordinate\n");
	fprintf(stderr, "   -y NN              Set co-ordinate\n");
	fprintf(stderr, "   -w NN              Set co-ordinate\n");
	fprintf(stderr, "   -v                 Verbose; list lines in script files\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "Examples:\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "  $ fb -montage -delay 1 -rand -f index.log -num 30\n");
	exit(1);
}
