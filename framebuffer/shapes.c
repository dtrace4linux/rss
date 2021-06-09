#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <linux/fb.h>
#include "fb.h"

# define set_location(x, y) \
	        scrp->s_location =  \
		    	(y+scrp->s_yoffset) * scrp->s_line_length + \
			(x+scrp->s_xoffset) * (scrp->s_bpp/8);
# define plot(x, y) do_plot(x, y, r, g, b)

static void
do_plot(int x, int y, int r, int g, int b)
{
	if (x < 0 || y < 0 || x >= (int) scrp->s_width || y >= (int) scrp->s_height)
		return;

        scrp->s_location = 
	    	(y+scrp->s_yoffset) * scrp->s_line_length +
		(x+scrp->s_xoffset) * (scrp->s_bpp/8);
	put_pixel(scrp, r, g, b);
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
draw_clear(cmd_t *cp)
{
	memset(scrp->s_mem, 0x00, scrp->s_screensize);
	return 0;
}

int
draw_dot(cmd_t *cp)
{
	int r = cp->rgb >> 16;
	int g = (cp->rgb >> 8) & 0xff;
	int b = (cp->rgb >> 0) & 0xff;

	plot(cp->x, cp->y);
}

void
draw__line(cmd_t *cp, int x1, int y1, int x2, int y2)
{
	cp->x = x1;
	cp->y = y1;
	cp->x1 = x2;
	cp->y1 = y2;
	draw_line(cp);
}
int
draw_filled_circle(cmd_t *cp)
{

	int	x0 = cp->x;
	int	y0 = cp->y;

	int	d = 3 - (2 * cp->radius);
	int x = 0;
	int y = cp->radius;

	while (x <= y) {
		draw__line(cp, x0 + x, y0 + y, x0 + y, y0 + x);
		draw__line(cp, x0 - x, y0 + y, x0 + y, y0 - x);
		draw__line(cp, x0 - x, y0 - y, x0 - y, y0 - x);
		draw__line(cp, x0 + x, y0 - y, x0 - y, y0 + x);
		if (d < 0)
			d += 4 * x + 6;
		else {
			d += 4*(x-y) + 10;
			y--;
		}
		x++;
	}
}

int
draw_filled_rectangle(cmd_t *cp)
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
	return 0;
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
		if (y == cp->y || y == cp->y + cp->h -1) {
			for (x = cp->x; x < cp->x + cp->w; x++) {
				do_plot(x, y, r, g, b);
			}
		} else {
			do_plot(cp->x, y, r, g, b);
			do_plot(cp->x + cp->w - 1, y, r, g, b);
		}
	}
}

