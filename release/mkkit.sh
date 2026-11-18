#!/bin/sh
# Packs the AT&T UNIX PC kit, att3b1-unix351-freebee.tar.lz: FreeBee for
# macOS arm64, Linux x86_64 and aarch64 and Windows x86_64, UNIX 3.51 on a
# 195 MB disk, the boot ROMs and slirp networking. Runs on macOS.
#
#   mkkit.sh [-n] BIN DISK ROMS OUT
#
# BIN   what build-macos.sh, build-linux.sh (amd64 and arm64) and
#       build-windows.sh made: macos-arm64, linux-x86_64, linux-aarch64,
#       windows-x86_64 and the LICENSE files. All 4 builds must come from
#       the same commit, with no -dirty. The macOS files must be signed with
#       a Developer ID and notarized: SIGNCHECK checks them (default
#       ~/code/lemu/machines/release/sign-mac.sh, from
#       https://github.com/tenox7/lemu, run with -c).
# DISK  the hard disk image: a copy with no private files, its free space
#       zero-filled, shut down cleanly.
# ROMS  a folder with 14c.bin and 15c.bin.
# OUT   gets att3b1-unix351-freebee.tar.lz.
# -n    only makes the kit folder OUT/att3b1-unix351-freebee, for a test
#       boot. It skips the checks of the commit and of the signatures.
set -e
here=$(cd "$(dirname "$0")" && pwd)
name=att3b1-unix351-freebee
tpl=$here/att3b1-unix351
only=
[ "$1" = -n ] && { only=1; shift; }
if [ $# -ne 4 ]; then
	sed -n '2,/^set -e/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//' >&2
	exit 1
fi
bin=$(cd "$1" && pwd)
disk=$2
roms=$(cd "$3" && pwd)
mkdir -p "$4"
out=$(cd "$4" && pwd)
for f in "$disk" "$roms/14c.bin" "$roms/15c.bin" "$bin/LICENSE-freebee.txt" \
	"$bin/macos-arm64/freebee" "$bin/linux-x86_64/freebee" "$bin/linux-aarch64/freebee" \
	"$bin/windows-x86_64/freebee.exe" "$bin/windows-x86_64/SDL2.dll"; do
	[ -f "$f" ] || { echo "mkkit: no $f" >&2; exit 1; }
done

# FreeBee's version line names the commit: "(git REV)"
rev=
for f in macos-arm64/freebee linux-x86_64/freebee linux-aarch64/freebee windows-x86_64/freebee.exe; do
	r=$(LC_ALL=C grep -a -o '(git [0-9a-f]\{7,40\}[-a-z]*)' "$bin/$f" | head -1 | sed 's/^(git //; s/)$//')
	[ -n "$r" ] || { echo "mkkit: $f names no commit" >&2; exit 1; }
	[ -z "$rev" ] || [ "$r" = "$rev" ] || { echo "mkkit: $f is $r, the others $rev" >&2; exit 1; }
	rev=$r
done
echo "FreeBee $rev"
if [ -z "$only" ]; then
	case $rev in
	*-dirty) echo "mkkit: the binaries come from a tree with changes" >&2; exit 1 ;;
	esac
	sc=${SIGNCHECK:-$HOME/code/lemu/machines/release/sign-mac.sh}
	[ -f "$sc" ] || { echo "mkkit: no $sc (set SIGNCHECK)" >&2; exit 1; }
	sh "$sc" -c "$bin/macos-arm64"
fi

if [ -n "$only" ]; then
	t=$out
else
	t=$out/.$name.stage
	trap 'rm -rf "$t"' EXIT
fi
k=$t/$name
rm -rf "$k"
mkdir -p "$k/disk" "$k/roms" "$k/bin" "$k/tools"
cp -c "$disk" "$k/disk/hd.img" 2>/dev/null || cp "$disk" "$k/disk/hd.img"
cp "$roms/14c.bin" "$roms/15c.bin" "$k/roms/"
for p in macos-arm64 linux-x86_64 linux-aarch64 windows-x86_64; do
	cp -R "$bin/$p" "$k/bin/"
done
cp "$bin"/LICENSE-*.txt "$k/bin/"
cp "$tpl/run.sh" "$k/"
# cmd.exe wants CRLF
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$tpl/run.cmd" > "$k/run.cmd"
sed "s/@REV@/$rev/" "$tpl/README.txt" > "$k/README.txt"
cp "$tpl/tools/fbctl" "$k/tools/"
chmod 755 "$k/run.sh" "$k/tools/fbctl"
chmod 644 "$k/run.cmd" "$k/README.txt" "$k/disk/hd.img" "$k/roms/"*.bin

# nothing from a VM that ran, and no network setting of the user's own VMs
bad=$(find "$k" \( -name '.*' -o -name serial-pty -o -name 'freebee.sock' -o -name 'freebee.pid' \) -print)
[ -z "$bad" ] || { echo "mkkit: these do not belong in a kit: $bad" >&2; exit 1; }
if grep -n -E 'vmnet|mac *=' "$k/run.sh" "$k/run.cmd"; then
	echo "mkkit: the kit's run files set a MAC or vmnet" >&2
	exit 1
fi
if [ -n "$only" ]; then
	echo "$k"
	exit 0
fi

f=$out/$name.tar.lz
(cd "$t" && bsdtar --uid 0 --gid 0 --uname root --gname root --no-mac-metadata --no-xattrs \
	-cf - "$name") | plzip -9 > "$out/.$name.tar.lz.tmp"
mv "$out/.$name.tar.lz.tmp" "$f"
lzip -t "$f"
ls -l "$f"
shasum "$f"
