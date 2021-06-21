/**********************************************************************/
/*   Code to handle reading a script file - a text file to implement  */
/*   drawing on the framebuffer.				      */
/**********************************************************************/

#include <unistd.h>
#include <ctype.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <linux/fb.h>
#include <search.h>
#include "fb.h"

static char	rand_buf[1024];
static int	rand_idx;
static cmd_t	*script;
static int	script_used;
static int	script_len;
static int sp;

int swidth = 1920, sheight = 1020;

static int debug;

static char *cmds[] = {
	"C_NONE", 
	"C_BREAK", 
	"C_CIRCLE", 
	"C_CLEAR", 
	"C_CONTINUE",
	"C_DELAY", 
	"C_DOT", 
	"C_DRAW",
	"C_ELLIPSE",
	"C_END",
	"C_EXIT", 
	"C_FILLED_CIRCLE", 
	"C_FILLED_ELLIPSE",
	"C_FILLED_RECTANGLE", 
	"C_FOR",
	"C_FOR2",
	"C_IF", 
	"C_LINE", 
	"C_NUMBER", 
	"C_PRINT",
	"C_RAND",
	"C_RECTANGLE", 
	"C_REPEAT", 
	"C_SCREENSIZE", 
	"C_SLEEP",
	"C_TEXT",
	"C_WHILE", 
	};

typedef struct estack_t {
	int	e_start;
	} estack_t;
static int esize;
static int eused;
estack_t *estack;

extern int x_arg;
extern int y_arg;
extern int w_arg;
extern int h_arg;
extern int rand_flag;

/**********************************************************************/
/*   Prototypes.						      */
/**********************************************************************/
static int	read_script_cmd(void);
static cmd_t *script_exec();
void push_estack(cmd_t *cmdp);
void pop_estack(void);
void set_var(char *name, int val);
long lookup(char *str);
void token_init(char *str);
char *token_next();
char ** parse_list(char *str, int *len);

cmd_t *
alloc_cmd(int type)
{	cmd_t	*cmdp;

	if (script_used + 1 >= script_len) {
		script_len += 128;
		script = realloc(script, script_len * sizeof *script);
	}

	cmdp = &script[script_used];
	memset(cmdp, 0, sizeof *cmdp);
	cmdp->type = type;
	cmdp->pc = script_used++;

	return cmdp;
}

void
cmd_usage(cmd_t *cmdp, char *str)
{
	printf("syntax error - %s\n", str);
	exit(1);
}
void
do_script()
{	cmd_t	*cmdp;

	esize = 16;
	estack = calloc(sizeof *estack * esize, 1);

	set_var("screen_width", swidth);
	set_var("screen_height", sheight);

	while ((cmdp = next_script_cmd()) != NULL) {
		if (cmdp->type == C_EXIT)
			return;
	}
}

/**********************************************************************/
/*   We  dont  want  to  randomize  in the script itself, since that  */
/*   means a new file on each release. So handle randomization here.  */
/**********************************************************************/
char *
map_rand(char *cp)
{	char	buf[BUFSIZ];
	char	*cp1;

	if (strcmp(cp, "rand_x") == 0)
		snprintf(buf, sizeof buf, "%d", (int) ((rand() / (float) RAND_MAX) * 1920));
	else if (strcmp(cp, "rand_y") == 0)
		snprintf(buf, sizeof buf, "%d", (int) ((rand() / (float) RAND_MAX) * 1080));
	else if (strcmp(cp, "rand_w") == 0)
		snprintf(buf, sizeof buf, "%d", (int) ((rand() / (float) RAND_MAX) * 1920));
	else if (strcmp(cp, "rand_h") == 0)
		snprintf(buf, sizeof buf, "%d", (int) ((rand() / (float) RAND_MAX) * 1080));
	else if (strcmp(cp, "rand_rgb") == 0) {
		snprintf(buf, sizeof buf, "%ld", (long) ((rand() / (float) RAND_MAX) * 0xffffff));
		}
	else
		return cp;
	if (rand_idx + strlen(buf) >= sizeof rand_buf - 1)
		return cp;

	cp1 = rand_buf + rand_idx;
	strcpy(rand_buf + rand_idx, buf);
	rand_idx += strlen(buf) + 1;
//printf("%s -> %s\n", cp, cp1);
	return cp1;
}

void
compile_blocks()
{	int	i, j;

	for (i = 0; i < script_used; i++) {
		cmd_t *cmdp = &script[i];
		int	lv = 0;
		if (cmdp->type == C_FOR2) {
			for (j = i+1; j < script_used; j++) {
				cmd_t *cmdp1 = &script[j];
				if (cmdp1->type == C_FOR2) {
					lv++;
					continue;
				}
				if (cmdp1->type != C_END)
					continue;
				if (lv-- != 0)
					continue;
				cmdp->next_pc = j+1;
//printf("Set %d->%d\n", i, j+1);
			}
		}
	}
}

void
dump_script()
{	int	i, j;

	if (debug) {
		for (i = 0; i < script_used; i++) {
			cmd_t *cmdp = &script[i];
			printf("0x%04x: %s ",
				i, cmds[cmdp->type]);
			for (j = 0; j < cmdp->argc; j++) {
				printf(" %s", cmdp->raw_args[j]);
			}
			if (cmdp->next_pc) {
				printf(" => 0x%04x", cmdp->next_pc);
			}
			printf("\n");
		}
		printf("== END ===\n");
	}
}

#define NUMBER	0
#define PLUS	1
#define MINUS	2
#define MUL	3
#define DIV	4

void
get_token(char *str, char **str2, int *type, long *value)
{
	if (isdigit(*str)) {
		*value = atoi(str);
		while (isdigit(*str))
			str++;
		*str2 = str;
		type = NUMBER;
		return;
	}
	if (isalpha(*str)) {
		char *cp;
		int	ch;
		for (cp = str; isalpha(*cp) || isdigit(*cp) || *cp == '_'; )
			cp++;
		ch = *cp;
		*cp = '\0';
		*value = lookup(str);
		*cp = ch;
		*str2 = cp;
		type = NUMBER;
		return;
	}
	if (*str == '+') {
		*str2 = str+1;
		*type = PLUS;
		return;
	}
	if (*str == '-') {
		*str2 = str+1;
		*type = MINUS;
		return;
	}
	if (*str == '+') {
		*str2 = str+1;
		*type = MUL;
		return;
	}
	if (*str == '+') {
		*str2 = str+1;
		*type = DIV;
		return;
	}
}

long
eval(char *str)
{	long	value, value2;
	int	type;
	char	*str2;

	get_token(str, &str2, &type, &value);
	str = str2;
	while (*str) {
		get_token(str, &str2, &type, &value);
		str = str2;
		switch (type) {
		  case PLUS:
			get_token(str, &str2, &type, &value2);
			str = str2;
			value += value2;
			break;
		  case MINUS:
			get_token(str, &str2, &type, &value2);
			str = str2;
			value -= value2;
			break;
		  case MUL:
			get_token(str, &str2, &type, &value2);
			str = str2;
			value *= value2;
			break;
		  case DIV:
			get_token(str, &str2, &type, &value2);
			str = str2;
			value /= value2;
			break;
		}
	}
	return value;
}

char *
get_attribute(cmd_t *cmdp, char *name)
{	int	i;
	int	len = strlen(name);

	for (i = 0; i < cmdp->argc; i++) {
		if (strncmp(name, cmdp->raw_args[i], len) == 0 &&
		    (cmdp->raw_args[i][len] == '(' || cmdp->raw_args[i][len] == '=')) {
		    	return cmdp->raw_args[i];
		}
	}
	return NULL;
}
char *
get_value(cmd_t *cmdp, char *name)
{	int	i;
	int	len = strlen(name);
	char	*v = NULL;
	int	size = 10;
	int	used = 0;
	char	*str;

	for (i = 0; i < cmdp->argc; i++) {
		if (strncmp(name, cmdp->raw_args[i], len) == 0 &&
		    (cmdp->raw_args[i][len] == '(' || cmdp->raw_args[i][len] == '=')) {
		    	v = cmdp->raw_args[i];
			break;
		}
	}
	if (v == NULL)
		return NULL;

	v += len;
	str = malloc(size);
	if (*v++ == '=') {
		while (isspace(*v))
			v++;
		if (*v == '"')
			v++;
		while (*v && *v != '"') {
			if (used + 2 >= size) {
				size += 32;
				str = realloc(str, size);
			}
			str[used++] = *v++;
		}
	} else {
		while (isspace(*v))
			v++;
		while (*v && *v != ')') {
			if (used + 2 >= size) {
				size += 32;
				str = realloc(str, size);
			}
			str[used++] = *v++;
		}
	}
	str[used] = '\0';

	return str;
}
int
has_attribute(cmd_t *cmdp, char *name)
{	int	i;

	for (i = 0; i < cmdp->argc; i++) {
		if (strcmp(name, cmdp->raw_args[i]) == 0)
			return 1;
		}
	return 0;
}
long
lookup(char *str)
{	ENTRY e, *ep;

	if (isdigit(*str))
		return atoi(str);
	if (strcmp(str, "rand_x") == 0) 
		return (int) (rand() / (float) RAND_MAX) * swidth;
	if (strcmp(str, "rand_y") == 0) 
		return (int) (rand() / (float) RAND_MAX) * sheight;
	if (strcmp(str, "rand_width") == 0) 
		return (int) (rand() / (float) RAND_MAX) * swidth;
	if (strcmp(str, "rand_height") == 0) 
		return (int) (rand() / (float) RAND_MAX) * sheight;
	e.key = str;
	ep = hsearch(e, FIND);
	if (ep) {
//printf("eval %s = %d\n", str, (int) ep->data);
		return (long) ep->data;
	}
	printf("lookup undefined variable: %s\n", str);
	return 1;
}

void
eval_range(char *str, int *from, int *to)
{	char	*cp;

	if (sscanf(str, "%d..%d", from, to) == 2)
		return;
//printf("eval range %s\n", str);

	for (cp = str; strncmp(cp, "..", 2) != 0; cp++)
		;
	if (strncmp(cp, "..", 2) != 0) {
		printf("error in range - format is N..M\n");
		exit(1);
	}
	*cp = '\0';
	*from = eval(str);
	*cp = '.';
	*to = eval(cp+2);
//printf("  => %d..%d\n", *from, *to);

}
cmd_t *
next_script_cmd()
{	int	i;

	if (script == NULL) {
		char *cp;
		if ((cp = getenv("DEBUG")) != NULL) {
			debug = atoi(cp);
		}

		script_len += 32;
		script = calloc(sizeof *script, script_len);

		while (read_script_cmd() != 0) {
		}

		compile_blocks();

		dump_script();
	}

	while (sp < script_used) {
		cmd_t *cmdp = script_exec();
		if (cmdp)
			return cmdp;
	}

	return NULL;
}
static cmd_t *
script_exec()
{	int	i;
	cmd_t *cmdp = &script[sp++];

	if (debug)
		printf("%*s0x%04x: %s 0x%02x\n", 
			eused, " ",
			sp-1, cmds[cmdp->type], cmdp->type);

	switch (cmdp->type) {
	  case C_CIRCLE:
		draw_circle(cmdp);
	  	break;

	  case C_CLEAR:
		draw_clear(cmdp);
		break;

	  case C_DELAY:
		delay = cmdp->args[1];
		break;

	  case C_DOT:
		draw_dot(cmdp);
	  	break;

	  case C_DRAW:
	  	if (draw_image(cmdp) == 0)
			exit(0);
	  	break;

	  case C_ELLIPSE:
	  case C_FILLED_ELLIPSE:
		draw_ellipse(cmdp);
	  	break;

	  case C_EXIT:
	  	return cmdp;

	  case C_FILLED_CIRCLE:
		draw_filled_circle(cmdp);
		break;

	  case C_FILLED_RECTANGLE:
		draw_filled_rectangle(cmdp);
		break;

	  case C_END:
	  	pop_estack();
	  	break;

	  case C_FOR:
	  	eval_range(cmdp->raw_args[3], &cmdp->start, &cmdp->end);
	  	cmdp[1].curval = cmdp->start;
	  	cmdp[1].end = cmdp->end;
		cmdp[1].step = eval(cmdp->raw_args[5]);
		cmdp[1].curval -= cmdp[1].step;
	  	break;

	  case C_FOR2:
//printf("for2: %d - %d\n", cmdp->curval, cmdp->end);
		cmdp->curval += cmdp->step;
//printf("FOR2: %s %d\n", cmdp->var, cmdp->curval);
		set_var(cmdp->var, cmdp->curval);
	  	if (cmdp->curval > cmdp->end) {
//printf("end loop - %x\n", cmdp->next_pc);
			sp = cmdp->next_pc;
			break;
		}
	  	push_estack(cmdp);
	  	break;

	  case C_LINE:
		draw_line(cmdp);
	  	break;

	  case C_NUMBER:
	  	num = cmdp->args[1];
		break;

	  case C_PRINT:
	  	for (i = 1; i < cmdp->argc; i++) {
			printf("%s%s", i > 1 ? " " : "", cmdp->raw_args[i]);
		}
		printf("\n");
		break;

	  case C_RAND:
	  	rand_images();
		break;

	  case C_RECTANGLE:
		draw_rectangle(cmdp);
	  	break;

	  case C_REPEAT:
	  	if (cmdp->count >= cmdp->args[1]) {
			sp++;
			break;
		}
		cmdp->count++;
	  	break;

	  case C_SLEEP:
		sleep(cmdp->args[1]);
	  	break;

	  case C_SCREENSIZE:
		swidth = eval(cmdp->raw_args[1]);
		sheight = eval(cmdp->raw_args[2]);
		set_var("screen_width", swidth);
		set_var("screen_height", sheight);
	  	break;

	  case C_TEXT:
	  	draw_text(cmdp);
		break;

	  default:
		printf("script_exec: error, 0x%04x: %s '%d' is unhandled\n", 
			sp-1, cmds[cmdp->type], cmdp->type);
		exit(0);
	  }

	return NULL;
}

int
parse_gradient(char *str, unsigned long *start, unsigned long *end)
{	char	**array;
	int	len;
	int	i;

	while (*str && *str != '(')
		str++;
	if (*str++ == '\0')
		return 0;
	array = parse_list(str, &len);
	if (len > 0)
		*start = strtol(array[0], NULL, 16);
	if (len > 1)
		*end = strtol(array[1], NULL, 16);

	for (i = 0; i < len; i++)
		free(array[i]);
	free(array);

	return 1;
}

char **
parse_list(char *str, int *len)
{	int	size = 10;
	int	used = 0;
	char	**array = calloc(sizeof *array, size);

	while (*str) {
		if (used + 1 >= size) {
			size += 10;
			array = realloc(array, size * sizeof *array);
		}

		while (isspace(*str))
			str++;
		char *start = str;
		while (*str && *str != ',' && *str != ')')
			str++;
		char *arg = malloc(str - start + 1);
		memcpy(arg, start, str - start);
		arg[str - start] = '\0';
		array[used++] = arg;
//printf("arg='%s'\n", arg);
		while (*arg && isspace(arg[strlen(arg) - 1]))
			arg[strlen(arg)-1] = '\0';

		if (*str != ',')
			break;
		str++;
	}
	*len = used;
	return array;
}

/**********************************************************************/
/*   Parse an expression like: random(xxx:10%, yyy:20%, ...)	      */
/**********************************************************************/
char *
parse_percentage(char *str)
{	int	pc = get_rand(100);
	int	cum_pc = 0;
	char	*name = NULL;

	while (*str && *str != '(')
		str++;
	if (*str == '\0')
		return NULL;
	str++;
	if (*str == '\0')
		return NULL;

	while (*str && *str != ')') {
		int	n;

		if (isspace(*str)) {
			str++;
			continue;
		}

		char *sym_start = str;
		while (*str && (isalnum(*str) || *str == '_'))
			str++;
		name = malloc(str - sym_start + 1);
		memcpy(name, sym_start, str - sym_start);
		name[str-sym_start] = '\0';

		while (*str && isspace(*str))
			str++;

		if (*str++ != ':') {
			break;
		}

		while (*str && isspace(*str))
			str++;
		n = atoi(str);
		cum_pc += n;
		if (cum_pc >= pc)
			return name;

		free(name);

		while (isdigit(*str))
			str++;
		while (*str == '%')
			str++;
		while (*str && isspace(*str))
			str++;
		if (*str == ',')
			str++;
	}
	if (name)
		free(name);
	return NULL;
}

void
push_estack(cmd_t *cmdp)
{
	if (eused + 1 >= esize) {
		printf("Execution stack overflow\n");
		exit(1);
	}
	estack_t *esp = &estack[eused++];
	esp->e_start = cmdp->pc;
}

void
pop_estack()
{
	if (eused == 0) {
		printf("pop_estack: internal error - stack is empty. extraneous 'end'?\n");
		exit(1);
	}
	sp = estack[--eused].e_start;
}


static int
read_script_cmd()
{
static FILE *fp;
	char	buf[BUFSIZ];
	char	*cp;
static int line = 0;
	cmd_t *cmdp;

	if (fp == NULL) {
		if ((fp = fopen(script_file, "r")) == NULL) {
			perror(script_file);
			exit(1);
		}
	}

	while (1) {
		line++;
		if (fgets(buf, sizeof buf, fp) == NULL) {
			if (v_flag)
				printf("[EOF]\n");
			alloc_cmd(C_EXIT);
			return 0;
		}
		if (v_flag) {
			printf("%s", buf);
		}

		if (*buf && buf[strlen(buf) - 1] == '\n') {
			buf[strlen(buf) - 1] = '\0';
		}

		cp = buf;
		while (isspace(*cp))
			cp++;

		if (*cp == '\0' || *cp == '#' || *cp == '\n' || strncmp(cp, "//", 2) == 0)
			continue;

		rand_idx = 0;
		cmdp = alloc_cmd(C_NONE);
		token_init(cp);
		while ((cp = token_next()) != NULL) {
			cmdp->raw_args[cmdp->argc] = cp ;
			if (cmdp->argc < MAX_ARGS) {
				char	*cp1;
				cp = map_rand(cp);
				cmdp->args[cmdp->argc] = strtol(cp, &cp1, 16);
			}
			cmdp->argc++;
		}

		char *cname = cmdp->raw_args[0];

		if (strcmp(cname, "}") == 0 || strcmp(cname, "end") == 0) {
			cmdp->type = C_END;
			return 1;
		}

		if (strcmp(cname, "draw") == 0 && cmdp->argc >= 5) {
			cmdp->type = C_DRAW;
			cmdp->x = cmdp->args[1];
			cmdp->y = cmdp->args[2];
			cmdp->w = cmdp->args[3];
			cmdp->h = cmdp->args[4];

			cmdp->x *= scrp->s_width / (float) swidth;
			cmdp->y *= scrp->s_height / (float) sheight;
			cmdp->w *= scrp->s_width / (float) swidth;
			cmdp->h *= scrp->s_height / (float) sheight;

			return 1;
		}
		if (strcmp(cname, "clear") == 0) {
			cmdp->type = C_CLEAR;
			return 1;
		}
		if (strcmp(cname, "exit") == 0) {
			cmdp->type = C_EXIT;
			return 1;
		}
		if (strcmp(cname, "delay") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_DELAY;
			return 1;
		}
		if (strcmp(cname, "number") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_NUMBER;
//		    	num = cmdp->args[1];
			return 1;
		}
		if ((strcmp(cname, "circle") == 0 ||
		    strcmp(cname, "filled_circle") == 0) && cmdp->argc >= 4) {
			cmdp->type = C_CIRCLE;
			cmdp->x      = cmdp->args[1];
			cmdp->y      = cmdp->args[2];
			cmdp->radius = cmdp->args[3];
			cmdp->rgb    = cmdp->args[4];

//printf("circle %d %d %d 0x%lx\n", cmdp->x, cmdp->y, cmdp->radius, cmdp->rgb);

			cmdp->x *= scrp->s_width / (float) swidth;
			cmdp->y *= scrp->s_height / (float) sheight;
			cmdp->radius *= scrp->s_width / (float) swidth;

			if (strcmp(cname, "filled_circle") == 0)
		       		cmdp->type   = C_FILLED_CIRCLE;

			return 1;
		}
		if (strcmp(cname, "ellipse") == 0) {
			cmdp->type = C_ELLIPSE;
			return 1;
		}

		if (strcmp(cname, "filled_ellipse") == 0) {
			cmdp->type = C_FILLED_ELLIPSE;
			return 1;
		}

		if (strcmp(cname, "for") == 0) {
			cmd_t *cmdp1;

			// for var in 0..100 step n
			if (cmdp->argc < 5) {
				cmd_usage(cmdp, "for");
			}
			cmdp->type = C_FOR;
			cmdp->var = cmdp->raw_args[1];
			if (strcmp(cmdp->raw_args[2], "in") != 0)
				cmd_usage(cmdp, "for: usage: for <var> in N..M [step SS]");
			cp = cmdp->raw_args[3];
/*			if (sscanf(cp, "%d..%d", &cmdp->start, &cmdp->end) != 2)
				cmd_usage(cmdp, "for (range): usage: for <var> in N..M [step SS]");
*/
			cmdp->step = 1;
			if (strcmp(cmdp->raw_args[4], "step") == 0)
				cmdp->step = atoi(cmdp->raw_args[5]);
			cmdp1 = alloc_cmd(C_FOR2);
			cmdp1->start = cmdp->start;
			cmdp1->end = cmdp->end;
			cmdp1->step = cmdp->step;
			cmdp1->var = cmdp->var;
			return 1;
		}

		if (strcmp(cname, "dot") == 0 && cmdp->argc >= 4) {
			cmdp->type = C_DOT;
			cmdp->x = cmdp->args[1];
			cmdp->y = cmdp->args[2];
			cmdp->x *= scrp->s_width / (float) swidth;
			cmdp->y *= scrp->s_height / (float) sheight;

			return 1;
		}
		if (strcmp(cname, "line") == 0 && cmdp->argc >= 6) {
			cmdp->type = C_LINE;
			cmdp->x   = cmdp->args[1];
			cmdp->y   = cmdp->args[2];
			cmdp->x1  = cmdp->args[3];
			cmdp->y1  = cmdp->args[4];
			cmdp->rgb = cmdp->args[5];

			cmdp->x *= scrp->s_width / (float) swidth;
			cmdp->y *= scrp->s_height / (float) sheight;
			cmdp->x1 *= scrp->s_width / (float) swidth;
			cmdp->y1 *= scrp->s_height / (float) sheight;

			return 1;
		}
		if (strcmp(cname, "print") == 0) {
			cmdp->type = C_PRINT;
			return 1;
		}
		if (strcmp(cname, "rand") == 0) {
			cmdp->type = C_RAND;
			return 1;
		}
		if ((strcmp(cname, "rectangle") == 0 ||
		    strcmp(cname, "filled_rectangle") == 0) && cmdp->argc >= 5) {
			if (strcmp(cname, "rectangle") == 0) {
				cmdp->type = C_RECTANGLE;
				}
			else {
				cmdp->type = C_FILLED_RECTANGLE;
				}
			cmdp->x = cmdp->args[1];
			cmdp->y = cmdp->args[2];
			cmdp->w = cmdp->args[3];
			cmdp->h = cmdp->args[4];
			cmdp->rgb = cmdp->args[5];

			cmdp->x *= scrp->s_width / (float) swidth;
			cmdp->y *= scrp->s_height / (float) sheight;
			cmdp->w *= scrp->s_width / (float) swidth;
			cmdp->h *= scrp->s_height / (float) sheight;

			return 1;
		}
		if (strcmp(cname, "repeat") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_REPEAT;
			return 1;
		}
		if (strcmp(cname, "sleep") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_SLEEP;
			return 1;
		}
		if (strcmp(cname, "screensize") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_SCREENSIZE;
			return 1;
		}

		if (strcmp(cname, "text") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_TEXT;
			cmdp->rgb = cmdp->args[5];
			return 1;
		}

		printf("%s:%d: bad command - not recognized '%s'\n",
			script_file, line, cname);
	}

	return 0;
}

void
set_var(char *name, int val)
{static int first_time = 1;
	ENTRY	e, *ep;

	if (first_time) {
		hcreate(30);
		first_time = 0;
	}

	e.key = name;
	e.data = (void *) (long) val;
	ep = hsearch(e, ENTER);
	if (ep)
		ep->data = (void *) (long) val;
}
static char *tok;
void
token_init(char *str)
{
	tok = str;
}
char *
token_next()
{
	int	br = 0;
	int	quote = 0;
	int	oused = 0;
	int	osize = 16;
	char	*ostr = malloc(osize);

	while (isspace(*tok))
		tok++;
	if (*tok == '\0')
		return NULL;

	while (*tok) {
		if (oused + 1 >= osize) {
			osize += 32;
			ostr = realloc(ostr, osize);
		}

		if (*tok == ' ' && br == 0 && quote == 0) {
			ostr[oused] = '\0';
			*tok++;
			return ostr;
		}
		if (*tok == '"' && quote == 0)
			quote = '"';
		else if (*tok == '\'' && quote == 0)
			quote = '\'';
		else if (*tok == quote)
			quote = '\0';
		else if (*tok == '\\' && tok[1]) {
			switch (*++tok) {
			  case 'n':
				ostr[oused++] = '\n';
				break;
			  default:
				ostr[oused++] = *tok;
				break;
			  }
		}
		else
			ostr[oused++] = *tok;

		if (*tok == '(')
			br++;
		if (*tok == ')')
			br--;
		tok++;
	}
	if (br) {
		fprintf(stderr, "unmatched brackets in argument\n");
		exit(1);
	}
	ostr[oused] = '\0';
	return ostr;
}

