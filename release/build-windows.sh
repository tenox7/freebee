#!/bin/sh
# Builds freebee.exe for 64-bit Windows from SRC (a FreeBee tree with
# src/musashi) into OUT/windows-x86_64, with MinGW on Fedora 43 in Docker:
# freebee.exe and the DLLs it needs. The license files go to OUT, those of
# the Windows DLLs to OUT/windows-x86_64/licenses.
#
# - Windows has no ptys or Unix sockets, so this build has no serial port,
#   no control socket and no MCP server (src/mcp/stub.c).
# - SDL2.dll is the official libsdl-org MinGW build.
# - libslirp is built here and linked in statically, libgcc too.
# - glib (LGPL), zlib and the DLLs they need are Fedora's MinGW builds.
set -e
if [ "$1" != --container ]; then
	[ $# -eq 2 ] || { echo "usage: $0 SRC OUT" >&2; exit 1; }
	here=$(cd "$(dirname "$0")" && pwd)
	. "$here/versions.sh"
	mkdir -p "$2"
	top=$(cd "$2" && pwd)
	s=$top/.src-windows
	trap 'rm -rf "$s"' EXIT
	freebee_src "$(cd "$1" && pwd)" "$s"
	echo "FreeBee $FREEBEE_REV"
	# the MinGW cross compiler runs natively, on any Docker host
	docker run --rm -e FREEBEE_REV="$FREEBEE_REV" -e MAKEFLAGS \
		-v "$here:/release:ro" -v "$s:/src:ro" -v "$top:/out" \
		registry.fedoraproject.org/fedora:43 sh /release/build-windows.sh --container
	exit
fi

. /release/versions.sh
dnf -y -q install mingw64-gcc mingw64-glib2 mingw64-zlib mingw64-winpthreads \
	mingw64-pkg-config meson ninja-build gcc make findutils binutils > /dev/null

cd /tmp
p=/tmp/prefix
curl -fsSL -o sdl.tar.gz "$SDL2_URL/SDL2-devel-$SDL2_V-mingw.tar.gz"
echo "$SDL2_MINGW_SHA  sdl.tar.gz" | sha256sum -c -
curl -fsSL -o slirp.tar.gz "$SLIRP_URL"
echo "$SLIRP_SHA  slirp.tar.gz" | sha256sum -c -
tar xzf sdl.tar.gz
tar xzf slirp.tar.gz
sdl=/tmp/SDL2-$SDL2_V/x86_64-w64-mingw32

cat > cross.txt <<'EOF'
[binaries]
c = 'x86_64-w64-mingw32-gcc'
ar = 'x86_64-w64-mingw32-ar'
strip = 'x86_64-w64-mingw32-strip'
windres = 'x86_64-w64-mingw32-windres'
pkg-config = 'x86_64-w64-mingw32-pkg-config'

[host_machine]
system = 'windows'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF
meson setup slirp-build libslirp-v$SLIRP_V --cross-file cross.txt --prefix=$p --libdir=lib \
	--buildtype=release --default-library=static > slirp.log || { tail -30 slirp.log; exit 1; }
ninja -C slirp-build install > slirp-build.log 2>&1 || { tail -30 slirp-build.log; exit 1; }

cp -R /src /tmp/fb
# a console program (FreeBee prints what it does), so no -mwindows
make -C /tmp/fb PLATFORM=win32 CC=x86_64-w64-mingw32-gcc HOSTCC=gcc \
	STRIP=x86_64-w64-mingw32-strip VER_GITREV="$FREEBEE_REV" \
	EXT_CFLAGS="-mconsole -D_WIN32_WINNT=0x0601 -DSCR_LINES=$SCR_LINES" VER_EXTRA=-tall \
	SDL2_CFLAGS="$(sh $sdl/bin/sdl2-config --prefix=$sdl --cflags)" \
	SDL2_LIBS="-L$sdl/lib -lmingw32 -lSDL2main -lSDL2" \
	SLIRP=yes SLIRP_CFLAGS="-DLIBSLIRP_STATIC -I$p/include/slirp $(x86_64-w64-mingw32-pkg-config --cflags glib-2.0)" \
	SLIRP_LIBS="$p/lib/libslirp.a $(x86_64-w64-mingw32-pkg-config --libs glib-2.0)" \
	EXT_LDFLAGS="-mconsole -static-libgcc" \
	> fb.log 2>&1 || { grep -E 'error|Error' fb.log | head -30; tail -20 fb.log; exit 1; }

out=/out/windows-x86_64
mb=/usr/x86_64-w64-mingw32/sys-root/mingw/bin
rm -rf "$out"
mkdir -p "$out/licenses"
cp /tmp/fb/freebee.exe "$sdl/bin/SDL2.dll" "$out/"
todo=$out/freebee.exe
while [ -n "$todo" ]; do
	next=
	for f in $todo; do
		for d in $(x86_64-w64-mingw32-objdump -p "$f" | sed -n 's/^\tDLL Name: //p'); do
			[ -f "$out/$d" ] && continue
			[ -f "$mb/$d" ] || continue
			cp "$mb/$d" "$out/"
			next="$next $out/$d"
		done
	done
	todo=$next
done
for pkg in glib2 gettext win-iconv pcre2; do
	d=/usr/share/licenses/mingw64-$pkg
	[ -d $d ] && cp -R $d "$out/licenses/$pkg"
done
# zlib's license is the comment at the top of zlib.h
sed -n '1,/madler@/p' /usr/x86_64-w64-mingw32/sys-root/mingw/include/zlib.h > "$out/licenses/zlib.txt"
cp /tmp/fb/LICENSE /out/LICENSE-freebee.txt
cp /tmp/fb/src/musashi/readme.txt /out/LICENSE-musashi.txt
cp libslirp-v$SLIRP_V/LICENSE /out/LICENSE-libslirp.txt
[ -f /tmp/SDL2-$SDL2_V/LICENSE.txt ] && cp /tmp/SDL2-$SDL2_V/LICENSE.txt /out/LICENSE-SDL2.txt
ls -l "$out" "$out/licenses"
# the versions of the DLLs, for the kit's README
rpm -q mingw64-glib2 mingw64-pcre2 mingw64-gettext mingw64-win-iconv mingw64-zlib

# Every DLL is either bundled or Windows' own:
for f in "$out"/*.exe "$out"/*.dll; do
	x86_64-w64-mingw32-objdump -p "$f" | sed -n 's/^\tDLL Name: //p'
done | sort -u > /tmp/dlls
cat /tmp/dlls
fail=0
for d in $(cat /tmp/dlls); do
	[ -f "$out/$d" ] && continue
	case $(echo "$d" | tr A-Z a-z) in
	advapi32.dll|bcrypt.dll|crypt32.dll|dnsapi.dll|gdi32.dll|imm32.dll|iphlpapi.dll|\
	kernel32.dll|msvcrt.dll|ntdll.dll|ole32.dll|oleaut32.dll|setupapi.dll|shell32.dll|\
	shlwapi.dll|user32.dll|userenv.dll|uuid.dll|version.dll|winmm.dll|ws2_32.dll|\
	api-ms-win-*) ;;
	*) echo "MISSING: $d"; fail=1 ;;
	esac
done
[ $fail = 0 ]
# the version FreeBee prints names the commit
grep -a -o "([a-z]* $FREEBEE_REV)" "$out/freebee.exe" | head -1
