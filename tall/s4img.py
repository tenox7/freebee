#!/usr/bin/env python3
"""s4img - look inside AT&T UNIX PC (3B1 / 7300) hard disk images on the Mac.

  s4img.py info IMG                 disk label (VHB): geometry, partitions
  s4img.py ls IMG [PATH]            list a directory (long format)
  s4img.py find IMG [PATH]          every file below PATH: mode size path
  s4img.py cat IMG PATH             print a file
  s4img.py get IMG PATH OUT         copy a file out
  s4img.py tar IMG PATH OUT.tar     copy a tree out as a tar file
  s4img.py rawpart IMG N OUT        copy partition N out as logical sectors
  s4img.py putraw IMG N FILE        write FILE into partition N from its
                                    start (logical sectors): a raw cpio
                                    archive the 3B1 reads from /dev/rfp0N
                                    (disk 2: /dev/rfp01N)

Read-only except putraw. The file system is the System V one with 1K blocks;
partition 2 is the root file system on a hard disk, partition 1 on a floppy
(raw images only: tools/imd2raw.py converts IMD files). On disks with an odd
number of sectors per track (17), the last sector of every track is the
spare and not part of the logical disk.
"""
import os
import stat
import struct
import sys
import tarfile
import io
import time

SECT = 512


class Vol:
    def __init__(self, path, write=False):
        self.f = open(path, "r+b" if write else "rb")
        vhb = self.f.read(SECT)
        (magic,) = struct.unpack(">I", vhb[0:4])
        if magic != 0x55515651:
            raise SystemExit("%s: no UNIX PC disk label (magic %08x)" % (path, magic))
        self.name = vhb[8:14].decode("latin-1").rstrip("\0")
        (self.cyls, self.heads, self.spt, self.spc) = struct.unpack(">HHHH", vhb[14:22])
        self.flags = vhb[22]
        (self.secsz,) = struct.unpack(">H", vhb[24:26])
        self.newpart = bool(self.flags & 0x08)
        self.parts = []
        for i in range(16):
            raw = vhb[26 + 4 * i: 30 + 4 * i]
            if self.newpart:
                (strk,) = struct.unpack(">I", raw)
                self.parts.append(strk)
            else:
                (strk, nsecs) = struct.unpack(">HH", raw)
                self.parts.append(strk)
        # logical sectors per track: the spare sector is not mapped
        self.lspt = self.spt - 1 if self.spt % 2 else self.spt
        self.ntracks = self.cyls * self.heads

    def part_tracks(self, n):
        start = self.parts[n]
        ends = [p for p in self.parts if p > start] + [self.ntracks]
        return start, min(ends)

    def sector_offset(self, part, lsec):
        start, end = self.part_tracks(part)
        trk = start + lsec // self.lspt
        if trk >= end:
            raise ValueError("sector %d past the end of partition %d" % (lsec, part))
        return (trk * self.spt + lsec % self.lspt) * SECT

    def read_sectors(self, part, lsec, n):
        out = bytearray()
        for i in range(n):
            self.f.seek(self.sector_offset(part, lsec + i))
            out += self.f.read(SECT)
        return bytes(out)

    def write_sector(self, part, lsec, data):
        assert len(data) == SECT
        self.f.seek(self.sector_offset(part, lsec))
        self.f.write(data)

    def part_sectors(self, n):
        start, end = self.part_tracks(n)
        return (end - start) * self.lspt


class FS:
    def __init__(self, vol, part=2):
        self.vol = vol
        self.part = part
        sb = self.block(1)[0:512]
        self.isize, self.fsize = struct.unpack(">HI", sb[0:6])
        (self.magic, self.type) = struct.unpack(">ii", sb[512 - 16:512 - 8])
        if self.magic & 0xffffffff != 0xfd187e20:
            # old file systems may lack the magic: 1K blocks assumed
            self.type = 2
        if self.type != 2:
            raise SystemExit("only 1K block file systems are handled (type %d)" % self.type)

    def block(self, b):
        return self.vol.read_sectors(self.part, b * 2, 2)

    def inode(self, ino):
        blk = 2 + (ino - 1) // 16
        off = ((ino - 1) % 16) * 64
        d = self.block(blk)[off:off + 64]
        mode, nlink, uid, gid, size = struct.unpack(">HhHHi", d[0:12])
        addr = []
        a = d[12:52]
        for i in range(13):
            addr.append((a[3 * i] << 16) | (a[3 * i + 1] << 8) | a[3 * i + 2])
        atime, mtime, ctime = struct.unpack(">iii", d[52:64])
        return dict(ino=ino, mode=mode, nlink=nlink, uid=uid, gid=gid, size=size,
                    addr=addr, atime=atime, mtime=mtime, ctime=ctime)

    def blocks(self, ip):
        nblk = (ip["size"] + 1023) // 1024
        out = []
        addr = ip["addr"]
        for i in range(10):
            if len(out) >= nblk:
                return out
            out.append(addr[i])

        def indir(b, level):
            if b == 0:
                for _ in range(256 ** level):
                    if len(out) >= nblk:
                        return
                    out.append(0)
                return
            ptrs = struct.unpack(">256i", self.block(b))
            for p in ptrs:
                if len(out) >= nblk:
                    return
                if level == 1:
                    out.append(p)
                else:
                    indir(p, level - 1)

        for lvl, i in ((1, 10), (2, 11), (3, 12)):
            if len(out) >= nblk:
                break
            indir(addr[i], lvl)
        return out

    def read(self, ip):
        mode = ip["mode"] & 0o170000
        if mode not in (0o100000, 0o040000):
            return b""
        data = bytearray()
        for b in self.blocks(ip):
            data += self.block(b) if b else bytes(1024)
        return bytes(data[:ip["size"]])

    def readdir(self, ip):
        d = self.read(ip)
        ents = []
        for i in range(0, len(d), 16):
            ino, = struct.unpack(">H", d[i:i + 2])
            if ino == 0:
                continue
            name = d[i + 2:i + 16].split(b"\0")[0].decode("latin-1")
            ents.append((name, ino))
        return ents

    def lookup(self, path):
        ip = self.inode(2)
        for part in [p for p in path.split("/") if p]:
            if ip["mode"] & 0o170000 != 0o040000:
                raise SystemExit("%s: not a directory on the way" % path)
            for name, ino in self.readdir(ip):
                if name == part:
                    ip = self.inode(ino)
                    break
            else:
                raise SystemExit("%s: not found" % path)
        return ip

    def walk(self, path, ip=None, seen=None):
        if ip is None:
            ip = self.lookup(path)
        if seen is None:
            seen = set()
        yield path, ip
        if ip["mode"] & 0o170000 == 0o040000:
            if ip["ino"] in seen:
                return
            seen.add(ip["ino"])
            for name, ino in sorted(self.readdir(ip)):
                if name in (".", ".."):
                    continue
                child = self.inode(ino)
                yield from self.walk(path.rstrip("/") + "/" + name, child, seen)


def modestr(m):
    t = {0o040000: "d", 0o100000: "-", 0o020000: "c", 0o060000: "b",
         0o010000: "p"}.get(m & 0o170000, "?")
    s = ""
    for who in (6, 3, 0):
        bits = (m >> who) & 7
        s += ("r" if bits & 4 else "-") + ("w" if bits & 2 else "-") + ("x" if bits & 1 else "-")
    s = list(s)
    if m & 0o4000:
        s[2] = "s"
    if m & 0o2000:
        s[5] = "s"
    if m & 0o1000:
        s[8] = "t"
    return t + "".join(s)


def main():
    a = sys.argv[1:]
    if len(a) < 2:
        print(__doc__.strip())
        sys.exit(2)
    cmd, img = a[0], a[1]
    if cmd == "putraw":
        vol = Vol(img, write=True)
    else:
        vol = Vol(img)
    if cmd == "info":
        print("label %r: %d cyls, %d heads, %d sectors/track (%d logical), %d bytes/sector, flags %02x"
              % (vol.name, vol.cyls, vol.heads, vol.spt, vol.lspt, vol.secsz, vol.flags))
        for i, p in enumerate(vol.parts):
            if i > 0 and p == 0:
                continue
            s, e = vol.part_tracks(i)
            print("  partition %d: tracks %d-%d, %d KB" % (i, s, e - 1, (e - s) * vol.lspt // 2))
        return
    if cmd == "rawpart":
        n = int(a[2])
        with open(a[3], "wb") as o:
            for s in range(vol.part_sectors(n)):
                o.write(vol.read_sectors(n, s, 1))
        return
    if cmd == "putraw":
        n = int(a[2])
        data = open(a[3], "rb").read()
        if len(data) % SECT:
            data += bytes(SECT - len(data) % SECT)
        nsec = len(data) // SECT
        if nsec > vol.part_sectors(n):
            raise SystemExit("%d KB does not fit in partition %d (%d KB)"
                             % (nsec // 2, n, vol.part_sectors(n) // 2))
        for s in range(nsec):
            vol.write_sector(n, s, data[s * SECT:(s + 1) * SECT])
        print("wrote %d KB to partition %d" % (nsec // 2, n))
        return
    # hard disk: partition 2 is the file system; floppy: partition 1
    fs = FS(vol, 1 if vol.ntracks <= 160 else 2)
    if cmd == "ls":
        path = a[2] if len(a) > 2 else "/"
        ip = fs.lookup(path)
        for name, ino in sorted(fs.readdir(ip)):
            c = fs.inode(ino)
            print("%s %3d %5d %5d %9d %s %s" % (
                modestr(c["mode"]), c["nlink"], c["uid"], c["gid"], c["size"],
                time.strftime("%Y-%m-%d", time.gmtime(c["mtime"])), name))
    elif cmd == "find":
        path = a[2] if len(a) > 2 else "/"
        for p, ip in fs.walk(path):
            print("%s %9d %s %s" % (modestr(ip["mode"]), ip["size"],
                                    time.strftime("%Y-%m-%d", time.gmtime(ip["mtime"])), p))
    elif cmd == "cat":
        sys.stdout.buffer.write(fs.read(fs.lookup(a[2])))
    elif cmd == "get":
        open(a[3], "wb").write(fs.read(fs.lookup(a[2])))
    elif cmd == "tar":
        with tarfile.open(a[3], "w") as t:
            for p, ip in fs.walk(a[2]):
                ti = tarfile.TarInfo(p.lstrip("/") or ".")
                ti.mode = ip["mode"] & 0o7777
                ti.uid, ti.gid = ip["uid"], ip["gid"]
                ti.mtime = ip["mtime"]
                ft = ip["mode"] & 0o170000
                if ft == 0o040000:
                    ti.type = tarfile.DIRTYPE
                    t.addfile(ti)
                elif ft == 0o100000:
                    data = fs.read(ip)
                    ti.size = len(data)
                    t.addfile(ti, io.BytesIO(data))
    else:
        print(__doc__.strip())
        sys.exit(2)


if __name__ == "__main__":
    main()
