# The libraries built into the release binaries: version and the sha256 of
# the download. The build-*.sh scripts read this file.

# Branch tall-screen: the release builds have a screen of SCR_LINES lines
# (see tall/README.md), and their version ends in -tall.
SCR_LINES=696
SDL2_V=2.32.10
SDL2_SHA=5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165
SDL2_MINGW_SHA=83a5d74012311edc3c0d40ea6faecbe57ad692aa033fa5dc273cc937e3938ff2
SLIRP_V=4.9.7
SLIRP_SHA=d2567fa06a6357c7755d61c67293b2c0bf069b3f2173bde6b76cf768529a1938
# macOS only: Linux and Windows use the distribution's glib
GLIB_V=2.90.1
GLIB_SHA=93c941aa17d5eb1d53fe838365f29a8b4e539c222a256d974ec8f30fc413e396
PCRE2_V=10.49
PCRE2_SHA=53c156e1ba416a20da8e65395daa132da0d80e76910424caca3fcdae7831d384

SDL2_URL=https://github.com/libsdl-org/SDL/releases/download/release-$SDL2_V
SLIRP_URL=https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v$SLIRP_V/libslirp-v$SLIRP_V.tar.gz
GLIB_URL=https://download.gnome.org/sources/glib/${GLIB_V%.*}/glib-$GLIB_V.tar.xz
PCRE2_URL=https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$PCRE2_V/pcre2-$PCRE2_V.tar.bz2

# freebee_src SRC DEST: copy a FreeBee tree without its build output, and
# print the git commit it is (FREEBEE_REV if SRC is not a git tree). A tree
# with changes is refused, so a release binary is always a commit, unless
# ALLOW_DIRTY=1.
freebee_src() {
	if git -C "$1" rev-parse --git-dir > /dev/null 2>&1; then
		if [ -n "$(git -C "$1" status --porcelain)" ] && [ "$ALLOW_DIRTY" != 1 ]; then
			echo "$1 has changes that are not committed (ALLOW_DIRTY=1 builds anyway)" >&2
			return 1
		fi
		FREEBEE_REV=$(git -C "$1" rev-parse --short HEAD)
		[ -n "$(git -C "$1" status --porcelain)" ] && FREEBEE_REV=$FREEBEE_REV-dirty
	fi
	[ -n "$FREEBEE_REV" ] || { echo "no FREEBEE_REV for $1" >&2; return 1; }
	rm -rf "$2"
	mkdir -p "$2"
	(cd "$1" && tar -cf - --exclude .git --exclude './freebee' --exclude './freebee.exe' \
		--exclude './freebee.running' .) | tar -xf - -C "$2"
	find "$2/obj" "$2/dep" -type f ! -name .keepme -exec rm -f {} +
	rm -f "$2/src/version.h" "$2/src/mcp/schema_data.h" "$2/src/musashi/m68kops.c" \
		"$2/src/musashi/m68kops.h" "$2/obj/musashi/m68kmake"
	echo 0 > "$2/.buildnum"
}
