/**********************************************************************/
/*   Code to handle reading a script file - a text file to implement  */
/*   drawing on the framebuffer.				      */
/**********************************************************************/

#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <linux/fb.h>
#include "fb.h"

static char	rand_buf[1024];
static int	rand_idx;
static cmd_t	*script;
static int	script_used;
static int	script_len;
static int sp;

static int swidth = 1920, sheight = 1020;

static cmd_t * read_script_cmd(cmd_t *cmdp);
static cmd_t *script_exec();
static int debug;

static char *cmds[] = {
	"C_NONE", 
	"C_CIRCLE", 
	"C_CLEAR", 
	"C_DELAY", 
	"C_DOT", 
	"C_DRAW",
	"C_EXIT", 
	"C_FILLED_CIRCLE", 
	"C_FILLED_RECTANGLE", 
	"C_LINE", 
	"C_NUMBER", 
	"C_RECTANGLE", 
	"C_REPEAT", 
	"C_SCREENSIZE", 
	"C_SLEEP",
	};

extern int x_arg;
extern int y_arg;
extern int w_arg;
extern int h_arg;

void
do_script()
{	cmd_t	*cmdp;
	struct imgRawImage *img;

	while ((cmdp = next_script_cmd()) != NULL) {
		if (cmdp->type == C_EXIT)
			return;

		if ((img = next_image()) == NULL)
			break;

		x_arg = cmdp->x;
		y_arg = cmdp->y;
		w_arg = cmdp->w;
		h_arg = cmdp->h;
		shrink_display(scrp, img);
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

cmd_t *
next_script_cmd()
{
	if (script == NULL) {
		char *cp;
		if ((cp = getenv("DEBUG")) != NULL) {
			debug = atoi(cp);
		}

		script_len += 32;
		script = calloc(sizeof *script, script_len);

		while (1) {
			memset(&script[script_used], 0, sizeof *script);
			if (read_script_cmd(&script[script_used]) == NULL)
				break;

			if (script[script_used++].type == C_EXIT)
				break;

			if (script_used >= script_len) {
				script_len += 128;
				script = realloc(script, script_len * sizeof *script);
			}
		}
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
{
	cmd_t *cmdp = &script[sp++];

	if (debug)
		printf("exec: 0x%04x: %s 0x%02x\n", sp-1, cmds[cmdp->type], cmdp->type);

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
	  	return cmdp;

	  case C_EXIT:
	  	return cmdp;

	  case C_FILLED_CIRCLE:
		draw_filled_circle(cmdp);
		break;

	  case C_FILLED_RECTANGLE:
		draw_filled_rectangle(cmdp);
		break;

	  case C_LINE:
		draw_line(cmdp);
	  	break;

	  case C_NUMBER:
	  	num = cmdp->args[1];
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
		swidth = cmdp->args[1];
		sheight = cmdp->args[2];
	  	break;

	  default:
		printf("script_exec: error, 0x%04x: %s '%d' is unhandled\n", 
			sp-1, cmds[cmdp->type], cmdp->type);
		exit(0);
	  }

	return NULL;
}

static cmd_t *
read_script_cmd(cmd_t *cmdp)
{
static FILE *fp;
	char	buf[BUFSIZ];
	char	*cp;
static int line = 0;

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
			cmdp->type = C_EXIT;
			return cmdp;
		}
		if (v_flag) {
			printf("%s", buf);
		}

		if (*buf && buf[strlen(buf) - 1] == '\n') {
			buf[strlen(buf) - 1] = '\0';
		}

		if (*buf == '\0' || *buf == ' ' || *buf == '#' || *buf == '\n')
			continue;

		rand_idx = 0;
		for (cp = strtok(buf, " "); cp; cp = strtok(NULL, " ")) {
			cmdp->raw_args[cmdp->argc] = strdup(cp);
			if (cmdp->argc < MAX_ARGS) {
				cp = map_rand(cp);
				cmdp->args[cmdp->argc] = atoi(cp);
			}
			cmdp->argc++;
		}

		char *cname = cmdp->raw_args[0];

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

			return cmdp;
		}
		if (strcmp(cname, "clear") == 0) {
			cmdp->type = C_CLEAR;
			return cmdp;
		}
		if (strcmp(cname, "delay") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_DELAY;
			return cmdp;
		}
		if (strcmp(cname, "number") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_NUMBER;
		    	num = cmdp->args[1];
			return cmdp;
		}
		if ((strcmp(cname, "circle") == 0 ||
		    strcmp(cname, "filled_circle") == 0) && cmdp->argc >= 4) {
			cmdp->type   = C_CIRCLE;
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

			return cmdp;
		}
		if (strcmp(cname, "dot") == 0 && cmdp->argc >= 4) {
			cmdp->type = C_DOT;
			cmdp->x = cmdp->args[1];
			cmdp->y = cmdp->args[2];
			cmdp->x *= scrp->s_width / (float) swidth;
			cmdp->y *= scrp->s_height / (float) sheight;

			return cmdp;
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

			return cmdp;
		}
		if ((strcmp(cname, "rectangle") == 0 ||
		    strcmp(cname, "filled_rectangle") == 0) && cmdp->argc >= 5) {
			cmdp->x = cmdp->args[1];
			cmdp->y = cmdp->args[2];
			cmdp->w = cmdp->args[3];
			cmdp->h = cmdp->args[4];
			cmdp->rgb = cmdp->args[5];

			cmdp->x *= scrp->s_width / (float) swidth;
			cmdp->y *= scrp->s_height / (float) sheight;
			cmdp->w *= scrp->s_width / (float) swidth;
			cmdp->h *= scrp->s_height / (float) sheight;

			if (strcmp(cname, "rectangle") == 0) {
				cmdp->type = C_RECTANGLE;
				}
			else {
				cmdp->type = C_FILLED_RECTANGLE;
				}

			return cmdp;
		}
		if (strcmp(cname, "repeat") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_REPEAT;
			return cmdp;
		}
		if (strcmp(cname, "sleep") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_SLEEP;
			return cmdp;
		}
		if (strcmp(cname, "screensize") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_SCREENSIZE;
			return cmdp;
		}

		printf("%s:%d: bad command - not recognized '%s'\n",
			script_file, line, cname);
	}

	return NULL;
}


