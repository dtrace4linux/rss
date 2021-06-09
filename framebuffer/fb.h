/**********************************************************************/
/*   A virtual or physical screen buffer.			      */
/**********************************************************************/
typedef struct screen_t {
	char	*s_name;
	char	*s_mem;
	int	s_screensize;
	unsigned s_line_length;
	unsigned s_width;
	unsigned s_height;
	long	s_location; /* Current offset for writing to buffer */
	int	s_bpp;
	int	s_yoffset;
	int	s_xoffset;
	} screen_t;

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
void put_pixel(screen_t *, int r, int g, int b);

cmd_t	*next_script_cmd(void);
void	do_script(void);
struct imgRawImage *next_image(void);
void shrink_display(screen_t *, struct imgRawImage *img);

extern screen_t *scrp;
extern int v_flag;
extern long delay;
extern int num;
extern char *script_file;
