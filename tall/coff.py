# coff.py FILE - print the sections and symbols of a 3B1 (m68k) COFF file
import struct, sys

def load(path):
    d = open(path, 'rb').read()
    magic, nscns, timdat, symptr, nsyms, opthdr, flags = struct.unpack('>HHIIIHH', d[:20])
    secs = []
    o = 20 + opthdr
    for i in range(nscns):
        name = d[o:o+8].rstrip(b'\0').decode('latin-1')
        paddr, vaddr, size, scnptr, relptr, lnnoptr, nreloc, nlnno, sflags = struct.unpack('>IIIIIIHHI', d[o+8:o+40])
        secs.append(dict(name=name, vaddr=vaddr, size=size, off=scnptr, nreloc=nreloc, relptr=relptr, flags=sflags))
        o += 40
    syms = []
    strtab = symptr + nsyms * 18
    i = 0
    while i < nsyms:
        e = d[symptr + i*18: symptr + i*18 + 18]
        if e[:4] == b'\0\0\0\0':
            so = struct.unpack('>I', e[4:8])[0]
            n = d[strtab+so: d.index(b'\0', strtab+so)].decode('latin-1')
        else:
            n = e[:8].rstrip(b'\0').decode('latin-1')
        value, scnum, typ, sclass, numaux = struct.unpack('>IhHBB', e[8:18])
        syms.append(dict(name=n, value=value, scnum=scnum, sclass=sclass))
        i += 1 + numaux
    return d, dict(magic=magic, opthdr=opthdr, flags=flags), secs, syms

if __name__ == '__main__':
    d, h, secs, syms = load(sys.argv[1])
    print('magic %#x opthdr %d flags %#x' % (h['magic'], h['opthdr'], h['flags']))
    if h['opthdr'] >= 28:
        print('aout', ['%#x' % x for x in struct.unpack('>HHIIIIII', d[20:48])])
    for s in secs:
        print('%-8s vaddr %#08x size %#07x off %#07x nreloc %d' % (s['name'], s['vaddr'], s['size'], s['off'], s['nreloc']))
    print(len(syms), 'symbols')
    if len(sys.argv) > 2:
        for s in sorted(syms, key=lambda s: s['value']):
            if s['sclass'] in (2, 3, 6):
                print('%08x %2d %d %s' % (s['value'], s['scnum'], s['sclass'], s['name']))
