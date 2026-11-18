#!/bin/sh
# Builds FreeBee for macOS on Apple silicon from SRC (a FreeBee tree with
# src/musashi) into OUT/macos-arm64, for macOS 11 and up: freebee, with glib
# in lib/. The license files go to OUT.
#
# - SDL2, libslirp, glib and pcre2 are built here from source, because
#   Homebrew's need the macOS that built them. SDL2, libslirp and pcre2 are
#   linked in statically; glib (LGPL) is a dylib in lib/.
# - glib's libintl is proxy-libintl (meson downloads it). gobject wants
#   libffi to configure: it gets the one in the macOS SDK. FreeBee uses
#   neither gobject nor gio.
# - The binaries are signed ad hoc. A kit's are then signed with a Developer
#   ID and notarized (see README.md).
# Needs: Xcode command line tools, Homebrew cmake, meson, ninja, pkg-config.
set -e
[ $# -eq 2 ] || { echo "usage: $0 SRC OUT" >&2; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)
. "$here/versions.sh"
src=$(cd "$1" && pwd)
mkdir -p "$2"
top=$(cd "$2" && pwd)
out=$top/macos-arm64
min=11.0
export MACOSX_DEPLOYMENT_TARGET=$min
b=$(mktemp -d)
trap 'rm -rf "$b"' EXIT
p=$b/prefix
freebee_src "$src" "$b/fb"
echo "FreeBee $FREEBEE_REV"

fetch() {
	curl -fsSL -o "$b/$1" "$2"
	echo "$3  $b/$1" | shasum -a 256 -c -
}
fetch pcre2.tar.bz2 "$PCRE2_URL" $PCRE2_SHA
fetch glib.tar.xz "$GLIB_URL" $GLIB_SHA
fetch slirp.tar.gz "$SLIRP_URL" $SLIRP_SHA
fetch sdl.tar.gz "$SDL2_URL/SDL2-$SDL2_V.tar.gz" $SDL2_SHA
cd "$b"
tar xjf pcre2.tar.bz2
tar xJf glib.tar.xz
tar xzf slirp.tar.gz
tar xzf sdl.tar.gz

cmake -S pcre2-$PCRE2_V -B pcre2-build -G Ninja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=$min \
	-DCMAKE_INSTALL_PREFIX="$p" -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON \
	-DPCRE2_BUILD_PCRE2GREP=OFF -DPCRE2_BUILD_TESTS=OFF > pcre2.log
cmake --build pcre2-build > pcre2-build.log
cmake --install pcre2-build > /dev/null

sdk=$(xcrun --show-sdk-path)
mkdir -p "$p/lib/pkgconfig"
printf 'Name: libffi\nDescription: libffi in the macOS SDK\nVersion: 3.4.0\nCflags: -I%s/usr/include/ffi\nLibs: -lffi\n' \
	"$sdk" > "$p/lib/pkgconfig/libffi.pc"
export PKG_CONFIG_LIBDIR="$p/lib/pkgconfig" PKG_CONFIG_PATH=

meson setup glib-build glib-$GLIB_V --prefix="$p" --libdir=lib --buildtype=release \
	--default-library=shared -Dproxy-libintl:default_library=static \
	-Dtests=false -Dintrospection=disabled -Dnls=disabled -Dman-pages=disabled \
	-Ddocumentation=false -Dsysprof=disabled -Dlibelf=disabled -Dglib_debug=disabled \
	> glib.log || { tail -30 glib.log; exit 1; }
ninja -C glib-build install > glib-build.log 2>&1 || { tail -30 glib-build.log; exit 1; }

meson setup slirp-build libslirp-v$SLIRP_V --prefix="$p" --libdir=lib --buildtype=release \
	--default-library=static > slirp.log || { tail -30 slirp.log; exit 1; }
ninja -C slirp-build install > slirp-build.log 2>&1 || { tail -30 slirp-build.log; exit 1; }

cmake -S SDL2-$SDL2_V -B sdl-build -G Ninja -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=$min \
	-DCMAKE_INSTALL_PREFIX="$p" -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TEST=OFF \
	> sdl.log || { tail -30 sdl.log; exit 1; }
cmake --build sdl-build > sdl-build.log 2>&1 || { tail -30 sdl-build.log; exit 1; }
cmake --install sdl-build > /dev/null

make -C fb PLATFORM=linux VER_GITREV=$FREEBEE_REV \
	SDL2_CFLAGS="$("$p/bin/sdl2-config" --cflags)" \
	SDL2_LIBS="$("$p/bin/sdl2-config" --static-libs)" \
	SLIRP=yes SLIRP_CFLAGS="-I$p/include/slirp $(pkg-config --cflags glib-2.0)" \
	SLIRP_LIBS="$p/lib/libslirp.a $(pkg-config --libs glib-2.0) -lresolv" \
	> fb.log 2>&1 || { grep -E 'error|Error' fb.log | head -30; tail -20 fb.log; exit 1; }

rm -rf "$out"
mkdir -p "$out/lib"
cp fb/freebee "$out/"
g=$(otool -D "$p/lib/libglib-2.0.0.dylib" | tail -1)
cp "$p/lib/libglib-2.0.0.dylib" "$out/lib/"
chmod u+w "$out/lib/libglib-2.0.0.dylib"
install_name_tool -id @rpath/libglib-2.0.0.dylib "$out/lib/libglib-2.0.0.dylib"
install_name_tool -change "$g" @rpath/libglib-2.0.0.dylib "$out/freebee"
install_name_tool -add_rpath @executable_path/lib "$out/freebee"
strip -x "$out/lib/libglib-2.0.0.dylib"
codesign -f -s - "$out/freebee" "$out/lib/libglib-2.0.0.dylib"
cp fb/LICENSE "$top/LICENSE-freebee.txt"
cp fb/src/musashi/readme.txt "$top/LICENSE-musashi.txt"
cp SDL2-$SDL2_V/LICENSE.txt "$top/LICENSE-SDL2.txt"
cp glib-$GLIB_V/COPYING "$top/LICENSE-glib.txt"
cp libslirp-v$SLIRP_V/LICENSE "$top/LICENSE-libslirp.txt"
cp pcre2-$PCRE2_V/LICENCE.md "$top/LICENSE-pcre2.txt"

# Only macOS' own libraries and the bundled glib may be needed:
otool -L "$out/freebee" "$out/lib/libglib-2.0.0.dylib" | grep -v ':$' |
	awk '{print $1}' | sort -u > libs
cat libs
if grep -v -E '^(/usr/lib/|/System/Library/|@rpath/libglib-2\.0\.0\.dylib$)' libs; then
	echo "freebee needs the libraries above" >&2
	exit 1
fi
otool -l "$out/freebee" "$out/lib/libglib-2.0.0.dylib" | awk '/minos/ {print "minos", $2}' | sort -u
ls -l "$out" "$out/lib"
# the banner names the commit; with no ROMs and no .freebee.toml it stops
# right after
(cd "$b" && HOME=$b FREEBEE_MCP=0 FREEBEE_HEADLESS=1 "$out/freebee" 2>/dev/null | grep -m1 Version)
