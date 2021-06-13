/*

https://github.com/bvdberg/code/blob/master/linux/framebuffer/fb-example.c

Tool based on above example code to write a JPG to the console frame
buffer. Originally the tool simply could display a JPG or PNG
file on the screen frame buffer. It is evolving more into a scripting
language to handle the console.

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
#include <sys/stat.h>
#include <errno.h>
#include <time.h>
#include "fb.h"

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
long	delay = 250;
float	xfrac = 1.0;
float	yfrac = 1.0;
int	x_arg = 0, y_arg = 0;
int	w_arg = -1, h_arg = -1;
int	v_flag;
char	*framebuffer_name;
int	framebuffer_w = 1920;
int	framebuffer_h = 1080;

screen_t	*scrp;

char	**filenames_list;
int	num_filenames;
int	do_free_filenames;

/**********************************************************************/
/*   Prototypes.						      */
/**********************************************************************/
screen_t	*open_framebuffer(void);
void	close_framebuffer(screen_t *);
void draw_image_old(struct imgRawImage *img);
void process_file(void);
void free_filenames(void);
struct imgRawImage *open_image(char *fname);
void normal_display(screen_t *, struct imgRawImage *img, int x, int y, int w, int h, int x1, int y1);
void fullscreen_display(screen_t *, struct imgRawImage *img, double f);
void stretch_display(screen_t *, struct imgRawImage *img);
void	usage(void);

void
free_image(struct imgRawImage *img)
{
	free(img->lpData);
	free(img);
}
struct imgRawImage *
next_image()
{	struct imgRawImage *img;
static int	i;

	while (i < num_filenames) {
		img = open_image(filenames_list[i++]);
		if (img)
			return img;
	}
	return NULL;
}

/**********************************************************************/
/*   Shuffle images.						      */
/**********************************************************************/
void
rand_images()
{	int	i;
	char	*name1;
	char	*name2;

	for (i = 0; i < num_filenames; i++) {
		int r = (rand() / (float) RAND_MAX) * num_filenames;
		name1 = filenames_list[i];
		name2 = filenames_list[r];
		filenames_list[i] = name2;
		filenames_list[r] = name1;
	}
}

struct imgRawImage *
open_image(char *fname)
{	int	fd;
	char	buf[BUFSIZ];
	struct imgRawImage *img = NULL;

	if ((fd = open(fname, O_RDONLY)) < 0) {
		printf("fb: Cannot open %s - %s\n", fname, strerror(errno));
		return NULL;
	}
	if (read(fd, buf, 4) != 4) {
		FILE	*fp;

		printf("File too short - %s\n", fname);
		if ((fp = fopen("/tmp/fb.log", "a")) != NULL) {
			fprintf(fp, "File too short - %s\n", fname);
			fclose(fp);
		}
		return NULL;
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
		return NULL;
	}

	if (info) {
		printf("Image: %ldx%ld\n", img->width, img->height);
		return NULL;
	}

	if (cvt_ofname) {
		screen_t s;
		s.s_mem = img->lpData;
		s.s_width = img->width;
		s.s_height = img->height;
		write_jpeg(cvt_ofname, &s, img->numComponents);
		exit(0);
	}

	if (ofname) {
		write_jpeg(ofname, scrp, scrp->s_bpp);
		exit(0);
	}

	return img;
}

void
do_sleep(int delay)
{
    	struct timeval tval;
	tval.tv_sec = 0;
	tval.tv_usec = 0;
	tval.tv_usec = delay * 1000;
	select(0, NULL, NULL, NULL, &tval);
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
			if (strcmp(cp, "effects") == 0) {
				effects = 1;
				break;
			}
			if (strcmp(cp, "framebuffer") == 0) {
				if (++i >= argc)
					usage();
				framebuffer_name = argv[i];
				break;
			}
			if (strcmp(cp, "framebuffer_size") == 0) {
				if (++i >= argc)
					usage();
				if (sscanf(argv[i], "%dx%d", &framebuffer_w, &framebuffer_h) != 2) {
					fprintf(stderr, "argument has usage: -framebuffer_size <width>x<height>\n");
					exit(1);
				}
				break;
			}
			if (strcmp(cp, "f") == 0) {
				if (++i >= argc)
					usage();
				f_flag = argv[i];
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

void
draw_image_old(struct imgRawImage *img)
{
	if (img == NULL)
		return;

	if (w_arg < 0)
		w_arg = img->width;
	if (h_arg < 0)
		h_arg = img->height;

	if (effects) {
		int i;
		double f = 0;
		struct timeval tv;
		for (i = 0; i < 10; i++) {
			fullscreen_display(scrp, img, f);
			f += 0.1;
			tv.tv_sec = 0;
			tv.tv_usec = 100000;
			select(0, NULL, NULL, NULL, &tv);
		}
	} else if (fullscreen) {
		fullscreen_display(scrp, img, 1.0);
	} else if (script_file) {
		cmd_t *cmdp;

		if ((cmdp = next_script_cmd()) != NULL) {
			if (cmdp->type == C_EXIT)
				return;

			x_arg = cmdp->x;
			y_arg = cmdp->y;
			w_arg = cmdp->w;
			h_arg = cmdp->h;
			shrink_display(scrp, img);
		}
	} else if (montage) {
static int x, y;
		x_arg = (rand() / (float) RAND_MAX) * scrp->s_width;
		y_arg = (rand() / (float) RAND_MAX) * scrp->s_height;
		w_arg = (rand() / (float) RAND_MAX) * 90 + 30;
		h_arg = (rand() / (float) RAND_MAX) * 90 + 30;
		if (seq_flag) {
			x_arg = x;
			y_arg = y;
			if ((x += w_arg) >= (int) scrp->s_width) {
				x = 0;
				y += 80 + (rand() / (float) RAND_MAX) * 20;
			}
			if (y_arg + h_arg >= (int) scrp->s_height) {
				exit(0);
			}
		}
		shrink_display(scrp, img);
	} else if (shrink) {
		shrink_display(scrp, img);
	} else if (stretch) {
		stretch_display(scrp, img);
	} else if (scroll) {
		int i;
		int	x1 = 0;
		int	y1 = 0;
		struct timeval tv;
		while (y1 + scrp->s_height < img->height) {
			normal_display(scrp, img, x_arg, y_arg, w_arg, h_arg, x1, y1);
			tv.tv_sec = delay / 1000;
			tv.tv_usec = (delay % 1000) * 1000;
			y1 += scroll_y_incr;
			select(0, NULL, NULL, NULL, &tv);
		}
	} else {
		normal_display(scrp, img, x_arg, y_arg, w_arg, h_arg, 0, 0);
	}

	free_image(img);
}

int
get_rand(int n)
{
	return (rand() / (float) RAND_MAX) * n;
}
int main(int argc, char **argv)
{
	int	x0, y0;
	int	arg_index = 1;
	char	*fname = NULL;
	int	fd;
	int	i;

	arg_index = do_switches(argc, argv);

	srand(time(NULL));

	scrp = open_framebuffer();

	if (info) {
		printf("%dx%d, %dbpp\n", scrp->s_width, scrp->s_height, scrp->s_bpp );
//		printf("xres_virtual=%d yres_virtual=%d\n",
//			scrp->s_width_virtual, scrp->s_height_virtual);
	}


	if (arg_index >= argc && !ofname && !f_flag) {
		if (info)
			exit(0);
		usage();
		exit(1);
	}

/*
    if (!quiet) {
	    printf("%dx%d, %dbpp\n", scrp->s_width, scrp->s_height, vinfo.bits_per_pixel );
    }
*/
	if (ofname) {
		write_jpeg(ofname, scrp, scrp->s_bpp);
		exit(0);
	}

	/***********************************************/
	/*   Clear screen if doing montage.	       */
	/***********************************************/
	if (montage) {
		memset(scrp->s_mem, 0x00, scrp->s_screensize);
	}


	if (f_flag) {
		process_file();
	} else {
		filenames_list = argv + arg_index;
		num_filenames = argc - arg_index;
		do_free_filenames = 0;
	}

	if (script_file) {
		do_script();
		exit(0);
	}

	for (i = 0; i < num_filenames; i++) {
		struct imgRawImage *img;

	    	fname = filenames_list[i];
		img = open_image(fname);
		draw_image_old(img);

		if (num_filenames> 1) {
			do_sleep(delay);
		}
	}

	free_filenames();
	close_framebuffer(scrp);
}

void
free_filenames()
{	int	i;

	if (!do_free_filenames)
		return;

	for (i = 0; i < num_filenames; i++)
		free(filenames_list[i]);
	free(filenames_list);
}

void
fullscreen_display(screen_t *scrp, struct imgRawImage *img, double f)
{
	int	x, y;
	float xfrac = scrp->s_width / (float) img->width;
	float yfrac = scrp->s_height / (float) img->height;
//printf("frac=%f %f\n", xfrac, yfrac);

	for (y = 0; y < (int) scrp->s_height; y++) {
	        scrp->s_location = (scrp->s_yoffset + y) * scrp->s_line_length +
			scrp->s_xoffset * (scrp->s_bpp / 8);
		for (x = 0; x < (int) scrp->s_width; x++) {
			unsigned char *data = &img->lpData[
				(int) (y / yfrac) * img->width * 3 +
				(int) (x / xfrac) * 3];

			put_pixel(scrp, data[0] * f, data[1] * f, data[2] * f);
		}
	}

	update_image();
}

void 
normal_display(screen_t *scrp, struct imgRawImage *img, int x, int y, int w, int h, int x_off, int y_off)
{	int	x0, y0;
	unsigned char *img_data = img->lpData;

	img_data += y_off * 3 * img->width;

	if (page > 0)
		img_data += img->width * 3 * page * scrp->s_height;
//printf("%d %d w=%d h=%d\n", x, y, w, h);

	for (y0 = y; y0 < y + h; y0++) {
		if (y0 - y >= (int) img->height)
			break;

	        scrp->s_location = 
		    	(y0+scrp->s_yoffset) * scrp->s_line_length +
			(x+scrp->s_xoffset) * (scrp->s_bpp/8);

		unsigned char *data = &img_data[((y0-y) * img->width + x) * 3];
	        for (x0 = x; x0 < x + w; x0++) {
		    if (x0 - x >= (int) img->width || x0 >= (int) scrp->s_width) {
			break;
		    }
		    if (scrp->s_location >= scrp->s_screensize) {
	//	    	printf("loc=0x%04x screensize=%04x\n", scrp->s_location, screensize);
		    	break;
		    }

		    put_pixel(scrp, data[0], data[1], data[2]);
		    data += 3;

	        }
	}
	update_image();
}

void
close_framebuffer(screen_t *scrp)
{
	update_image();

	munmap(scrp->s_mem, scrp->s_screensize);
	free(scrp);
}
/**********************************************************************/
/*   Open  the  frame  buffer, and memory map it. User can specify a  */
/*   virtual frame buffer via "-framebuffer <fname>"		      */
/**********************************************************************/
screen_t *
open_framebuffer()
{	char	*fbname = "/dev/fb0";
	screen_t *scrp = calloc(sizeof(screen_t), 1);
	struct fb_var_screeninfo vinfo;
	struct fb_fix_screeninfo finfo;
	int	fbfd;

	if (framebuffer_name) {
		struct stat sbuf;
		char	*cp;

		if ((fbfd = open(framebuffer_name, O_RDWR | O_CREAT, 0644)) < 0) {
			perror(framebuffer_name);
			exit(1);
		}
		if (fstat(fbfd, &sbuf) < 0) {
			perror("fstat");
			exit(1);
		}
		scrp->s_width = framebuffer_w;
		scrp->s_height = framebuffer_h;
		scrp->s_bpp = 32;
		scrp->s_screensize = scrp->s_width * scrp->s_height * scrp->s_bpp / 8;
		scrp->s_line_length = scrp->s_bpp / 8 * scrp->s_width;
		if (sbuf.st_size < scrp->s_screensize) {
			int	ret;
			fb_info_t f;

			memset(&f, 0, sizeof f);
			f.f_width = scrp->s_width;
			f.f_height = scrp->s_height;
			f.f_bpp = scrp->s_bpp;

			cp = calloc(scrp->s_screensize, 1);
			if ((ret = write(fbfd, cp, scrp->s_screensize)) != scrp->s_screensize) {
				fprintf(stderr, "write error - wrote %d, returned %d\n", scrp->s_screensize, ret);
				exit(1);
			}
			if ((ret = write(fbfd, &f, sizeof f)) != sizeof f) {
				fprintf(stderr, "write error (info) - wrote %ld, returned %d\n", sizeof f, ret);
				exit(1);
			}
			free(cp);
		}
		scrp->s_mem = (char *)mmap(0, scrp->s_screensize + sizeof(fb_info_t), 
			PROT_READ | PROT_WRITE, MAP_SHARED, fbfd, 0);
		scrp->s_info = (fb_info_t *) (scrp->s_mem + scrp->s_screensize);
		if (scrp->s_mem == (char *) -1) {
			printf("Error: failed to map framebuffer device to memory.\n");
			exit(1);
		}
		close(fbfd);
		return scrp;
	}

	fbfd = open(fbname, O_RDWR);
	if (fbfd == -1) {
		fprintf(stderr, "Error opening %s - %s\n",
			fbname, strerror(errno));
		exit(1);
	}

	// Get fixed screen information
	if (ioctl(fbfd, FBIOGET_FSCREENINFO, &finfo)) {
		fprintf(stderr, "%s: Error reading fixed information.\n", fbname);
		exit(1);
	}

	// Get variable screen information
	if (ioctl(fbfd, FBIOGET_VSCREENINFO, &vinfo)) {
		fprintf(stderr, "%s: Error reading variable information.\n", fbname);
		exit(1);
	}

	scrp->s_location = 0;
	scrp->s_line_length = finfo.line_length;
	scrp->s_width = vinfo.xres;
	scrp->s_height = vinfo.yres;
	scrp->s_bpp = vinfo.bits_per_pixel;
	scrp->s_yoffset = vinfo.yoffset;
	scrp->s_xoffset = vinfo.xoffset;
	// Figure out the size of the screen in bytes
	scrp->s_screensize = scrp->s_width * scrp->s_height * vinfo.bits_per_pixel / 8;

	// Map the device to memory
	scrp->s_mem = (char *)mmap(0, scrp->s_screensize, PROT_READ | PROT_WRITE, MAP_SHARED, fbfd, 0);
	if (scrp->s_mem == (char *) -1) {
		printf("Error: failed to map framebuffer device to memory.\n");
		exit(1);
	}
	close(fbfd);

	return scrp;
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

	filenames_list = names;
	num_filenames = n;
	do_free_filenames = 1;
}

void
shrink_display(screen_t *scrp, struct imgRawImage *img)
{
	int	x, y;
	float xfrac = 1;
	float yfrac = 1;
	int	width = img->width;

	int vwidth = w_arg < (int) scrp->s_width ? w_arg : (int) scrp->s_width;
	int vheight = h_arg < (int) scrp->s_height ? h_arg : (int) scrp->s_height;

	xfrac = img->width / (float) vwidth;
	yfrac = img->height / (float) vheight;

//printf("%f %f imgw=%d imgh=%d vw=%d vh=%d\n", xfrac, yfrac, img->width, img->height, vwidth, vheight);
//printf("frac=%f %f [img: %dx%d] %d,%d\n", xfrac, yfrac, img->width, img->height, x_arg, y_arg);
//printf("x0=%d xfrac=%.2f yfrac=%.2f\n", x0, xfrac, yfrac);

	for (y = 0; y < vheight; y++) {
		int loc_end;

		if (y_arg + scrp->s_yoffset > (int) scrp->s_height)
			break;

	        scrp->s_location = (y_arg + scrp->s_yoffset + y) * scrp->s_line_length +
			(x_arg + scrp->s_xoffset) * (scrp->s_bpp / 8);
	        loc_end = (y_arg + scrp->s_yoffset + y + 1) * scrp->s_line_length;
		for (x = 0; x < vwidth; x++) {
			if (scrp->s_location >= loc_end || scrp->s_location >= scrp->s_screensize)
				break; 
			if (x * xfrac > width)
				put_pixel(scrp, 0, 0, 0);
			else {
				unsigned char *data = &img->lpData[
					(int) (y * yfrac) * img->width * 3 +
					(int) (x * xfrac) * 3];

				put_pixel(scrp, data[0], data[1], data[2]);
			}
		}
	}
	update_image();
}

void
stretch_display(screen_t *scrp, struct imgRawImage *img)
{
	int	x, y;
	float xfrac = 1;
	float yfrac = 1;
	int	width = img->width;

	xfrac = scrp->s_width / (float) img->width;
	yfrac = scrp->s_height / (float) img->height;
	xfrac = yfrac;
	width *= xfrac;

	int	x0 = (scrp->s_width - width) / 2;
//printf("frac=%f %f\n", xfrac, yfrac);
//printf("x0=%d xfrac=%.2f yfrac=%.2f\n", x0, xfrac, yfrac);

	for (y = 0; y < (int) scrp->s_height; y++) {
	        scrp->s_location = (scrp->s_yoffset + y) * scrp->s_line_length +
			scrp->s_xoffset * (scrp->s_bpp / 8);
		for (x = 0; x < (int) scrp->s_width; x++) {
			if (x < x0 || x > x0 + width)
				put_pixel(scrp, 0, 0, 0);
			else {
				unsigned char *data = &img->lpData[
					(int) (y / yfrac) * img->width * 3 +
					(int) ((x - x0) / xfrac) * 3];

				put_pixel(scrp, data[0], data[1], data[2]);
			}
		}
	}
	update_image();
}

void
put_pixel(screen_t *scrp, int r, int g, int b)
{	char *fbp = scrp->s_mem;

	if ( scrp->s_bpp == 32 ) {
		*(fbp + scrp->s_location) = b;
		*(fbp + scrp->s_location + 1) = g;
		*(fbp + scrp->s_location + 2) = r;
		*(fbp + scrp->s_location + 3) = 0;      // No transparency
		scrp->s_location += 4;
	} else {
		/***********************************************/
		/*   Really  need to look at the rgb ordering  */
		/*   in vinfo				       */
		/***********************************************/
		unsigned short int t = 
			((r >> 3) <<11) | 
			(((g >> 2) & 0x3f) << 5) | 
			((b >> 3) & 0x1f);
		*((unsigned short int*)(fbp + scrp->s_location)) = t;
		scrp->s_location += 2;
	}
}

void
update_image()
{
	if (scrp->s_info) scrp->s_info->f_seq++;
}
void
usage()
{	extern const char *usage_text;

	fprintf(stderr, "%s", usage_text);
	exit(1);
}
