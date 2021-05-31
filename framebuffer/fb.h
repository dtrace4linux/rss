struct imgRawImage {
	unsigned int	numComponents;
	unsigned long	width;
	unsigned long	height;
	unsigned char	*lpData;
	};
struct imgRawImage* loadJpegImageFile(char* lpFilename);
struct imgRawImage* read_png_file(char *lpFilename);

enum ctypes { 
	C_NONE, 
	C_CIRCLE, 
	C_CLEAR, 
	C_DELAY, 
	C_DOT, 
	C_DRAW,
	C_EXIT, 
	C_FILLED_CIRCLE, 
	C_FILLED_RECTANGLE, 
	C_LINE, 
	C_NUMBER, 
	C_RECTANGLE, 
	C_REPEAT, 
	C_SCREENSIZE, 
	C_SLEEP,
	 };
# define MAX_ARGS 16

typedef struct cmd_t {
	int	type;
	int	x, y, w, h;
	int	x1, y1;
	int	count;
	int	radius;
	unsigned long rgb;
	int	argc;
	char	*raw_args[MAX_ARGS];
	int	args[MAX_ARGS];
	} cmd_t;

int	draw_circle(cmd_t *);
int	draw_filled_circle(cmd_t *);
int	draw_clear(cmd_t *);
int	draw_dot(cmd_t *);
int	draw_filled_rectangle(cmd_t *);
int	draw_line(cmd_t *);
int	draw_rectangle(cmd_t *);
void put_pixel(char *fbp, int r, int g, int b);

extern long location;
extern char *fbp;
extern struct fb_var_screeninfo vinfo;
extern struct fb_fix_screeninfo finfo;
extern int v_flag;
extern long delay;
extern int num;
extern long screensize;
extern char *script_file;
