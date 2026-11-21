#!/bin/sh
# AT&T UNIX PC (3B1 / PC 7300) with UNIX System V 3.51m, on the FreeBee
# emulator, with a tall 720x696 screen (a hack). See README.txt.
#
#   ./run.sh                 boot disk/hd.img; log in as tenox or root
#   ./run.sh 4x              CPU speed: 1x is a real 3B1 (10 MHz), up to 32x;
#                            default 10x. The clock stays real
#   ZOOM=2 ./run.sh          each 3B1 pixel 2x2 (1440x1392), 3 for 3x3 ...;
#                            default 1: no zoom (720x696)
#   COLOR=white ./run.sh     green (default), white or amber screen
#   MOUSE=grab ./run.sh      F10 grabs the mouse for the 3B1 and lets it go;
#                            default seamless: the 3B1's pointer follows
#                            yours over the window, with no grab
#   FLOPPY=file ./run.sh    a floppy image for the drive (F11 puts it in
#                            and takes it out)
#   HD2=file ./run.sh        a second hard disk image
#   NET=none ./run.sh        no network: the Ethernet board with no cable
#   HEADLESS=1 ./run.sh      no window (for an AI agent driving it over MCP)
cd "$(dirname "$0")" || exit 1
for a in "$@"; do
	case "$a" in
	[0-9]x|[0-9][0-9]x|[0-9]X|[0-9][0-9]X)	TURBO=${a%[xX]} ;;
	-h|--help|help)
		sed -n '2,/^cd /p' "./${0##*/}" | sed '$d' | sed 's/^# \{0,1\}//'
		exit 0 ;;
	*)	echo "run.sh: unknown argument '$a' (try 4x, 16x or --help)" >&2
		exit 1 ;;
	esac
done
set --
case "$(uname -s)-$(uname -m)" in
Darwin-arm64)	b=bin/macos-arm64 ;;
Linux-x86_64)	b=bin/linux-x86_64 ;;
Linux-aarch64)	b=bin/linux-aarch64 ;;
*)	echo "run.sh: no FreeBee binary for $(uname -sm); on Windows use run.cmd" >&2
	exit 1 ;;
esac
DISK=${DISK:-disk/hd.img}
ZOOM=${ZOOM:-1}
case "$ZOOM" in
[1-9])	;;
*)	echo "run.sh: ZOOM must be 1 (no zoom) to 9 (got $ZOOM)" >&2
	exit 1 ;;
esac
TURBO=${TURBO:-10}
case "$TURBO" in
[1-9]|[12][0-9]|3[0-2])	;;
*)	echo "run.sh: the speed must be 1x to 32x (got $TURBO)" >&2
	exit 1 ;;
esac
NET=${NET:-slirp}
case "$NET" in
slirp|none)	;;
*)	echo "run.sh: NET must be slirp or none (got $NET)" >&2
	exit 1 ;;
esac
case "${COLOR:-green}" in
white)	R=0xFF G=0xFF B=0xFF ;;
amber)	R=0xFF G=0xB0 B=0x00 ;;
green)	R=0x33 G=0xFF B=0x66 ;;
*)	echo "run.sh: COLOR must be green, white or amber (got $COLOR)" >&2
	exit 1 ;;
esac
case "${MOUSE:-seamless}" in
seamless)	SEAMLESS=true ;;
grab)	SEAMLESS=false ;;
*)	echo "run.sh: MOUSE must be seamless or grab (got $MOUSE)" >&2
	exit 1 ;;
esac
for f in "$DISK" ${FLOPPY:+"$FLOPPY"} ${HD2:+"$HD2"}; do
	[ -f "$f" ] && continue
	echo "run.sh: no file $f" >&2
	exit 1
done
# one FreeBee at a time on this disk
if [ -f freebee.pid ] && p=$(cat freebee.pid) && kill -0 "$p" 2>/dev/null &&
	ps -p "$p" -o comm= 2>/dev/null | grep -q freebee; then
	echo "run.sh: this VM is already running (pid $p)" >&2
	exit 1
fi

# FreeBee reads ./.freebee.toml. run.sh writes it at every start: change the
# variables above, not that file.
cat > .freebee.toml <<EOF
# made by run.sh - edit run.sh, not this file
[floppy]
	disk = "$FLOPPY"
[hard_disk]
	disk1 = "$DISK"
	disk2 = "$HD2"
[display]
	x_scale = $ZOOM
	y_scale = $ZOOM
	scale_quality = "nearest"
	red = $R
	green = $G
	blue = $B
[roms]
	rom_14c = "roms/14c.bin"
	rom_15c = "roms/15c.bin"
[serial]
	symlink = "serial-pty"
[control]
	socket = "freebee.sock"
[cpu]
	turbo = $TURBO
[mouse]
	seamless = $SEAMLESS
[memory]
	base_memory = 2048
	extended_memory = 2048
[beeper]
	volume = 40
[network]
	enabled = true
	backend = "$NET"
	hostfwd = "tcp:127.0.0.1:14123-:23, tcp:127.0.0.1:14121-:21, tcp:127.0.0.1:14514-:514"
EOF

echo "run.sh: CPU ${TURBO}x ($((TURBO * 10)) MHz)" >&2
[ "$NET" = slirp ] && echo "run.sh: after the login prompt: telnet localhost 14123" >&2
if [ -n "$HEADLESS" ] && [ "$HEADLESS" != 0 ]; then
	export FREEBEE_HEADLESS=1
fi
echo $$ > freebee.pid
exec "$b/freebee"
