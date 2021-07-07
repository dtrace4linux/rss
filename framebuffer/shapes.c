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
{	char	*str;
	int	montage = 0;

	x_arg = eval(cp->raw_args[1]);
	y_arg = eval(cp->raw_args[2]);
	w_arg = eval(cp->raw_args[3]);
	h_arg = eval(cp->raw_args[4]);

	if ((str = get_attribute(cp, "montage")) != NULL) {
		montage = parse_value(str);
	}
	if (montage) {
		compute_montage(scrp, 0);
	}

	x_arg *= scrp->s_width / (float) swidth;
	y_arg *= scrp->s_height / (float) sheight;
	w_arg *= scrp->s_width / (float) swidth;
	h_arg *= scrp->s_height / (float) sheight;

	cp->x = x_arg;
	cp->y = y_arg;
	cp->w = w_arg;
	cp->h = h_arg;
}

static unsigned long
do_gradient(cmd_t *cp, unsigned long start, unsigned long end, double n)
{
	int r = (start >> 16) & 0xff;
	int g = (start >> 8) & 0xff;
	int b = (start >> 0) & 0xff;

	int r1 = (end >> 16) & 0xff;
	int g1 = (end >> 8) & 0xff;
	int b1 = (end >> 0) & 0xff;

	r = (int) (r1 + (r - r1) * n) & 0xff;
	g = (int) (g1 + (g - g1) * n) & 0xff;
	b = (int) (b1 + (b - b1) * n) & 0xff;

	unsigned long p = (r << 16) | (g << 8) | (b << 0);
//printf("grad %02x %02x %02x - %02x %02x %02x %f -> 0x%lx\n", r, g, b, r1, g1, b1, n, p);
	return p;
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
		int	old_x = 0;
		int	old_y = 0;

		if (scrp->s_width > img->width) {
			x_arg = (scrp->s_width - img->width) / 2;
			y_arg = (scrp->s_height - img->height) / 2;
		} else {
			x_arg = (img->width - scrp->s_width) / 2;
			y_arg = (img->height - scrp->s_height) / 2;
		}

		for (t = 0; t < 10; t++) {
			x1 = get_rand(5);
			y1 = get_rand(5);
			if (x1 > 0 && get_rand(2) == 0) x1 = -x1;
			if (y1 > 0 && get_rand(2) == 0) y1 = -y1;

			for (i = 0; i < 20; i++) {
				x_arg += x1;
				y_arg += y1;
/*				if (x_arg < 0) 
					x_arg = 0;
				else if (x_arg + img->width > scrp->s_width)
					x_arg = scrp->s_width - img->width;
				if (y_arg < 0) 
					y_arg = 0;
				else if (y_arg + img->height > scrp->s_height)
					y_arg = scrp->s_height - img->height;
*/
//				memset(scrp->s_mem, 0x00, scrp->s_screensize);

				/***********************************************/
				/*   Need  to  erase the delta image to avoid  */
				/*   bleeding				       */
				/***********************************************/
				cmd_t cp1;
				memset(&cp1, 0, sizeof cp1);
				if (y_arg > old_y) {
					cp1.x = old_x;
					cp1.y = old_y;
					cp1.w = w_arg;
					cp1.h = y_arg - old_y;
					draw_filled_rectangle(&cp1);
				}

				if (y1 < 0) {
					cp1.x = old_x;
					cp1.y = old_y + w_arg - y1;
					cp1.w = w_arg;
					cp1.h = -y1;
					draw_filled_rectangle(&cp1);
				}
				if (x1 > 0) {
					cp1.x = old_x;
					cp1.y = old_y;
					cp1.w = x1;
					cp1.h = h_arg;
					draw_filled_rectangle(&cp1);
				}
				if (x1 < 0) {
					cp1.x = old_x + w_arg + x1;
					cp1.y = old_y;
					cp1.w = -x1;
					cp1.h = h_arg;
					draw_filled_rectangle(&cp1);
				}

				/***********************************************/
				/*   Now  we  can  draw the new image without  */
				/*   flicker				       */
				/***********************************************/
				shrink_display(scrp, img);

				old_x = x_arg;
				old_y = y_arg;

				do_sleep(100);
			}
		}
	} else {
		shrink_display(scrp, img);
	}
	free_image(img);
	return 1;
}

int
draw_image_list(cmd_t *cp)
{
	while (draw_image(cp) == 1) {
		update_image();

		if (time_limit_exceeded())
			break;
	}

	update_image();

	return 0;
}

static void
draw__line(cmd_t *cp, int x1, int y1, int w)
{	int	x = cp->x;
	int	y = cp->y;
	int	x1_save = cp->x1;
	int	y1_save = cp->y1;

	cp->x = x1;
	cp->y = y1;
	cp->x1 = x1 + w;
	cp->y1 = y1;
	draw_line(cp);

	cp->x = x;
	cp->y = y;
	cp->x1 = x1_save;
	cp->y1 = y1_save;
}

// https://dai.fmph.uniba.sk/upload/0/01/Ellipse.pdf
// ellipse(x, y, xradius, yradius)
int
draw_ellipse(cmd_t *cp)
{	char	*str;
	unsigned long start = cp->rgb;
	unsigned long end = cp->rgb;
	int	has_grad = 0;

	compute_rect(cp);

	if ((str = get_attribute(cp, "gradient")) != NULL) {
		parse_gradient(str, &start, &end);
		has_grad = 1;
	}

	cp->rgb = cp->args[5];
	int r = cp->rgb >> 16;
	int g = (cp->rgb >> 8) & 0xff;
	int b = (cp->rgb >> 0) & 0xff;

	long xradius = cp->w;
	long yradius = cp->h;

	long TwoASquare = 2 * xradius * xradius;
	long TwoBSquare = 2 * yradius * yradius;
	long x = xradius;
	long y = 0;
	long XChange = yradius * yradius * (1 - 2 * xradius);
	long YChange = xradius * xradius;
	long ellipse_error = 0;
	long stopping_x = TwoBSquare * xradius;
	long stopping_y = 0;

	while (stopping_x >= stopping_y) {
//printf("plot %ld %ld %02x%02x%02x\n", cp->x+x, cp->y+y, r, g, b);
		if (cp->type == C_FILLED_ELLIPSE) {
			draw__line(cp, cp->x-x, cp->y-y, 2 * x);
			draw__line(cp, cp->x-x, cp->y+y, 2 * x);
		} else {
			plot(cp->x + x, cp->y + y);
			plot(cp->x - x, cp->y + y);
			plot(cp->x - x, cp->y - y);
			plot(cp->x + x, cp->y - y);
		}

		y++;
		stopping_y += TwoASquare;
		ellipse_error += YChange;
		YChange += TwoASquare;
		if (2 * ellipse_error + XChange > 0) {
			x--;
			stopping_x -= TwoBSquare;
			ellipse_error += XChange;
			XChange += TwoBSquare;
		}
	}

	// 1st point set is done; start the 2nd set of points
	x = 0;
	y = yradius;
	XChange = yradius * yradius;
	YChange = xradius * xradius * (1 - 2 * yradius);
	ellipse_error = 0;
	stopping_x = 0;
	stopping_y = TwoASquare * yradius;
	while (stopping_x <= stopping_y) {
//printf("plot2 %ld %ld %02x%02x%02x\n", cp->x+x, cp->y+y, r, g, b);
		if (cp->type == C_FILLED_ELLIPSE) {
			draw__line(cp, cp->x-x, cp->y-y, 2 * x);
			draw__line(cp, cp->x-x, cp->y+y, 2 * x);
		} else {
			plot(cp->x + x, cp->y + y);
			plot(cp->x - x, cp->y + y);
			plot(cp->x - x, cp->y - y);
			plot(cp->x + x, cp->y - y);
		}

		x++;
		stopping_x += TwoBSquare;
		ellipse_error += XChange;
		XChange += TwoBSquare;
		if (2 * ellipse_error + YChange > 0) {
			y--;
			stopping_y -= TwoASquare;
			ellipse_error += YChange;
			YChange += TwoASquare;
		}
	}

	return 0;
}

int
draw_filled_circle(cmd_t *cp)
{	char	*str;
	unsigned long start = cp->rgb;
	unsigned long end = cp->rgb;
	int	has_grad = 0;
	int	grad_type = 0;

	if (cp->radius <= 0)
		return 0;

	int	xp = cp->x;
	int	yp = cp->y;

	int xoff = 0;
	int yoff = cp->radius;
	int balance = -cp->radius;

	if ((str = get_attribute(cp, "gradient")) != NULL) {
		parse_gradient(str, &start, &end);
		has_grad = 1;
//printf("strat=%lx %lx\n", start, end);
	}

int n = 0;
	while (xoff <= yoff) {
		int p0 = xp - xoff;
		int p1 = xp - yoff;

		int w0 = xoff + xoff;
		int w1 = yoff + yoff;

		if (has_grad) {
//			double f = (xoff - xp) / ((double) cp->radius * 2);
//			double f = (double) n++ / cp->radius;
			double f = (double) p0 / cp->radius;
//printf("%d) f=%f %d %d %d\n", n++, f, p0, xoff, yoff);
			cp->rgb = do_gradient(cp, start, end, f);
		}

		draw__line(cp, p0, yp + yoff, w0);
	      	draw__line(cp, p0, yp - yoff, w0);
		draw__line(cp, p1, yp + xoff, w1);
		draw__line(cp, p1, yp - xoff, w1);

		balance += xoff + 1 + xoff;
		xoff++;
		if (balance >= 0) {
			balance -= yoff-1 + yoff;
			yoff--;
		}
	}
	update_image();
}

int
draw_filled_rectangle(cmd_t *cp)
{	int	x, y;
	unsigned long start = cp->rgb;
	unsigned long end = cp->rgb;
	int	has_grad = 0;
	int	end_y;
	char	*str;

	if ((str = get_attribute(cp, "gradient")) != NULL) {
		parse_gradient(str, &start, &end);
		has_grad = 1;
//printf("strat=%lx %lx\n", start, end);
	}

	end_y = cp->y + cp->h;
	for (y = cp->y; y < end_y; y++) {
		if (has_grad) {
			cp->rgb = do_gradient(cp, start, end, 
				(double) (y - cp->y) / (end_y - cp->y));
		}

		int r = cp->rgb >> 16;
		int g = (cp->rgb >> 8) & 0xff;
		int b = (cp->rgb >> 0) & 0xff;

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
	cairo_font_extents_t fe;
	cairo_text_extents_t te;
	int i, j;
	int	x, y;
	int	has_alpha = 0;
	char	*str;
	
	int r = cp->rgb >> 16;
	int g = (cp->rgb >> 8) & 0xff;
	int b = (cp->rgb >> 0) & 0xff;

	if ((str = get_attribute(cp, "alpha")) != NULL) {
		has_alpha = 1;
	}

	compute_rect(cp);

	surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 
		w_arg, h_arg);
	cr = cairo_create(surface);
	cairo_set_source_rgb(cr, r, g, b);

	cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL,
		CAIRO_FONT_WEIGHT_NORMAL);
	cairo_set_font_size(cr, 40.0);
	cairo_font_extents (cr, &fe);

	x = scrp->s_txt_col;
	y = scrp->s_txt_row;
	int x0 = x;

	if ((str = get_value(cp, "text")) == NULL)
		str = strdup("no text specified");

	j = 0;
	while (str[j] && y < (int) scrp->s_height) {
		int start = j;
		int	skip_char = 1;
		int ch;

		if (str[j] == ' ') {
			j++;
			continue;
		}

		for (j = start; str[j]; j++) {
			if (str[j] == '\0' || str[j] == '\n' || str[j] == ' ')
				break;
		}
		ch = str[j];
		str[j] = '\0';

printf("cairo: '%s' start=%d j=%d x=%d y=%d\n", str + start, start, j, x, y);
		cairo_text_extents(cr, str + start, &te);
		if (x + te.width > x_arg + w_arg && start) {
			x = x0;
			y += fe.descent + te.height;
		}

		/***********************************************/
		/*   If word is still too long, need to split  */
		/*   a word.				       */
		/***********************************************/
		if (x + te.width >= x_arg + w_arg) {
			str[j] = ch;
printf("loop j=%d %f x_arg=%d, w_arg=%d\n", j, te.width, x_arg, w_arg);
			while (x + te.width >= x_arg + w_arg) {
				j--;
				ch = str[j];
				str[j] = '\0';
//printf("j=%d %f '%s'\n", j, te.width, str);
				cairo_text_extents(cr, str + start, &te);
				skip_char = 0;
			}
printf("       '%s' start=%d j=%d x=%d y=%d\n", str + start, start, j, x, y);
		}

		cairo_move_to(cr, x, y);
printf(" -> '%s'\n", str + start);
		cairo_show_text(cr, str + start);
		x += te.width;
		if (ch) {
			cairo_text_extents(cr, "n", &te);
			x += te.width;
		}
//		cairo_move_to(cr, x, y);

		str[j] = ch;
		if (skip_char)
			j++;
		if (ch == 0)
			break;
		if (ch == ' ') {
			continue;
		}

		x = x0;
		y += fe.descent + te.height;
	}
	free(str);

	unsigned char *data = cairo_image_surface_get_data (surface);
	int width = cairo_image_surface_get_width(surface);
	int height = cairo_image_surface_get_height(surface);
	int stride = cairo_image_surface_get_stride(surface);
	int	pixel_size = 4;

	for (i = 0; i < height; i++) {
		unsigned char *row = data + i * stride;
		for (int j = 0; j < width; j++) {
			int b = *row++;
			int g = *row++;
			int r = *row++;
			if (!has_alpha || b + g + r) {
				plot(x_arg + j, y_arg + i);
			}
			row ++;

		// do something with the pixel at (i, j), which lies at row + j * (pixel size),
		// based on the result of cairo_image_get_format and platform endian-ness
		}
	}

	cairo_destroy(cr);
	cairo_surface_destroy(surface);

	scrp->s_txt_row = y;
	scrp->s_txt_col = x;

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

