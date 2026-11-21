#ifndef _SCREEN_H
#define _SCREEN_H

/*
 * The screen: 720 pixels across, 90 bytes a line, one bit a pixel.
 * The 3B1 has 348 lines in 32 KB of video RAM at 0x420000. A build with
 * -DSCR_LINES=N (up to 728) has a taller screen in 64 KB: 0x420000 to
 * 0x42FFFF, where the 3B1 has a mirror of the 32 KB. Only a UNIX patched
 * for it draws there.
 */
#ifndef SCR_LINES
#define SCR_LINES 348
#endif
#define SCR_COLS 720
#define VRAM_ROW 90		// bytes in a screen line
#define VRAM_SIZE (SCR_LINES * VRAM_ROW > 0x8000 ? 0x10000 : 0x8000)
#define VRAM_LAST (0x420000 + VRAM_SIZE - 1)	// above it: the mirror
#if SCR_LINES < 348 || SCR_LINES * VRAM_ROW > 0x10000
#error "SCR_LINES must be 348 to 728"
#endif

#endif
