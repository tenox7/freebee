AT&T UNIX PC (3B1 / PC 7300) with UNIX System V 3.51m, emulated by FreeBee
==========================================================================

The UNIX PC: a 68010 CPU at 10 MHz (run 10 times as fast here), 4 MB RAM,
a 720x348 one-bit screen (shown green), a 195 MB hard disk and the 3B1
Ethernet board. The disk has nearly every program made for the UNIX PC.


Start
-----

- macOS 11 or later on Apple silicon, or Linux x86_64 or aarch64 (glibc
  2.34 or later, X11 or Wayland): ./run.sh
- Windows 10 or later, x64: run.cmd
- ./run.sh --help lists the options.

After about 30 seconds the screen says "Please login:".
- Type tenox and press Return: the Office comes up.
- Type root and press Return: a # shell.
- No account has a password.

Other accounts: demo (hello world in C, BASIC and Logo), show (starts the
Trade Show Demo), games, game2, and sap (the Small Accounting Package).


Basic use
---------

On a Mac, Alt is the Option key.

The Office is the 3B1's desktop: a window with a list of programs.
- Up and Down move through the list. Or type the first letter of a name
  to jump to it: u jumps to "UNIX System".
- Alt+Return opens the item. Or click it with the mouse: over the window,
  the 3B1's pointer follows yours.
- Alt+Esc closes the program, form or window you are in.
- PageUp shows help for the item or program.
- The bottom line of the screen shows what F1 to F8 do right now.

A shell: open "UNIX System" in the Office. Ctrl-D closes it.
Programs and games run there, for example:
  ls /usr/games        the games: rogue, nethack, larn, moria ...
  vi, ee, emacs        editors (emacs is AT&T EMACS 4.9c; GNU Emacs 19
                       is /usr/local/bin/emacs)
  cc, gcc              C compilers (cc takes only old K&R C)

Windows: F9 lists the open windows. Pick one with Up and Down, then press
Alt+Return to go to it.

Log out: press Alt+Esc in the Office, then Alt+Return to say yes (or
Alt+Backspace to stay). Close all your windows first: the Office does not
log out while one is open.


Stop
----

1. Log in as root and type /etc/shutdown.
   It waits a minute if other users are logged in.
2. After about 30 seconds it says "Ready to power off or reset the
   machine." (Return would boot it again.) It says it where you typed
   the command: on the screen, or on the serial port.
3. Close the window, or press Alt+F12.

Closing the window while UNIX runs can damage the file system.


Keys
----

The 3B1 keyboard has keys a PC keyboard lacks. On a Mac, Alt is Option.

  Return              ends a shell line
  Alt+Return          Enter: opens the item under the cursor in the
                      Office, says yes, and sends a form
  Alt+Esc             Exit: closes a window or a form
  Alt+Backspace       Cancl: says no, stops
  PageUp              Help
  PageDown            Page
  Insert              Cmd
  Home, End           Home, End
  arrows              arrows
  Shift+Up, Down      Roll Up, Roll Down: scroll a list or a text by one
                      line (the mouse wheel does this too)
  F1 to F8            the soft keys: the bottom line shows what they do
  F9                  Suspd: the list of open windows
  Pause               Reset/Break
  keypad 7 8 4 1 3    Print, Clear/Refresh, Beg, Prev, Next

  F10                 only with MOUSE=grab (see below): grabs the mouse
                      for the 3B1, and lets it go
  F11                puts the floppy in, and takes it out
  Alt+F12             quits FreeBee

Ctrl: the disk has the caps-lock/cntrl driver. Caps Lock and left Ctrl
are Ctrl. Right Ctrl is Caps Lock.


Speed, screen and mouse
-----------------------

- ./run.sh 4x: the CPU is 4 times as fast as a real 3B1. 1x to 32x, and
  10x if you say nothing. The clock always keeps real time.
- ZOOM=2 ./run.sh shows each pixel as 2x2 (1440x696). ZOOM=3 for 3x3.
- COLOR=white ./run.sh or COLOR=amber ./run.sh: another screen color.
- The mouse: over the window, the 3B1's pointer follows yours. There is
  no grab. MOUSE=grab ./run.sh gives the old way: F10 grabs the mouse
  for the 3B1, and F10 again lets it go.
- The mouse wheel scrolls a window that has scroll arrows on its right
  edge, such as the Office, like a click on the arrows. Point at the
  window first. In a shell window the wheel does nothing.
- Windows: run.cmd 4x, and "set ZOOM=2", "set COLOR=amber" or
  "set MOUSE=grab" before it.


Network
-------

The Ethernet board runs WIN/TCP (TCP/IP from The Wollongong Group, 1986)
on FreeBee's user networking (slirp: NAT, no admin rights needed).
- The 3B1 is 10.0.2.15.
- It sees your computer as 10.0.2.2, named qemuhost.
- Its default route goes through your computer, to the Internet.
- It has no DNS: use IP addresses, or add names to /etc/hosts. That
  file already has three public telnet hosts: sdf.org, telehack.com
  and nethack.alt.org (short names: sdf, telehack and nao).

From your computer (after "Please login:" shows):
- telnet localhost 35123
  macOS has no telnet. Use curl telnet://localhost:35123 instead.
- FTP, port 35121, active mode only (ftpd has no passive mode):
  curl -P - -u root:x ftp://localhost:35121/etc/hosts
- rsh and rcp, port 35514. rshd takes only the users listed in /.rhosts
  (to log in as root) and /etc/hosts.equiv (other accounts), as
  "qemuhost NAME". It has no + wildcard. Add your own name, as root:
  echo qemuhost NAME >> /.rhosts

From the 3B1:
- telnet telehack.com in a UNIX System window, or in the Office:
  Ethernet, then Network Virtual Terminal (telnet). There, Cmd
  (Insert) shows a list of hosts.
- To leave telnet: type ~ (no prompt shows), then quit and Return.
- The telnet client works on the screen, not on the serial port.
- ftp works anywhere.

NET=none ./run.sh keeps the Ethernet board but pulls its cable out.
On Windows: set NET=none, then run.cmd.


More
----

- Floppy: FLOPPY=file ./run.sh. F11 then puts it in and takes it out.
- Second hard disk: HD2=file ./run.sh.
- Serial port (macOS and Linux): screen ./serial-pty. Log in, and answer
  vt100 when it asks for the terminal name. There, # erases a character
  and @ the line, as on old terminals. To use Backspace and Ctrl-U, type:
  stty erase '^h' kill '^u'
- Scripting (macOS and Linux, needs python3): tools/fbctl sends commands
  to ./freebee.sock, for example: tools/fbctl "type date" "key return".
  tools/fbctl "speed max" runs the 3B1 as fast as your computer can (the
  clock races too). tools/fbctl "speed real" goes back.
- MCP (macOS and Linux): an AI agent can drive this VM: its screen, keys,
  mouse, serial port, floppy, and video recording. Add FreeBee's bridge
  to the agent, for example:
  claude mcp add freebee -- /full/path/to/bin/macos-arm64/freebee -mcp-bridge
  The VM's name is the name of this folder. HEADLESS=1 ./run.sh starts
  it without a window.
- The Windows build has no serial port, no tools/fbctl and no MCP server.
- The date and time come from your computer, but FreeBee always sets the
  year to 1987.
- FreeBee writes notes about the hardware in the terminal, such as
  "Attempt by user code to access kernel space". They are normal.


Software
--------

UNIX System V 3.51m with Fix Disk 2.0, and 187 installed packages:

- AT&T: the Office, Electronic Mail, Calendar, Telephone, Windowing
  Utilities, EMACS 4.9c, HoneyDanBer uucp, RS-232 Expansion, DOS-73,
  Voice Power, STARLAN, Tape Backup and WIN/TCP.
- Commercial: Microsoft Word 1.10, Multiplan 1.20, dBASE III 1.10,
  WordStar 2000, CrystalWriter Plus, Write Power, BBx, LPI-C, LPI-PASCAL,
  RM/COBOL, BACS and MiniCad.
- About 125 packages from THE STORE!: ksh, gawk, less, elm, pcomm, sc,
  LEARN, Office tools and every game.
- GNU and more: GCC 2.5.8 and 1.42, g++, gdb 3.5, GNU make, bash 2.05b,
  tcsh, GNU Emacs 19.19, perl 4.036, f2c, J 6.2, AKCL, Modula-2,
  TeX 3.141 with LaTeX2e, groff, ghostscript 2.6.1, gnuplot 3.5,
  SPICE 3c1, C-Kermit, pgp and KA9Q.
- Over 80 games in /usr/games: Rogue, NetHack 3.1.3, Hack, Larn, Moria,
  Omega, Adventure, Dungeon, Empire, Xconq, Tetrix, Pacman, gnuchess,
  Mahjongg, Backgammon, Star Trek and more.

Known limits:
- File-it! is not installed: it needs your own serial number and key.
- The AT&T Word Processor is partial: some printer filters and its help
  file are missing in every copy that exists.
- The phone manager (/etc/ph) crashes under FreeBee.
- MGR cannot run.

disk/hd.img: 1400 cylinders, 16 heads, 17 sectors (195 MB, the largest
disk the 3B1 takes), 54 MB free, one file system.


Credits and licenses
--------------------

- FreeBee: Phil Pemberton and others, https://github.com/philpem/freebee
  This build: https://github.com/tenox7/freebee at @REV@, with the
  Ethernet board, slirp networking, turbo, the control socket and the
  MCP server. GPL 3: bin/LICENSE-freebee.txt.
- Musashi (the 68000 CPU emulator): Karl Stenerud, from
  https://github.com/tenox7/Musashi. bin/LICENSE-musashi.txt.
- SDL 2.32.10: zlib license, bin/LICENSE-SDL2.txt.
- libslirp 4.9.7: BSD license, bin/LICENSE-libslirp.txt.
- glib: LGPL 2.1, bin/LICENSE-glib.txt.
  - macOS: glib 2.90.1 with pcre2 10.49 (bin/LICENSE-pcre2.txt).
  - Linux: AlmaLinux 9's glib 2.68.4 with pcre 8.44 (bin/LICENSE-pcre.txt).
  - Windows: Fedora 43's glib 2.86.5 with pcre2 10.48 (the same license,
    bin/LICENSE-pcre2.txt), libintl 0.25.1 (LGPL 2.1), win-iconv 0.0.10
    (public domain) and zlib 1.3.2 (bin/windows-x86_64/licenses).
- The software on the disk comes from the UNIX PC archives: THE STORE!,
  the 2008 mirror of the 3B1 archive, and the disk images of Arnold
  Robbins (https://www.skeeve.com/3b1/), Alain Knaff and the VCF.
