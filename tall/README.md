# Tall screen: a 720x696 3B1 (a hack, for fun)

The 3B1 has a 720x348 screen in 32 KB of video RAM at 0x420000. This
branch lets FreeBee have a taller one, up to 728 lines in 64 KB, and the
tools here patch 3B1 UNIX 3.51m to use it. Real hardware can't do this, and
the patches are binary patches of one UNIX version. That is why it stays on
this branch.

## Build

    make clean
    make EXT_CFLAGS=-DSCR_LINES=696

Without SCR_LINES the build is the normal 348-line FreeBee.

## Make a tall disk

Take a copy of a 3B1 UNIX 3.51m disk image (for example the disk of the
FreeBee kit). The VM must be off. Then:

    tall/mktall.sh hd.img [696]

It patches three files in the image, in place:

- /unix: the screen clear, the mouse pointer limit, and the window driver's
  back buffer (it takes H*90 bytes off the top of pxmem).
- /etc/lddrv/wind.o (lddrv links it into /etc/lddrv/wind at every boot):
  the window area, the 4 text lines below it, mouse limits, window move and
  size limits, saved-window sizes. The screen saver is off, because it
  keeps the screen in 8 pages, too few for a tall screen.
- /lib/shlib (TAM, the menus and forms of the Office): menus and forms can
  be taller and go to the bottom of the screen; LINES is 53.

Every patch checks the old bytes first. If the disk is a different version,
or is tall already, the script stops before it writes anything.

Use a tall disk only with a tall build: on a 348-line FreeBee it shows
garbage.

## What works

Boot, login, the Office, shells, window moves and resizes, covered windows,
Full-screen UNIX (53 lines), the soft keys, the mouse. Office windows go to
the bottom of the screen. New Office windows open in the top 20 rows, as on
the 3B1 (winmap, the map TAM places them with, has 26 rows). vi uses the
LINES=12 that the Office sets.

## The tools

- mktall.sh: all of the above.
- patch.py: patches /unix and wind.o.
- patchlib.py: patches /lib/shlib.
- s4get.py, s4same.py: copy a file out of a disk image; write a file of the
  same size back in place. s4img.py reads and writes the 3B1 file system.
- coff.py: reads 3B1 COFF files.
