#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <linux/fb.h>
#include "fb.h"

extern char *fbp;

static void
do_plot(int x, int y, int r, int g, int b)
{
	if (x < 0 || y < 0 || x >= vinfo.xres || y >= vinfo.yres)
		return;

        location = 
	    	(y+vinfo.yoffset) * finfo.line_length +
		(x+vinfo.xoffset) * (vinfo.bits_per_pixel/8);
	put_pixel(fbp, r, g, b);
}

int
draw_circle(cmd_t *cp)
{
	int r = cp->rgb >> 16;
	int g = (cp->rgb >> 8) & 0xff;
	int b = (cp->rgb >> 0) & 0x00;

	int f = 1 - cp->radius;
	int ddF_x = 0;
	int ddF_y = -2 * cp->radius;
	int x = 0;
	int y = cp->radius;

# define plot(x, y) do_plot(x, y, r, g, b)

	plot(cp->x, cp->y + cp->radius);
	plot(cp->x, cp->y - cp->radius);
	plot(cp->x + cp->radius, cp->y);
	plot(cp->x - cp->radius, cp->y);

	while(x < y) {
		if(f >= 0) {
			y--;
			ddF_y += 2;
			f += ddF_y;
		}
	        x++;
	        ddF_x += 2;
	        f += ddF_x + 1;    
	        plot(cp->x + x, cp->y + y);
	        plot(cp->x - x, cp->y + y);
	        plot(cp->x + x, cp->y - y);
	        plot(cp->x - x, cp->y - y);
	        plot(cp->x + y, cp->y + x);
	        plot(cp->x - y, cp->y + x);
	        plot(cp->x + y, cp->y - x);
	        plot(cp->x - y, cp->y - x);
	}
}

int
draw_rectangle(cmd_t *cp)
{	int	x, y;

	int r = cp->rgb >> 16;
	int g = (cp->rgb >> 8) & 0xff;
	int b = (cp->rgb >> 0) & 0x00;

	for (y = cp->y; y < cp->y + cp->h; y++) {
	        location = 
		    	(y+vinfo.yoffset) * finfo.line_length +
			(cp->x+vinfo.xoffset) * (vinfo.bits_per_pixel/8);
		for (x = cp->x; x < cp->x + cp->w; x++) {
			put_pixel(fbp, r, g, b);
		}
	}
}


