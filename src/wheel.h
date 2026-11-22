#ifndef _WHEEL_H
#define _WHEEL_H

#include <stdint.h>

/*
 * The mouse wheel: it scrolls a 3B1 window that has scroll arrows in its
 * border (such as the Office), as a click on the arrows does.
 */

/// main thread: the wheel turned; steps > 0 up (away from the user)
void wheel_scroll(float steps);
/// main thread, at every 60 Hz tick: press the next Roll key
void wheel_tick(void);
/// main thread: the machine was reset
void wheel_reset(void);
/// main thread: the address of keywp, the window driver's pointer to the
/// window that has the keyboard (struct windef *); 0 if not found. A
/// look reads the whole kernel: not at every tick.
uint32_t wheel_keywp(void);

#endif
