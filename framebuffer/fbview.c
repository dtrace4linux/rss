/**********************************************************************/
/*   View a virtual frame buffer, in real time, so we can do console  */
/*   debugging from inside X windows.				      */
/**********************************************************************/

#include     <stdio.h>
#include     <stdlib.h>
#include     <string.h>
#include     <unistd.h>
#include     <fcntl.h>
#include     <stdlib.h>
#include     <sys/types.h>
#include     <sys/stat.h>
#include     <sys/mman.h>
#include     <X11/Xlib.h>
# include "fb.h"

Display *display;
Window	window;
XImage *ximage;

char	*fb;
fb_info_t *info;
int	screensize;
int width=512, height=512;
int	img_width;
int	img_height;

/**********************************************************************/
/*   Prototypes.						      */
/**********************************************************************/
void XPutPixel(XImage *, int, int, unsigned long);
int	XDestroyImage(XImage *);
void	usage();
void	redraw_buffer();

int
do_switches(int argc, char **argv)
{	int	i;
	char	*cp;

	for (i = 1; i < argc; i++) {
		cp = argv[i];
		if (*cp++ != 'i')
			break;
		if (strcmp(cp, "height") == 0) {
			if (++i >= argc)
				usage();
			height = atoi(argv[i]);
			continue;
		}
		if (strcmp(cp, "width") == 0) {
			if (++i >= argc)
				usage();
			width = atoi(argv[i]);
			continue;
		}
	}
	return i;
}

void
open_image(char *fn)
{	struct stat sbuf;
	int	fd;

	if ((fd = open(fn, O_RDONLY)) < 0) {
		perror(fn);
		exit(1);
	}
	fstat(fd, &sbuf);
	screensize = sbuf.st_size;
	screensize -= sizeof(*info);
	fb = (char *)mmap(0, sbuf.st_size, PROT_READ, MAP_SHARED, fd, 0);
	if (fb == (char *) -1) {
		fprintf(stderr, "Couldnt mmap file into memory, size %ld\n", sbuf.st_size);
		exit(1);
	}
	info = (fb_info_t *) (fb + screensize);
	img_width = info->f_width;
	img_height = info->f_height;
	width = img_width / 2;
	height = img_height / 2;
	close(fd);
}

XImage *
create_image(Display *display, int width, int height)
{
    unsigned char *image32 = (unsigned char *)calloc(width*height*4, 1);

    return XCreateImage(display, 
	DefaultVisual(display, 0),
    	DefaultDepth(display,DefaultScreen(display)), 
    	ZPixmap, 0, image32, width, height, 32, 0);
}

void
expose_image(Display *display, Window window, XEvent *ev)
{	int	x, y;
	unsigned char *sp;
	int	bpp = 4;
	int	ymax = ev->xexpose.y + ev->xexpose.height;
	double	xf = (double) width / img_width;
	double	yf = (double) height / img_height;
	int	yp = -1;

	if (height < ymax)
		ymax = height;
	for (y = 0; y < img_height; y++) {
		unsigned char *rowp = &fb[y * img_width * bpp];
		for (x = 0; x < img_width; x++) {
			sp = rowp + x * bpp;
			unsigned long p = (sp[2] << 16) | (sp[1] << 8) | sp[0];
			XPutPixel(ximage, x * xf, y * yf, p);
		}
	}

        XPutImage(display, window, DefaultGC(display, 0), ximage, 
		ev->xexpose.x, ev->xexpose.y, 
		ev->xexpose.x, ev->xexpose.y, 
		ev->xexpose.width, ev->xexpose.height);
}

void processEvent(Display *display, Window window)
{
	XEvent ev;
	XNextEvent(display, &ev);

	switch(ev.type) {
	case Expose:
    		expose_image(display, window, &ev);
	        break;
	    case ButtonPress:
	    	redraw_buffer();
	        break;
	    case ConfigureNotify:
	    	XDestroyImage(ximage);
		width = ev.xconfigure.width;
		height = ev.xconfigure.height;

		ximage = create_image(display, width, height);

	    	printf("resize %d,%d %dx%d\n",
			ev.xconfigure.x,
			ev.xconfigure.y,
			ev.xconfigure.width,
			ev.xconfigure.height
			);
		redraw_buffer();
	    	break;
	    default:
	//    	printf("event %d\n", ev.type);
		break;
	}
}

int main(int argc, char **argv)
{
	int	arg_index = do_switches(argc, argv);

	display=XOpenDisplay(NULL);
	Visual *visual=DefaultVisual(display, 0);
	
	if (arg_index >= argc)
		usage();

	open_image(argv[arg_index++]);

	window=XCreateSimpleWindow(display, RootWindow(display, 0), 0, 0, width, height, 1, 0, 0);
	if(visual->class!=TrueColor) {
		fprintf(stderr, "Cannot handle non true color visual ...\n");
		exit(1);
	}

	XSetWindowAttributes set_attr;

	set_attr.win_gravity = NorthWestGravity;
	set_attr.bit_gravity = NorthWestGravity;
	XChangeWindowAttributes(display, window, CWBitGravity | CWWinGravity, &set_attr);

	ximage = create_image(display, width, height);
	XSelectInput(display, window, 
		StructureNotifyMask|ButtonPressMask|ExposureMask);
	XMapWindow(display, window);
	while (1) {
		struct timeval tval = {0, 50 * 1000};
		if (XPending(display) > 0) {
			processEvent(display, window);
			continue;
		} else {
			static unsigned long last_seq;
			if (info->f_seq != last_seq) {
				last_seq = info->f_seq;
				redraw_buffer();
				if (write(1, ".", 1) != 1)
					exit(0);
			}
		}
		select(0, NULL, NULL, NULL, &tval);
	}
}

void
redraw_buffer()
{	XEvent ev;

    	ev.xexpose.x = 0;
    	ev.xexpose.y = 0;
    	ev.xexpose.width  = width;
    	ev.xexpose.height= height;
    	expose_image(display, window, &ev);
}

void
usage()
{
	printf("xlib -- tool to display virtual image buffer inside X desktop\n");
	printf("usage: xlib [switches] filename\n");
	printf("\n");
	printf("Options:\n");
	printf("\n");
	printf("  -width NN      Set default image width\n");
	printf("  -height NN      Set default image height\n");
	exit(1);
}
