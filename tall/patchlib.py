# patchlib.py H SHLIB_IN SHLIB_OUT
#
# Patch the 3B1 shared library (/lib/shlib) for a screen of H lines (see
# patch.py). Its TAM code (the menus, forms and windows of the Office)
# has, in a window, "tbtflg ? 20 : LINES-6" rows to use: the 24 text rows
# of the old window area less 4. A menu or form that ends lower is moved
# back up (mdisplay, form), and none is made taller than that. Here the
# 20 grows by the new rows: 20 + (H - 348) / 12.
# The objects are the same as in /usr/lib/libtam.a; findobj.py found
# where each sits in shlib. Every patch checks the old bytes first.
import sys

H = int(sys.argv[1])
assert 348 < H and H * 90 <= 0x10000, H
N = 20 + (H - 348) // 12
assert N < 128, N			# a moveq takes -128..127

TEXT, TEXT_OFF = 0x310000, 0x4800	# shlib .text: address, file offset
OBJS = {				# object: base address in shlib
    'menu.o': 0x314764,
    'form.o': 0x3126d4,
    'wind.o': 0x3174c4,
    'wtty.o': 0x31badc,
}
# LINES: the screen's text rows. getcap takes it from the terminal entry
# (s4: lines#24), then keeps it in 6..48. wcreate refuses a window that
# ends below row LINES, so the taller menus failed and the Office quit.
# Here getcap always sets it, to the 24 rows plus the new ones (N + 4).
WORDS = [				# object, offset, old word, new word
    ('wtty.o', 0x02be, 0x6e0a, 0x4e71),	# getcap: bgt (keep it) -> nop
    ('wtty.o', 0x02c2, 24, N + 4),	# getcap: move.w #24, LINES
]
SITES = [				# object, offset of the moveq #20, its opcode
    ('wind.o', 0x001c, 0x70),		# wind: lines (rows for menus and forms)
    ('menu.o', 0x04a8, 0x70),		# mbegin: a new menu's size and place
    ('menu.o', 0x04e8, 0x70),
    ('menu.o', 0x0590, 0x70),
    ('menu.o', 0x06ac, 0x70),
    ('menu.o', 0x0762, 0x70),
    ('menu.o', 0x1762, 0x70),		# mdisplay: lowest row, else move up
    ('menu.o', 0x17b2, 0x70),		# mdisplay: then the height
    ('menu.o', 0x248c, 0x70),		# mshape
    ('menu.o', 0x257a, 0x70),
    ('form.o', 0x02b0, 0x70),		# form: a new form's size and place
    ('form.o', 0x02e0, 0x70),
    ('form.o', 0x0302, 0x70),
    ('form.o', 0x0356, 0x70),
    ('form.o', 0x0388, 0x70),
    ('form.o', 0x132c, 0x72),		# form: lowest row (moveq to d1)
]

# wind.o's "lines" (now N) is also the row count of winmap, the map that
# do_w_new and readdev use to place a new window: winmap[26][80] at
# 0x307f78. With N rows they wrote past it, over libc data and the end of
# shlib's bss, where signal() keeps its handlers (0x308d0c): SIGWIND went
# back to SIG_DFL and the next window move killed the Office. These 5 uses
# keep the old 20 rows; wind() still lets a window be N rows tall.
LINES_VAR = 0x307f70			# wind.o "lines" in shlib's bss
CMP_OLD = bytes.fromhex('b0b9') + LINES_VAR.to_bytes(4, 'big')	# cmp.l lines, d0
MOV_OLD = bytes.fromhex('2239') + LINES_VAR.to_bytes(4, 'big')	# move.l lines, d1
CMP_NEW = bytes.fromhex('0c8000000014')	# cmpi.l #20, d0
MOV_NEW = bytes.fromhex('72144e714e71')	# moveq #20, d1; nop; nop
INSNS = [				# object, offset, old bytes, new bytes
    ('wind.o', 0x02e0, CMP_OLD, CMP_NEW),	# do_w_new: clear winmap
    ('wind.o', 0x032c, CMP_OLD, CMP_NEW),	# do_w_new: mark windows (wgetstat)
    ('wind.o', 0x04ba, MOV_OLD, MOV_NEW),	# do_w_new: search rows
    ('wind.o', 0x051c, MOV_OLD, MOV_NEW),	# do_w_new: next row
    ('wind.o', 0x0702, CMP_OLD, CMP_NEW),	# readdev: mark windows (console)
]

buf = bytearray(open(sys.argv[2], 'rb').read())
for obj, off, op in SITES:
    a = OBJS[obj] + off
    o = a - TEXT + TEXT_OFF
    if buf[o] != op or buf[o + 1] != 20:
        sys.exit('%s+%#x (%#x): %02x%02x, not %02x14' % (obj, off, a, buf[o], buf[o + 1], op))
    buf[o + 1] = N
    print('shlib  %#x  %s+%#06x  moveq #20 -> #%d' % (a, obj, off, N))
for obj, off, old, new in WORDS:
    a = OBJS[obj] + off
    o = a - TEXT + TEXT_OFF
    cur = int.from_bytes(buf[o:o + 2], 'big')
    if cur != old:
        sys.exit('%s+%#x (%#x): %04x, not %04x' % (obj, off, a, cur, old))
    buf[o:o + 2] = new.to_bytes(2, 'big')
    print('shlib  %#x  %s+%#06x  %04x -> %04x' % (a, obj, off, old, new))
for obj, off, old, new in INSNS:
    a = OBJS[obj] + off
    o = a - TEXT + TEXT_OFF
    if buf[o:o + len(old)] != old:
        sys.exit('%s+%#x (%#x): %s, not %s' % (obj, off, a, buf[o:o + len(old)].hex(), old.hex()))
    buf[o:o + len(old)] = new
    print('shlib  %#x  %s+%#06x  %s -> %s' % (a, obj, off, old.hex(), new.hex()))
open(sys.argv[3], 'wb').write(buf)
