struct imgRawImage {
	unsigned int	numComponents;
	unsigned long	width;
	unsigned long	height;
	unsigned char	*lpData;
	};
struct imgRawImage* loadJpegImageFile(char* lpFilename);
struct imgRawImage* read_png_file(char *lpFilename);

enum ctypes { C_NONE, C_DELAY, C_EXIT };

typedef struct cmd_t {
	int	type;
	int	x, y, w, h;
	int	radius;
	unsigned long rgb;
	} cmd_t;

int	draw_circle(cmd_t *);
int	draw_rectangle(cmd_t *);
void put_pixel(char *fbp, int r, int g, int b);

extern long location;
extern char *fbp;
extern struct fb_var_screeninfo vinfo;
extern struct fb_fix_screeninfo finfo;

