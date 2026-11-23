/*
 * wheel - the mouse wheel scrolls a 3B1 window, as its scroll arrows do.
 *
 * The 3B1 mouse has no wheel. A window that can scroll has arrows in its
 * border (BORDVSCROLL in sys/window.h). A click on one sends the window's
 * program Roll Up or Roll Down, the keys Shift+Up and Shift+Down: the
 * Office's list moves one line, and the highlight stays where it was on
 * the screen. So each wheel step presses Shift+Up or Shift+Down, but only
 * while the window that has the keyboard has those arrows (keywin.c) and
 * the pointer is over it. A shell window has no arrows, and there the keys
 * would be typed into the command line, so there the wheel does nothing.
 *
 * This is specific to UNIX 3.51: with other software keywin finds no
 * window, and the wheel does nothing.
 */
#include <stdbool.h>
#include <stdint.h>
#include "memory.h"
#include "keys.h"
#include "keywin.h"
#include "pointer.h"
#include "wheel.h"

// Roll steps still to press: + up, - down. A few at most, so the window
// stops soon after the wheel does.
#define MAX_STEPS 3
static float steps;
// the ticks until the next look for the window driver
static int look_wait;

// the window that has the keyboard has scroll arrows, and the pointer is
// over it
static bool window_scrolls(void)
{
	if (look_wait > 0)
		return false;
	if (!keywin_keywp()) {
		look_wait = 60;		// the next look in a second at the soonest
		return false;
	}
	uint32_t const wp = keywin_window();
	uint16_t uflags, r[4];
	if (!wp || !mem_peek16(wp + WD_UFLAGS, &uflags) || !(uflags & WD_BORDVSCROLL))
		return false;
	for (int i = 0; i < 4; i++)
		if (!mem_peek16(wp + WD_REC + 2 * i, &r[i]))
			return false;
	int x, y;
	return !pointer_get(&x, &y) ||
		(x >= r[0] && x < r[2] && y >= r[1] && y < r[3]);
}

void wheel_scroll(float n)
{
	steps += n;
	if (steps > MAX_STEPS)
		steps = MAX_STEPS;
	else if (steps < -MAX_STEPS)
		steps = -MAX_STEPS;
}

void wheel_tick(void)
{
	if (look_wait > 0)
		look_wait--;
	if (steps > -1 && steps < 1)
		return;
	// one Roll at a time, after the keys before it
	if (keys_pending())
		return;
	bool const up = steps > 0;
	if (!window_scrolls()) {
		steps = 0;		// nothing here scrolls: forget the wheel
		return;
	}
	steps -= up ? 1 : -1;
	key_chord const c = { .code = { KEY_SHIFT, up ? KEY_UP : KEY_DOWN }, .n = 2 };
	keys_push(&c);
}

void wheel_reset(void)
{
	steps = 0;
	look_wait = 0;
}
