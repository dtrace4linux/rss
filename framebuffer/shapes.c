#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <search.h>
#include <ctype.h>
#include <cairo/cairo.h>
#include "fb.h"

# define set_location(x, y) \
	        scrp->s_location =  \
		    	(y+scrp->s_yoffset) * scrp->s_line_length + \
			(x+scrp->s_xoffset) * (scrp->s_bpp/8);
# define plot(x, y) do_plot(x, y, r, g, b)

void gfx_grid(struct imgRawImage *img);
void gfx_mono(struct imgRawImage *img);
void gfx_sepia(struct imgRawImage *img);

void compute_rect(cmd_t *cp)
{
	x_arg = eval(cp->raw_args[1]);
	y_arg = eval(cp->raw_args[2]);
	w_arg = eval(cp->raw_args[3]);
	h_arg = eval(cp->raw_args[4]);

	x_arg *= scrp->s_width / (float) swidth;
	y_arg *= scrp->s_height / (float) sheight;
	w_arg *= scrp->s_width / (float) swidth;
	h_arg *= scrp->s_height / (float) sheight;
}

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

	update_image();
}

int
draw_clear(cmd_t *cp)
{
	memset(scrp->s_mem, 0x00, scrp->s_screensize);
	update_image();
	return 0;
}

int
draw_dot(cmd_t *cp)
{
	int r = cp->rgb >> 16;
	int g = (cp->rgb >> 8) & 0xff;
	int b = (cp->rgb >> 0) & 0xff;

	plot(cp->x, cp->y);
	update_image();
}
int
draw_image(cmd_t *cp)
{	struct imgRawImage *img;
	char	*str;

	if ((img = next_image()) == NULL) {
		return 0;
		}

	compute_rect(cp);

	if ((str = get_attribute(cp, "random")) != NULL) {
		str = parse_percentage(str);
		if (str && strcmp(str, "grid") == 0)
			gfx_grid(img);
		if (str && strcmp(str, "mono") == 0)
			gfx_mono(img);
		if (str && strcmp(str, "sepia") == 0)
			gfx_sepia(img);
//		printf("got a random - %s\n", str);
		if (str)
			free(str);
	}
	if (has_attribute(cp, "grid")) {
		gfx_grid(img);
	}
	if (has_attribute(cp, "mono")) {
		gfx_mono(img);
	}
	if (has_attribute(cp, "sepia")) {
		gfx_sepia(img);
	}

	if (has_attribute(cp, "animate")) {
		int	i, t;
		int	x1, y1;

		x_arg = (scrp->s_width - img->width) / 2;
		y_arg = (scrp->s_height - img->height) / 2;

		for (t = 0; t < 10; t++) {
			x1 = get_rand(5);
			y1 = get_rand(5);
			if (get_rand(2) == 0) x1 = -x1;
			if (get_rand(2) == 0) y1 = -y1;

			for (i = 0; i < 10; i++) {
				x_arg += x1;
				y_arg += y1;
				if (x_arg < 0) x_arg = 0;
				if (y_arg < 0) y_arg = 0;
				if (x_arg + img->width > scrp->s_width)
					x_arg = scrp->s_width - img->width;
				if (y_arg + img->height > scrp->s_height)
					y_arg = scrp->s_height - img->height;
				memset(scrp->s_mem, 0x00, scrp->s_screensize);
				shrink_display(scrp, img);
				do_sleep(200);
			}
		}
	} else {
		shrink_display(scrp, img);
	}
	free_image(img);
	return 1;
}
void
draw__line(cmd_t *cp, int x1, int y1, int x2, int y2)
{
	cp->x = x1;
	cp->y = y1;
	cp->x1 = x2;
	cp->y1 = y2;
	draw_line(cp);

	update_image();
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
	update_image();
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
	update_image();
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
	update_image();
	return 0;
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
	update_image();
	return 0;
}

int
draw_text(cmd_t *cp)
{
 	cairo_surface_t *surface;
	cairo_t *cr;
	cairo_text_extents_t te;
	int i, j;
	int	x, y;
	
	int r = cp->rgb >> 16;
	int g = (cp->rgb >> 8) & 0xff;
	int b = (cp->rgb >> 0) & 0xff;

	compute_rect(cp);

	surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 
		w_arg, h_arg);
	cr = cairo_create(surface);
	cairo_set_source_rgb(cr, r, g, b);

	cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL,
		CAIRO_FONT_WEIGHT_NORMAL);
	cairo_set_font_size(cr, 40.0);

	x = 10;
	y = 50;
	int x0 = x;

	for (i = 6; i < cp->argc; i++) {
		char *str = cp->raw_args[i];
printf("cairo: %s\n", str);
		cairo_text_extents(cr, str, &te);
		if (x + te.width > w_arg) {
			x = x0;
			y += te.height;
		}

		cairo_move_to(cr, x, y);
		cairo_show_text(cr, str);
		x += te.width;
		cairo_text_extents(cr, "n", &te);
		x += te.width;
		cairo_move_to(cr, x, y);
	}

	unsigned char *data = cairo_image_surface_get_data (surface);
	int width = cairo_image_surface_get_width(surface);
	int height = cairo_image_surface_get_height(surface);
	int stride = cairo_image_surface_get_stride(surface);
	int	pixel_size = 4;

	for (i = 0; i < height; i++) {
		unsigned char *row = data + i * stride;
		for (int j = 0; j < width; j++) {
			int r = *row++;
			int g = *row++;
			int b = *row++;
			plot(x_arg + j, y_arg + i);
			row ++;

		// do something with the pixel at (i, j), which lies at row + j * (pixel size),
		// based on the result of cairo_image_get_format and platform endian-ness
		}
	}

	cairo_destroy(cr);
	cairo_surface_destroy(surface);

	update_image();
	return 0;
}

void
gfx_grid(struct imgRawImage *img)
{	unsigned x, y;
	int	n = 20;

	for (y = 0; y < img->height; y += n) {
		unsigned char *sp = &img->lpData[y * img->width * 3];
		memset(sp, 0, 3 * img->width);
	}

	for (y = 0; y < img->height; y++) {
		unsigned char *sp = &img->lpData[y * img->width * 3];
		for (x = 0; x < img->width; x += n) {
			sp[0] = 0;
			sp[1] = 0;
			sp[2] = 0;
			sp += 3 * n;
		}
	}
}

void
gfx_mono(struct imgRawImage *img)
{	unsigned x, y;

	for (y = 0; y < img->height; y++) {
		unsigned char *sp = &img->lpData[y * img->width * 3];
		for (x = 0; x < img->width; x++) {
			unsigned long r = sp[1];
			sp[0] = r;
			sp[1] = r;
			sp[2] = r;
			sp += 3;
		}
	}
}
void
gfx_sepia(struct imgRawImage *img)
{	unsigned x, y;

	for (y = 0; y < img->height; y++) {
		unsigned char *sp = &img->lpData[y * img->width * 3];
		for (x = 0; x < img->width; x++) {
			int r = sp[0];
			int g = sp[1];
			int b = sp[2];

			int r1 = (r * 0.393 + g * 0.769 + 0.189);
			int g1 = (r * 0.349 + g * 0.686 + 0.168);
			int b1 = (r * 0.272 + g * 0.534 + 0.131);
			if (r1 > 255) r1 = 255;
			if (g1 > 255) g1 = 255;
			if (b1 > 255) b1 = 255;
			sp[0] = r1;
			sp[1] = g1;
			sp[2] = b1;
			sp += 3;
		}
	}
}

