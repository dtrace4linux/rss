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

char	rand_buf[1024];
int	rand_idx;

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
{	cmd_t *cmdp = NULL;
static FILE *fp;
	char	buf[BUFSIZ];
	char	*cp;
static int line = 0;
static int swidth, sheight;

	if (fp == NULL) {
		if ((fp = fopen(script_file, "r")) == NULL) {
			perror(script_file);
			exit(1);
		}
	}

	while (1) {
		cmdp = calloc(sizeof *cmdp, 1);

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
			cmdp->x = cmdp->args[1];
			cmdp->y = cmdp->args[2];
			cmdp->w = cmdp->args[3];
			cmdp->h = cmdp->args[4];

			cmdp->x *= vinfo.xres / (float) swidth;
			cmdp->y *= vinfo.yres / (float) sheight;
			cmdp->w *= vinfo.xres / (float) swidth;
			cmdp->h *= vinfo.yres / (float) sheight;

			return cmdp;
		}
		if (strcmp(cname, "clear") == 0) {
			draw_clear(cmdp);
			continue;
		}
		if (strcmp(cname, "delay") == 0 && cmdp->argc >= 1) {
			delay = cmdp->args[1];
			continue;
		}
		if (strcmp(cname, "number") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_NUMBER;
		    	num = cmdp->args[1];
			continue;
		}
		if (strcmp(cname, "circle") == 0 && cmdp->argc >= 4) {
			cmdp->type   = C_CIRCLE;
			cmdp->x      = cmdp->args[1];
			cmdp->y      = cmdp->args[2];
			cmdp->radius = cmdp->args[3];
			cmdp->rgb    = cmdp->args[4];

//printf("circle %d %d %d 0x%lx\n", cmdp->x, cmdp->y, cmdp->radius, cmdp->rgb);

			cmdp->x *= vinfo.xres / (float) swidth;
			cmdp->y *= vinfo.yres / (float) sheight;
			cmdp->radius *= vinfo.xres / (float) swidth;

			draw_circle(cmdp);

			continue;
		}
		if (strcmp(cname, "dot") == 0 && cmdp->argc >= 4) {
			cmdp->type = C_DOT;
			cmdp->x = cmdp->args[1];
			cmdp->y = cmdp->args[2];
			cmdp->x *= vinfo.xres / (float) swidth;
			cmdp->y *= vinfo.yres / (float) sheight;

			draw_dot(cmdp);

			continue;
		}
		if (strcmp(cname, "line") == 0 && cmdp->argc >= 6) {
			cmdp->type = C_LINE;
			cmdp->x   = cmdp->args[1];
			cmdp->y   = cmdp->args[2];
			cmdp->x1  = cmdp->args[3];
			cmdp->y1  = cmdp->args[4];
			cmdp->rgb = cmdp->args[5];

			cmdp->x *= vinfo.xres / (float) swidth;
			cmdp->y *= vinfo.yres / (float) sheight;
			cmdp->x1 *= vinfo.xres / (float) swidth;
			cmdp->y1 *= vinfo.yres / (float) sheight;

			draw_line(cmdp);

			continue;
		}
		if ((strcmp(cname, "rectangle") == 0 ||
		    strcmp(cname, "filled_rectangle") == 0) && cmdp->argc >= 5) {
			cmdp->x = cmdp->args[1];
			cmdp->y = cmdp->args[2];
			cmdp->w = cmdp->args[3];
			cmdp->h = cmdp->args[4];
			cmdp->rgb = cmdp->args[5];

			cmdp->x *= vinfo.xres / (float) swidth;
			cmdp->y *= vinfo.yres / (float) sheight;
			cmdp->w *= vinfo.xres / (float) swidth;
			cmdp->h *= vinfo.yres / (float) sheight;

			if (strcmp(cname, "rectangle") == 0) {
				cmdp->type = C_RECTANGLE;
				draw_rectangle(cmdp);
				}
			else {
				cmdp->type = C_FILLED_RECTANGLE;
				draw_filled_rectangle(cmdp);
				}

			continue;
		}
		if (strcmp(cname, "sleep") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_SLEEP;
			sleep(cmdp->args[1]);
			continue;
		}
		if (strcmp(cname, "screensize") == 0 && cmdp->argc >= 1) {
			cmdp->type = C_SCREENSIZE;
			swidth = cmdp->args[1];
			sheight = cmdp->args[2];
			continue;
		}

		printf("%s:%d: bad command - not recognized '%s'\n",
			script_file, line, cname);
	}

	return NULL;
}


