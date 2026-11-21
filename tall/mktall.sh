#!/bin/sh
# mktall.sh IMG [H] - make a 3B1 UNIX 3.51m disk image use a screen of H
# lines (default 696, at most 728). It patches /unix, /etc/lddrv/wind.o and
# /lib/shlib in IMG, in place: use a copy, with the VM off. Every patch
# checks the old bytes first, so a disk that is not 3.51m, or that is
# already tall, stops with an error before anything is written.
set -e
T=$(cd "$(dirname "$0")" && pwd)
IMG=$1
H=${2:-696}
if [ ! -f "$IMG" ]; then
	echo "usage: mktall.sh IMG [H]" >&2
	exit 1
fi
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
python3 "$T/s4get.py" "$IMG" "$W" /unix /etc/lddrv/wind.o /etc/lddrv/wind /lib/shlib
python3 "$T/patch.py" "$H" "$W/unix" "$W/unix.new" "$W/wind.o" "$W/wind.o.new" "$W/wind"
python3 "$T/patchlib.py" "$H" "$W/shlib" "$W/shlib.new"
python3 "$T/s4same.py" "$IMG" /unix "$W/unix.new"
python3 "$T/s4same.py" "$IMG" /etc/lddrv/wind.o "$W/wind.o.new"
python3 "$T/s4same.py" "$IMG" /lib/shlib "$W/shlib.new"
echo "$IMG: tall, $H lines. Run it with FreeBee built with -DSCR_LINES=$H."
