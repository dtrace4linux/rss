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

XImage *CreateTrueColorImage(Display *display, Visual *visual, unsigned char *image, int width, int height)
{
    int i, j;
    unsigned char *image32=(unsigned char *)malloc(width*height*4);
    unsigned char *p=image32;
    for(i=0; i<width; i++)
    {
        for(j=0; j<height; j++)
        {
            if((i<256)&&(j<256))
            {
                *p++=rand()%256; // blue
                *p++=rand()%256; // green
                *p++=rand()%256; // red
            }
            else
            {
                *p++=i%256; // blue
                *p++=j%256; // green
                if(i<256)
                    *p++=i%256; // red
                else if(j<256)
                    *p++=j%256; // red
                else
                    *p++=(256-j)%256; // red
            }
            p++;
        }
    }
    return XCreateImage(display, visual, DefaultDepth(display,DefaultScreen(display)), ZPixmap, 0, image32, width, height, 32, 0);
}

void
expose_image(Display *display, Window window, XImage *ximage, XEvent *ev)
{	int	x, y;
	unsigned char *sp;
	int	bpp = 4;
	int	ymax = ev->xexpose.y + ev->xexpose.height;
	double	xf = (double) width / img_width;
	double	yf = (double) height / img_height;

	if (height < ymax)
		ymax = height;
	for (y = ev->xexpose.y; y < ymax; y++) {
		unsigned char *rowp = &fb[(int) ((y * img_width * yf) * bpp)];
		int	xmax = ev->xexpose.x + ev->xexpose.width;
		if (width < xmax)
			xmax = width;
		for (x = ev->xexpose.x; x < xmax; x++) {
			sp = rowp + (int) (x * xf * bpp);
			unsigned long p = (sp[2] << 16) | (sp[1] << 8) | sp[0];
			XPutPixel(ximage, x, y, p);
		}
	}
        XPutImage(display, window, DefaultGC(display, 0), ximage, 
		ev->xexpose.x, ev->xexpose.y, 
		ev->xexpose.x, ev->xexpose.y, 
		ev->xexpose.width, ev->xexpose.height);
}

void processEvent(Display *display, Window window, XImage *ximage, int width, int height)
{
    static char *tir="This is red";
    static char *tig="This is green";
    static char *tib="This is blue";
    XEvent ev;
    XNextEvent(display, &ev);
    switch(ev.type) {
    case Expose:
# if 1
    	expose_image(display, window, ximage, &ev);
# else
        XPutImage(display, window, DefaultGC(display, 0), ximage, 0, 0, 0, 0, width, height);
        XSetForeground(display, DefaultGC(display, 0), 0x00ff0000); // red
        XDrawString(display, window, DefaultGC(display, 0), 32,     32,     tir, strlen(tir));
        XDrawString(display, window, DefaultGC(display, 0), 32+256, 32,     tir, strlen(tir));
        XDrawString(display, window, DefaultGC(display, 0), 32+256, 32+256, tir, strlen(tir));
        XDrawString(display, window, DefaultGC(display, 0), 32,     32+256, tir, strlen(tir));
        XSetForeground(display, DefaultGC(display, 0), 0x0000ff00); // green
        XDrawString(display, window, DefaultGC(display, 0), 32,     52,     tig, strlen(tig));
        XDrawString(display, window, DefaultGC(display, 0), 32+256, 52,     tig, strlen(tig));
        XDrawString(display, window, DefaultGC(display, 0), 32+256, 52+256, tig, strlen(tig));
        XDrawString(display, window, DefaultGC(display, 0), 32,     52+256, tig, strlen(tig));
        XSetForeground(display, DefaultGC(display, 0), 0x000000ff); // blue
        XDrawString(display, window, DefaultGC(display, 0), 32,     72,     tib, strlen(tib));
        XDrawString(display, window, DefaultGC(display, 0), 32+256, 72,     tib, strlen(tib));
        XDrawString(display, window, DefaultGC(display, 0), 32+256, 72+256, tib, strlen(tib));
        XDrawString(display, window, DefaultGC(display, 0), 32,     72+256, tib, strlen(tib));
# endif
        break;
    case ButtonPress:
    	redraw_buffer();
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

	ximage=CreateTrueColorImage(display, visual, 0, width, height);
	XSelectInput(display, window, ButtonPressMask|ExposureMask);
	XMapWindow(display, window);
	while (1) {
		struct timeval tval = {0, 50 * 1000};
		if (XPending(display) > 0) {
			processEvent(display, window, ximage, width, height);
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
    	expose_image(display, window, ximage, &ev);
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
