/**********************************************************************/
/*   A virtual or physical screen buffer.			      */
/**********************************************************************/
typedef struct screen_t {
	int	s_id;
	char	*s_name;
	char	*s_mem;
	unsigned s_screensize;
	unsigned s_line_length;
	unsigned s_width;
	unsigned s_height;
	long	s_location; /* Current offset for writing to buffer */
	int	s_bpp;
	int	s_yoffset;
	int	s_xoffset;
	struct fb_info_t *s_info;
	int	s_txt_row, s_txt_col;
	unsigned long s_txt_fg_rgb;
	unsigned long s_txt_bg_rgb;
	struct screen_t *s_next;
	struct screen_t *s_prev;
	} screen_t;

/**********************************************************************/
/*   For  virtual  frame buffers, we need to know the dimensions and  */
/*   bpp							      */
/**********************************************************************/
# define	FB_MAGIC "fb-info-file"
# define	FB_VERSION 1
typedef struct fb_info_t {
	char	f_magic[64];
	int	f_version;
	int	f_width;
	int	f_height;
	int	f_bpp;
	unsigned long f_seq;
	} fb_info_t;

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
	C_ASSIGN,
	C_BREAK,
	C_CIRCLE, 
	C_CLEAR,
	C_CONTINUE, 
	C_DEBUG,
	C_DELAY, 
	C_DOT, 
	C_DRAW,
	C_ELLIPSE,
	C_END,
	C_EXIT, 
	C_FILLED_CIRCLE, 
	C_FILLED_ELLIPSE, 
	C_FILLED_RECTANGLE, 
	C_FRAME,
	C_FOR,
	C_FOR2,
	C_IF,
	C_IMAGE_LIST,
	C_LINE, 
	C_NUMBER, 
	C_PRINT,
	C_RAND,
	C_RECTANGLE, 
	C_REPEAT, 
	C_SCREENSIZE, 
	C_SLEEP,
	C_TEXT,
	C_TIME_LIMIT,
	C_WHILE,
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
	int	pc;	/* Program Counter. */
	int	next_pc;	/* Jump outside block */
	char	*var;
	int	start;
	int	end;
	int	step;
	int	curval;
	int	line_num;
	} cmd_t;

int	draw_circle(cmd_t *);
int	draw_filled_circle(cmd_t *);
int	draw_clear(cmd_t *);
int	draw_dot(cmd_t *);
int	draw_ellipse(cmd_t *);
int	draw_filled_rectangle(cmd_t *);
int	draw_image_list(cmd_t *);
int	draw_line(cmd_t *);
int	draw_rectangle(cmd_t *);
void put_pixel(screen_t *, int r, int g, int b);

cmd_t	*next_script_cmd(void);
void	do_script(void);
struct imgRawImage *next_image(void);
void shrink_display(screen_t *, struct imgRawImage *img);
void	update_image(void);
void	free_image(struct imgRawImage *);
int	draw_image(cmd_t *);
int	draw_text(cmd_t *);
void	rand_images(void);
long	eval(char *);
int	write_jpeg(char *ofname, screen_t *, int depth);
int	has_attribute(cmd_t *, char *);
void do_sleep(int delay);
int	get_rand(int n);
char *get_attribute(cmd_t *cmdp, char *name);
char *get_value(cmd_t *cmdp, char *name);
char	*parse_percentage(char *);
int parse_gradient(char *str, unsigned long *start, unsigned long *end);
long eval(char *str);
int time_limit_exceeded();
int	compute_montage(screen_t *, int seq_flag);
int parse_value(char *str);
long	lookup(char *, int quiet);

extern screen_t *scrp;
extern int v_flag;
extern long delay;
extern int num;
extern char *script_file;
extern int x_arg;
extern int y_arg;
extern int w_arg;
extern int h_arg;
extern int swidth, sheight;

# if !defined(MIN)
#	define MIN(a, b) ((a) < (b)) ? (a) : (b)
#	define MAX(a, b) ((a) > (b)) ? (a) : (b)
# endif
