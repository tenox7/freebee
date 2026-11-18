# Release builds and the 3B1 kit

These scripts build FreeBee to run on other people's computers, with
nothing else installed, and pack the AT&T UNIX PC kit
(`att3b1-unix351-freebee.tar.lz`): FreeBee for 4 platforms, UNIX 3.51 on a
195 MB disk, the boot ROMs and slirp networking.

| File | What it does |
|---|---|
| `versions.sh` | Versions and sha256 sums of SDL2, libslirp, glib and pcre2. Copies the tree for a build. |
| `build-macos.sh SRC OUT` | macOS arm64, macOS 11 and later, into `OUT/macos-arm64`. Runs on the Mac. |
| `build-linux.sh amd64\|arm64 SRC OUT` | Linux x86_64 or aarch64, glibc 2.34 and later, in Docker (AlmaLinux 9). |
| `build-windows.sh SRC OUT` | Windows x86_64 with MinGW, in Docker (Fedora 43). No serial port, control socket or MCP server. |
| `mkkit.sh [-n] BIN DISK ROMS OUT` | Packs the kit. `-n` only makes the kit folder, for a test boot. |
| `att3b1-unix351/` | The kit's `run.sh`, `run.cmd`, `README.txt` and `tools/fbctl`. |

Each build copies the tree first and refuses one with changes, so a
release binary is always a commit. `ALLOW_DIRTY=1` builds anyway, for
tests: the version then ends in `-dirty`, and `mkkit.sh` packs it only
with `-n`.

## Steps

1. Commit and push.
2. Build all 4 into one folder:
   ```sh
   sh release/build-macos.sh . BIN
   sh release/build-linux.sh amd64 . BIN
   sh release/build-linux.sh arm64 . BIN
   sh release/build-windows.sh . BIN
   ```
3. Sign the macOS files with a Developer ID and have Apple notarize them,
   so macOS runs the downloaded kit without asking. The scripts here sign
   them ad hoc only. The kits use `machines/release/sign-mac.sh` from
   [LEMU](https://github.com/tenox7/lemu): `sh sign-mac.sh BIN/macos-arm64`.
4. Pack:
   ```sh
   sh release/mkkit.sh BIN DISK ROMS OUT
   ```
   - DISK: a copy of the hard disk with no private files, its free space
     zero-filled, shut down cleanly.
   - ROMS: a folder with `14c.bin` and `15c.bin`.
   - It checks that the 4 builds name the same commit and that the macOS
     files are signed and notarized (`SIGNCHECK` is the path of
     `sign-mac.sh`, run with `-c`).
5. Test the unpacked kit: boot it with `HEADLESS=1 ./run.sh`, log in, and
   `telnet localhost 35123`.
