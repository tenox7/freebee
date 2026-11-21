# patch.py H UNIX_IN UNIX_OUT WINDO_IN WINDO_OUT [WIND_LINKED [WIND_OUT]]
#
# Patch the 3B1 UNIX 3.51m kernel (/unix) and window driver object
# (/etc/lddrv/wind.o) for a screen of H lines (348 < H <= 728), 720 pixels
# and 90 bytes a line as before, in 64 KB of video RAM at 0x420000.
# Every patch checks the old bytes first. Addresses are those of the
# linked wind (0x54000) and of /unix; WIND_LINKED (the /etc/lddrv/wind
# that goes with WINDO_IN) gives the map from one to the other. With
# WIND_OUT, the linked wind is patched too (lddrv loads it as it is).
import struct
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import coff

H = int(sys.argv[1])
assert 348 < H and H * 90 <= 0x10000, H
WH = H - 48			# window area: 0..WH-1; the 4 text lines below it
L = [WH, WH + 12, WH + 24, WH + 36]	# prompt, command, soft keys 1 and 2

# (address, old, new): 2 or 4 bytes, by the size of old
KERNEL = [
    (0x14eca, 0x3d2c, H * 45),		# vidinit: clear the whole screen (words)
    (0x1a05c, 694, 2 * H - 2),		# mscan: pointer y limit
    (0x1a066, 694, 2 * H - 2),
    # altvmem: the window driver's back buffer, where lcreate, ldelete and
    # lexpose draw (wsetscr copies the screen there and back). The kernel
    # has 31320 bytes there, one 348-line screen. Window memory is pages
    # 0x380 to 0x3dd (kv_pages), mapped when first used; nothing is free
    # in it. So the back buffer comes off the top of pxmem, the pool for
    # the saved parts of covered windows (256 KB, then 195 KB at 696 lines).
    (0x1ea1c, 0x40000, 0x3c1900 - H * 90 - 0x381900),	# pxmemsize
    (0x1ea2c, 0x3d2fc8, 0x3c1900 - H * 90),		# altvmem: up to wtxt
]
KERNEL_SIZES = {0x14eca: 2}
WIND = [
    (0x5502c, 300, L[0], 2),		# wbusyinit: busy icon on the prompt line
    (0x550ee, 312, L[1], 2),		# text lines: command
    (0x550f6, 300, L[0], 2),		# prompt
    (0x55106, 324, L[2], 2),		# soft keys 1
    (0x55110, 336, L[3], 2),		# soft keys 2
    (0x555c0, 288, WH - 12, 2),		# wset: highest window y
    (0x55644, 300, WH, 2),		# wset: tallest window
    (0x56f08, 347, H - 1, 4),		# mouse: y limit
    (0x56f12, 347, H - 1, 4),
    (0x570ea, 300, WH, 4),		# mouse: below the windows = text lines
    (0x573c6, 348, H, 4),		# msset: mouse icon clip
    (0x573ce, 348, H, 2),
    (0x576ae, 324, L[2], 2),		# msbelow: on the soft keys
    (0x577a8, 347, H - 1, 4),		# wmgr: mouse y limit
    (0x577b2, 347, H - 1, 4),
    (0x5797a, 300, WH, 4),		# wmgr: move and resize limit
    (0x57982, 300, WH, 2),
    (0x5632a, 31320, H * 90, 4),	# wsetscr: copy the whole screen
    (0x5984e, 31320, H * 90, 4),	# lcreate: largest saved window
    (0x59856, 31320, H * 90, 4),
    (0x5a794, 288, WH - 12, 2),		# uwdflt: a new window's height
    (0x5a7b6, 300, WH, 2),		# vidrec: the window area
    # the screen saver keeps the screen in 8 pages (wmpte has 8 entries):
    # too small for a taller screen, so it is off. scrchk never fires,
    # and savscrn returns at once.
    (0x56358, 0x672e, 0x602e, 2),	# scrchk: beq -> bra
    (0x56614, 0x4e56, 0x4e75, 2),	# savscrn: link -> rts
]


def put(buf, off, old, new, size):
    fmt = '>H' if size == 2 else '>I'
    cur = struct.unpack(fmt, bytes(buf[off:off + size]))[0]
    if cur != old:
        sys.exit('at file offset %#x: %#x, not %#x' % (off, cur, old))
    buf[off:off + size] = struct.pack(fmt, new)


def sec_of(secs, addr):
    for i, s in enumerate(secs):
        if s['name'] in ('.text', '.data') and s['vaddr'] <= addr < s['vaddr'] + s['size']:
            return i, addr - s['vaddr']
    sys.exit('%#x is in no section' % addr)


# the kernel
d, h, secs, syms = coff.load(sys.argv[2])
buf = bytearray(d)
for a, old, new in KERNEL:
    i, rel = sec_of(secs, a)
    size = KERNEL_SIZES.get(a, 4)
    put(buf, secs[i]['off'] + rel, old, new, size)
    print('unix   %#07x %6d -> %d' % (a, old, new))
open(sys.argv[3], 'wb').write(buf)

# the window driver object
lk = sys.argv[6] if len(sys.argv) > 6 else None
d, h, osecs, syms = coff.load(sys.argv[4])
buf = bytearray(d)
if lk:
    ld, lh, lsecs, lsyms = coff.load(lk)
for a, old, new, size in WIND:
    if lk:
        i, rel = sec_of(lsecs, a)
        assert lsecs[i]['name'] == osecs[i]['name']
    else:
        # wind linked at 0x54000: .text, then .data right after it
        i, rel = sec_of([dict(s, vaddr=s['vaddr'] + 0x54000) for s in osecs], a)
    put(buf, osecs[i]['off'] + rel, old, new, size)
    print('wind.o %#07x %6d -> %d' % (a, old, new))
open(sys.argv[5], 'wb').write(buf)

# the linked window driver: lddrv loads it as it is, and links wind.o again
# only when wind.o is newer. A disk patched in place keeps the old times,
# so the linked file gets the same patches.
if len(sys.argv) > 7:
    buf = bytearray(ld)
    for a, old, new, size in WIND:
        i, rel = sec_of(lsecs, a)
        put(buf, lsecs[i]['off'] + rel, old, new, size)
    open(sys.argv[7], 'wb').write(buf)
    print('wind: the same %d patches' % len(WIND))
print('H %d: windows 0..%d, text lines at %s' % (H, WH - 1, L))
