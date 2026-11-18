#!/bin/sh
# Builds FreeBee for Linux from SRC (a FreeBee tree with src/musashi) into
# OUT/linux-<arch>, on AlmaLinux 9 (glibc 2.34) in Docker: freebee, with glib
# and pcre in lib/. The license files go to OUT.
#
# - SDL2 is built here from the official release and linked in statically.
#   It loads X11, Wayland, ALSA, PulseAudio and PipeWire at run time, so it
#   needs none of them to start.
# - libslirp is built here (AlmaLinux 9 has 4.4) and linked in statically.
# - glib (LGPL) and pcre are AlmaLinux 9's, copied to lib/. zlib comes with
#   every Linux.
set -e
if [ "$1" != --container ]; then
	[ $# -eq 3 ] || { echo "usage: $0 amd64|arm64 SRC OUT" >&2; exit 1; }
	here=$(cd "$(dirname "$0")" && pwd)
	. "$here/versions.sh"
	mkdir -p "$3"
	top=$(cd "$3" && pwd)
	s=$top/.src-linux-$1
	trap 'rm -rf "$s"' EXIT
	freebee_src "$(cd "$2" && pwd)" "$s"
	echo "FreeBee $FREEBEE_REV"
	docker run --rm --platform "linux/$1" -e FREEBEE_REV="$FREEBEE_REV" \
		-v "$here:/release:ro" -v "$s:/src:ro" -v "$top:/out" \
		almalinux:9 sh /release/build-linux.sh --container
	exit
fi

. /release/versions.sh
dnf -y -q install epel-release dnf-plugins-core > /dev/null
dnf config-manager --set-enabled crb
dnf -y -q install gcc make cmake ninja-build meson pkgconf-pkg-config patchelf \
	glib2-devel zlib-devel \
	libX11-devel libXext-devel libXrandr-devel libXcursor-devel libXi-devel \
	libXfixes-devel libXScrnSaver-devel libxkbcommon-devel \
	wayland-devel wayland-protocols-devel mesa-libEGL-devel mesa-libGL-devel \
	alsa-lib-devel pulseaudio-libs-devel pipewire-devel dbus-devel > /dev/null

cd /tmp
p=/tmp/prefix
curl -fsSL -o sdl.tar.gz "$SDL2_URL/SDL2-$SDL2_V.tar.gz"
echo "$SDL2_SHA  sdl.tar.gz" | sha256sum -c -
curl -fsSL -o slirp.tar.gz "$SLIRP_URL"
echo "$SLIRP_SHA  slirp.tar.gz" | sha256sum -c -
tar xzf sdl.tar.gz
tar xzf slirp.tar.gz

cmake -S SDL2-$SDL2_V -B sdl-build -G Ninja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$p -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TEST=OFF \
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON > sdl.log || { tail -30 sdl.log; exit 1; }
grep -E ' SDL_(X11|WAYLAND|ALSA|PULSEAUDIO|PIPEWIRE|OPENGL|OPENGLES) ' sdl.log || true
cmake --build sdl-build > sdl-build.log 2>&1 || { tail -30 sdl-build.log; exit 1; }
cmake --install sdl-build > /dev/null

meson setup slirp-build libslirp-v$SLIRP_V --prefix=$p --libdir=lib --buildtype=release \
	--default-library=static > slirp.log || { tail -30 slirp.log; exit 1; }
ninja -C slirp-build install > slirp-build.log 2>&1 || { tail -30 slirp-build.log; exit 1; }

cp -R /src /tmp/fb
make -C /tmp/fb PLATFORM=linux VER_GITREV="$FREEBEE_REV" \
	SDL2_CFLAGS="$($p/bin/sdl2-config --cflags)" \
	SDL2_LIBS="$($p/bin/sdl2-config --static-libs)" \
	SLIRP=yes SLIRP_CFLAGS="-I$p/include/slirp $(pkg-config --cflags glib-2.0)" \
	SLIRP_LIBS="$p/lib/libslirp.a $(pkg-config --libs glib-2.0)" \
	> fb.log 2>&1 || { grep -E 'error|Error' fb.log | head -30; tail -20 fb.log; exit 1; }

out=/out/linux-$(uname -m)
rm -rf "$out"
mkdir -p "$out/lib"
install -m 755 /tmp/fb/freebee "$out/"
for l in $(ldd "$out/freebee" | awk '$3 ~ /^\// {print $3}'); do
	case ${l##*/} in
	ld-linux*|libc.so*|libm.so*|libdl.so*|librt.so*|libpthread.so*|\
	libresolv.so*|libgcc_s.so*|libz.so*)
		continue ;;
	esac
	cp -L "$l" "$out/lib/"
done
strip "$out"/lib/*
patchelf --force-rpath --set-rpath '$ORIGIN/lib' "$out/freebee"
for l in "$out"/lib/*; do
	patchelf --force-rpath --set-rpath '$ORIGIN' "$l"
done
cp /tmp/fb/LICENSE /out/LICENSE-freebee.txt
cp /tmp/fb/src/musashi/readme.txt /out/LICENSE-musashi.txt
cp SDL2-$SDL2_V/LICENSE.txt /out/LICENSE-SDL2.txt
cp libslirp-v$SLIRP_V/LICENSE /out/LICENSE-libslirp.txt
cp "$(rpm -ql glib2 | grep -m1 '/COPYING$')" /out/LICENSE-glib.txt
# pcre's COPYING only points to LICENCE, which has the text
cp "$(rpm -ql pcre | grep -m1 '/LICENCE$')" /out/LICENSE-pcre.txt
ls -l "$out" "$out/lib"
# the versions in lib/, for the kit's README
rpm -q glib2 pcre
for f in "$out/freebee" "$out"/lib/*; do
	echo "$f:"; readelf -d "$f" | awk '/NEEDED|RPATH|RUNPATH/ {print "  " $0}'
done
objdump -T "$out/freebee" "$out"/lib/* | grep -o 'GLIBC_[0-9.]*' | sort -t. -k2,2n -k3,3n -u | tail -1
# the banner names the commit; with no ROMs and no .freebee.toml it stops
# right after
mkdir -p /tmp/empty
(cd /tmp/empty && HOME=/tmp/empty FREEBEE_MCP=0 FREEBEE_HEADLESS=1 "$out/freebee" 2>/dev/null | grep -m1 Version)
