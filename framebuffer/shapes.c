#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <linux/fb.h>
#include "fb.h"

extern char *fbp;

# define set_location(x, y) \
	        location =  \
		    	(y+vinfo.yoffset) * finfo.line_length + \
			(x+vinfo.xoffset) * (vinfo.bits_per_pixel/8);

static void
do_plot(int x, int y, int r, int g, int b)
{
	if (x < 0 || y < 0 || x >= (int) vinfo.xres || y >= (int) vinfo.yres)
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
	int b = (cp->rgb >> 0) & 0xff;

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
draw_line(cmd_t *cp)
{	int	x, y;

	int x0 = cp->x;
	int x1 = cp->x1;
	int y0 = cp->y;
	int y1 = cp->y1;

	int r = (cp->rgb >> 16) & 0xff;
	int g = (cp->rgb >> 8) & 0xff;
	int b = (cp->rgb >> 0) & 0xff;

	int dx = abs(x1-x0), sx = x0<x1 ? 1 : -1;
	int dy = abs(y1-y0), sy = y0<y1 ? 1 : -1; 
	int err = (dx>dy ? dx : -dy)/2, e2;

	for(;;) {
		plot(x0,y0);
		if (x0==x1 && y0==y1) break;
		e2 = err;
		if (e2 >-dx) { err -= dy; x0 += sx; }
		if (e2 < dy) { err += dx; y0 += sy; }
	}
}

int
draw_rectangle(cmd_t *cp)
{	int	x, y;

	int r = cp->rgb >> 16;
	int g = (cp->rgb >> 8) & 0xff;
	int b = (cp->rgb >> 0) & 0xff;

	for (y = cp->y; y < cp->y + cp->h; y++) {
		set_location(cp->x, y);
		for (x = cp->x; x < cp->x + cp->w; x++) {
			do_plot(x, y, r, g, b);
		}
	}
}

